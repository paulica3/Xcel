import SwiftUI
import PhotosUI
import Photos
import Vision
import ImageIO
import UIKit

// On-device proof checker. Two independent signals, no network, no entitlement
// beyond the photo picker:
//   1. EXIF same-day check  - was the photo actually taken today?
//   2. Vision label match   - does what's in the photo loosely match the task?
// The match is a bonus signal; "verified" means the photo was taken today.
struct PhotoProofResult {
    var sameDay: Bool?      // nil = no date metadata (e.g. a screenshot)
    var matchedLabel: String?
    var summary: String
    var verified: Bool { sameDay == true }
}

enum PhotoProof {
    // Downscale to a light thumbnail for storage in SwiftData.
    static func thumbnail(_ image: UIImage, maxDimension: CGFloat = 480) -> Data? {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return scaled.jpegData(compressionQuality: 0.7)
    }

    // Full verification of a LIBRARY photo. The most reliable capture date is the
    // Photos asset's own creationDate (set by the OS, survives screenshots, edits,
    // and re-saves where EXIF often doesn't). We pass the picker's asset identifier
    // and fall back to EXIF/TIFF only when the asset date isn't available.
    static func verify(originalData: Data, assetIdentifier: String?, taskTitle: String) async -> PhotoProofResult {
        let captureDate = await captureDate(originalData: originalData, assetIdentifier: assetIdentifier)
        let sameDay: Bool? = captureDate.map { Calendar.current.isDateInToday($0) }
        let match = await classify(originalData, against: taskTitle)

        let summary: String
        switch (sameDay, match) {
        case (true, let label?):
            summary = "Verified · taken today, looks like \(label)."
        case (true, nil):
            summary = "Verified · taken today."
        case (false, _):
            summary = "Heads up · this photo wasn't taken today."
        case (nil, let label?):
            summary = "Added · couldn't read a date, but it looks like \(label)."
        case (nil, nil):
            summary = "Added · couldn't read this photo's date. Shoot it in-app to verify."
        }
        return PhotoProofResult(sameDay: sameDay, matchedLabel: match, summary: summary)
    }

    // A photo just captured inside the app is same-day by definition - the most
    // trustworthy proof there is. We only run the label match for flavor.
    static func verifyCameraShot(image: UIImage, taskTitle: String) async -> PhotoProofResult {
        let data = image.jpegData(compressionQuality: 0.9) ?? Data()
        let match = await classify(data, against: taskTitle)
        let summary = match.map { "Verified · shot in-app just now, looks like \($0)." }
            ?? "Verified · shot in-app just now."
        return PhotoProofResult(sameDay: true, matchedLabel: match, summary: summary)
    }

    // MARK: Capture date (Photos asset first, EXIF fallback)

    private static func captureDate(originalData: Data, assetIdentifier: String?) async -> Date? {
        if let id = assetIdentifier, let date = await assetCreationDate(id) {
            return date
        }
        return exifDate(originalData)
    }

    private static func assetCreationDate(_ identifier: String) async -> Date? {
        let status = await ensurePhotoAccess()
        guard status == .authorized || status == .limited else { return nil }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return assets.firstObject?.creationDate
    }

    private static func ensurePhotoAccess() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return current
    }

    private static func exifDate(_ data: Data) -> Date? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        else { return nil }

        // Prefer EXIF DateTimeOriginal; fall back to TIFF DateTime.
        var stamp: String?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            stamp = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        }
        if stamp == nil, let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            stamp = tiff[kCGImagePropertyTIFFDateTime] as? String
        }
        guard let stamp else { return nil }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
        fmt.timeZone = .current
        return fmt.date(from: stamp)
    }

    // MARK: Vision classification

    private static func classify(_ data: Data, against title: String) async -> String? {
        let words = Set(
            title.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= 3 }
        )
        guard !words.isEmpty else { return nil }

        let labels: [String] = await withCheckedContinuation { cont in
            let request = VNClassifyImageRequest { req, _ in
                let obs = (req.results as? [VNClassificationObservation]) ?? []
                let top = obs.filter { $0.confidence > 0.1 }
                    .prefix(15)
                    .map { $0.identifier.lowercased() }
                cont.resume(returning: Array(top))
            }
            let handler = VNImageRequestHandler(data: data, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }

        // A hit is any overlap between a task word and a Vision label token.
        for label in labels {
            let tokens = label.split(whereSeparator: { $0 == "_" || $0 == " " }).map(String.init)
            for token in tokens where token.count >= 3 {
                if words.contains(token) || words.contains(where: { token.contains($0) || $0.contains(token) }) {
                    return "“\(token)”"
                }
            }
        }
        return nil
    }
}

// Per-task photo attach + verification, used in the evening review. Owns its own
// picker state so each task row is independent.
struct PhotoProofRow: View {
    @Binding var item: ChecklistItem
    let accent: Color

    @State private var pickerItem: PhotosPickerItem?
    @State private var working = false
    @State private var showCamera = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if let data = item.photoData, let ui = UIImage(data: data) {
                attached(ui)
            } else if working {
                HStack(spacing: 8) {
                    ProgressView().tint(accent).scaleEffect(0.8)
                    Text("Checking the photo…")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(white: 0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    if cameraAvailable {
                        Button { showCamera = true } label: {
                            proofButton(icon: "camera.fill", label: "Take photo")
                        }
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                        proofButton(icon: "photo.on.rectangle", label: "Choose photo")
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            loadAndVerify(newValue)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { verifyCamera(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func proofButton(icon: String, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(accent)
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func attached(_ ui: UIImage) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: item.photoVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(item.photoVerified ? accent : Color.eliminationRed)
                    Text(item.photoVerified ? "Verified" : "Unverified")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(item.photoVerified ? accent : Color.eliminationRed)
                }
                Text(item.photoNote)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                item.photoData = nil
                item.photoVerified = false
                item.photoNote = ""
                pickerItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color(white: 0.35))
            }
        }
        .padding(10)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadAndVerify(_ pick: PhotosPickerItem) {
        working = true
        let identifier = pick.itemIdentifier
        Task {
            guard let data = try? await pick.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data) else {
                await MainActor.run { working = false }
                return
            }
            let result = await PhotoProof.verify(originalData: data, assetIdentifier: identifier, taskTitle: item.title)
            let thumb = PhotoProof.thumbnail(ui)
            await MainActor.run {
                item.photoData = thumb
                item.photoVerified = result.verified
                item.photoNote = result.summary
                working = false
            }
        }
    }

    private func verifyCamera(_ image: UIImage) {
        working = true
        Task {
            let result = await PhotoProof.verifyCameraShot(image: image, taskTitle: item.title)
            let thumb = PhotoProof.thumbnail(image)
            await MainActor.run {
                item.photoData = thumb
                item.photoVerified = result.verified
                item.photoNote = result.summary
                working = false
            }
        }
    }
}

// A thin wrapper over the system camera. Returns the captured image, or nil if
// the user cancels. Camera isn't available in the simulator - callers guard with
// UIImagePickerController.isSourceTypeAvailable(.camera).
struct CameraPicker: UIViewControllerRepresentable {
    let onResult: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onResult: (UIImage?) -> Void
        init(onResult: @escaping (UIImage?) -> Void) { self.onResult = onResult }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onResult(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onResult(nil)
        }
    }
}
