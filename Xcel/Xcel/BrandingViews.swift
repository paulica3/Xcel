import SwiftUI
import UIKit

// App wordmark: crisp white letters over a soft accent glow that slowly breathes,
// like a scoreboard lit up in a dark arena. Calm, premium, not distracting.
struct WavingTitle: View {
    let text: String
    let accent: Color
    var size: CGFloat = 46

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 1.3) + 1) / 2          // 0…1, ~5s breath
            let glow = 9 + pulse * 11
            let glowOpacity = 0.30 + pulse * 0.35

            ZStack {
                Text(text)
                    .font(.system(size: size, weight: .black))
                    .kerning(3)
                    .foregroundStyle(accent)
                    .blur(radius: glow)
                    .opacity(glowOpacity)

                Text(text)
                    .font(.system(size: size, weight: .black))
                    .kerning(3)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 16)
        }
    }
}

// "POWERED BY" stays perfectly still; only "XTINCT AI" dissolves into grainy,
// pixelated static and resolves - a brief rise-and-fall, low intensity.
struct XtinctBadge: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("POWERED BY")
                .font(.system(size: 9, weight: .bold))
                .kerning(2.5)
                .foregroundStyle(Color(white: 0.32))

            GrainyText(text: "XTINCT AI", color: accent)
        }
    }
}

private struct GrainyText: View {
    let text: String
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = 6.5
            let p = (t.truncatingRemainder(dividingBy: cycle)) / cycle
            let grain = pow(max(0, sin(p * .pi)), 4) * 0.6
            let frame = NoiseTexture.frames[Int(t * 14) % NoiseTexture.frames.count]

            label
                .opacity(1 - grain * 0.8)
                .overlay {
                    Image(uiImage: frame)
                        .interpolation(.none)
                        .resizable()
                        .opacity(grain)
                        .blendMode(.screen)
                        .mask(label)
                }
        }
    }

    private var label: some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .kerning(1.8)
            .foregroundStyle(color)
    }
}

// Circular profile avatar - shows the user's photo if set, else a placeholder glyph.
struct AvatarView: View {
    let data: Data?
    let accent: Color
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color(white: 0.1))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(accent.opacity(0.6), lineWidth: max(1, size * 0.04)))
            .overlay {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(Color(white: 0.55))
                }
            }
    }
}

// A handful of small random-noise frames, generated once, cycled for a static-y shimmer.
enum NoiseTexture {
    static let frames: [UIImage] = (0..<8).map { _ in make(width: 56, height: 14) }

    private static func make(width: Int, height: Int) -> UIImage {
        let count = width * height * 4
        var data = [UInt8](repeating: 0, count: count)
        var i = 0
        while i < count {
            let v = UInt8.random(in: 40...255)
            data[i] = v; data[i + 1] = v; data[i + 2] = v; data[i + 3] = 255
            i += 4
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &data, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cg = ctx.makeImage() else { return UIImage() }
        return UIImage(cgImage: cg)
    }
}
