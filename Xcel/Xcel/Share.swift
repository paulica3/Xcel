import SwiftUI
import UIKit

// What goes on a shareable card.
struct ShareCardContent {
    var tag: String          // e.g. "THE SERIES" / "GAME 6 · SAT"
    var big: String          // the hero text: "W", "L", "4–2"
    var bigIsWin: Bool       // accent vs muted color for the hero
    var headline: String     // punchy line
    var sub: String          // record / context
}

// The 9:16 visual rendered to an image for sharing (fills IG Stories cleanly).
struct ShareCardView: View {
    let content: ShareCardContent
    let accent: Color

    var body: some View {
        ZStack {
            Color.arenaBlack
            RadialGradient(colors: [accent.opacity(0.28), .clear],
                           center: .center, startRadius: 10, endRadius: 320)

            VStack(spacing: 0) {
                Spacer()
                Text(content.tag)
                    .font(.system(size: 15, weight: .black))
                    .kerning(3)
                    .foregroundStyle(accent)

                Text(content.big)
                    .font(.system(size: 150, weight: .black))
                    .foregroundStyle(content.bigIsWin ? accent : Color(white: 0.55))
                    .shadow(color: content.bigIsWin ? accent.opacity(0.6) : .clear, radius: 28)
                    .padding(.vertical, 4)

                Text(content.headline)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Text(content.sub)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.top, 10)
                    .monospacedDigit()
                Spacer()

                VStack(spacing: 4) {
                    Text("XCEL")
                        .font(.system(size: 30, weight: .black))
                        .kerning(4)
                        .foregroundStyle(.white)
                    Text("POWERED BY XTINCT AI")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(3)
                        .foregroundStyle(accent.opacity(0.8))
                }
                .padding(.bottom, 40)
            }
        }
        .frame(width: 360, height: 640)
    }
}

enum Sharer {
    // Render the card to a high-res image (1080×1920).
    @MainActor static func render(_ content: ShareCardContent, accent: Color) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(content: content, accent: accent))
        renderer.scale = 3
        return renderer.uiImage
    }

    // The system share sheet - covers WhatsApp, Telegram, Messages, Instagram
    // feed/direct, Save Image, and anything else with a share extension.
    @MainActor static func presentShareSheet(image: UIImage) {
        guard let root = keyRootController() else { return }
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }

    // Drop the card straight into an Instagram Story via the sticker pasteboard.
    // Falls back to the share sheet if Instagram isn't installed.
    @MainActor static func shareToInstagramStory(image: UIImage) {
        guard let data = image.pngData(),
              let url = URL(string: "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "")") else {
            presentShareSheet(image: image)
            return
        }
        let items: [[String: Any]] = [["com.instagram.sharedSticker.backgroundImage": data]]
        UIPasteboard.general.setItems(items, options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(url, options: [:]) { ok in
            if !ok { presentShareSheet(image: image) }
        }
    }

    private static func keyRootController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMost()
    }
}

private extension UIViewController {
    func topMost() -> UIViewController {
        if let presented = presentedViewController { return presented.topMost() }
        if let nav = self as? UINavigationController, let top = nav.visibleViewController { return top.topMost() }
        if let tab = self as? UITabBarController, let sel = tab.selectedViewController { return sel.topMost() }
        return self
    }
}

// A reusable share control: tap for a menu of "Share…" and "Instagram Story".
struct ShareCardButton: View {
    let content: ShareCardContent
    let accent: Color
    var compact: Bool = false

    var body: some View {
        Menu {
            Button {
                if let img = Sharer.render(content, accent: accent) { Sharer.presentShareSheet(image: img) }
            } label: { Label("Share…", systemImage: "square.and.arrow.up") }
            Button {
                if let img = Sharer.render(content, accent: accent) { Sharer.shareToInstagramStory(image: img) }
            } label: { Label("Instagram Story", systemImage: "camera.fill") }
        } label: {
            if compact {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(Color(white: 0.1))
                    .clipShape(Circle())
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1))
            }
        }
    }
}
