import SwiftUI
import UIKit

// Wraps a UIImage so it can drive an item-based sheet/cover.
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// Lets the user pan and zoom a chosen image inside a circular guideline before
// it becomes their profile photo. The circle is just the framing guide - the
// output is a square crop (the avatar clips it to a circle when displayed).
struct ProfileCropView: View {
    let image: UIImage
    let accent: Color
    let onCrop: (Data) -> Void
    let onCancel: () -> Void

    // Committed transform + live gesture deltas.
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            // The crop circle is a centered square as wide as the screen (minus a
            // margin), capped so it never exceeds the available height.
            let d = min(geo.size.width - 48, geo.size.height - 220)
            let base = baseScale(for: d)
            let liveScale = clampScale(scale * pinch)
            let liveOffset = clampedOffset(
                CGSize(width: offset.width + drag.width, height: offset.height + drag.height),
                d: d, scale: liveScale, base: base)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    Spacer()

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: image.size.width * base * liveScale,
                                   height: image.size.height * base * liveScale)
                            .offset(liveOffset)
                            .frame(width: d, height: d)
                            .clipped()

                        // Dim everything outside the circular guideline.
                        circleMask(d: d)
                    }
                    .frame(width: d, height: d)
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            DragGesture()
                                .updating($drag) { value, state, _ in state = value.translation },
                            MagnificationGesture()
                                .updating($pinch) { value, state, _ in state = value }
                        )
                        .onEnded { _ in
                            offset = liveOffset
                            scale = liveScale
                        }
                    )

                    Text("Drag to position · pinch to zoom")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.45))
                        .padding(.top, 20)

                    Spacer()

                    useButton(d: d, base: base)
                }
                .padding(.vertical, 24)
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(white: 0.6))
            }
            Spacer()
            Text("MOVE & SCALE")
                .font(.system(size: 12, weight: .bold))
                .kerning(2)
                .foregroundStyle(.white)
            Spacer()
            // Balance the Cancel button so the title stays centered.
            Text("Cancel").font(.system(size: 16, weight: .medium)).opacity(0)
        }
        .padding(.horizontal, 24)
    }

    private func circleMask(d: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .frame(width: d, height: d)
            .mask {
                Rectangle()
                    .overlay(Circle().blendMode(.destinationOut))
                    .compositingGroup()
            }
            .overlay(Circle().stroke(accent, lineWidth: 2))
            .allowsHitTesting(false)
    }

    private func useButton(d: CGFloat, base: CGFloat) -> some View {
        Button {
            let data = render(d: d, base: base)
            onCrop(data)
        } label: {
            Text("Use photo")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 24)
    }

    // MARK: Geometry

    // Scale that makes the image fill the crop square edge-to-edge.
    private func baseScale(for d: CGFloat) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return max(d / image.size.width, d / image.size.height)
    }

    private func clampScale(_ s: CGFloat) -> CGFloat {
        min(maxScale, max(minScale, s))
    }

    // Keep the image covering the whole crop square (no empty corners).
    private func clampedOffset(_ o: CGSize, d: CGFloat, scale: CGFloat, base: CGFloat) -> CGSize {
        let w = image.size.width * base * scale
        let h = image.size.height * base * scale
        let maxX = max(0, (w - d) / 2)
        let maxY = max(0, (h - d) / 2)
        return CGSize(width: min(maxX, max(-maxX, o.width)),
                      height: min(maxY, max(-maxY, o.height)))
    }

    // Render the visible crop square to JPEG data at a crisp output resolution.
    private func render(d: CGFloat, base: CGFloat) -> Data {
        let output: CGFloat = 600
        let k = output / d   // points -> output pixels
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: output, height: output), format: format)

        let scaledW = image.size.width * base * scale * k
        let scaledH = image.size.height * base * scale * k
        let originX = output / 2 + offset.width * k - scaledW / 2
        let originY = output / 2 + offset.height * k - scaledH / 2

        let result = renderer.image { _ in
            image.draw(in: CGRect(x: originX, y: originY, width: scaledW, height: scaledH))
        }
        return result.jpegData(compressionQuality: 0.85) ?? Data()
    }
}
