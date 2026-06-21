import SwiftUI

// Full-screen payoff for taking a series — trophy, confetti, the works.
// Reused for the comeback variant with different copy.
struct CelebrationOverlay: View {
    let title: String
    let subtitle: String
    let accent: Color
    var onDismiss: () -> Void

    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            ConfettiView(accent: accent)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.7), radius: 18)
                    .scaleEffect(pop ? 1 : 0.4)

                Text(title)
                    .font(.system(size: 42, weight: .black))
                    .kerning(2)
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button { onDismiss() } label: {
                    Text("Let it sink in")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(accent)
                        .clipShape(Capsule())
                }
                .padding(.top, 10)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { pop = true }
        }
    }
}

// Lightweight confetti: a field of colored shards drifting down on a loop.
struct ConfettiView: View {
    let accent: Color

    private let pieces: [Piece] = (0..<70).map { _ in Piece() }

    struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat = .random(in: 0...1)
        let delay: Double = .random(in: 0...1.4)
        let duration: Double = .random(in: 2.0...3.6)
        let size: CGFloat = .random(in: 5...11)
        let spin: Double = .random(in: 1...3)
        let hue: Double = .random(in: 0...1)
        let sway: CGFloat = .random(in: -28...28)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    for p in pieces {
                        let cycle = (t - p.delay).truncatingRemainder(dividingBy: p.duration)
                        guard cycle >= 0 else { continue }
                        let progress = cycle / p.duration
                        let y = progress * (size.height + 40) - 20
                        let x = p.x * size.width + sin(progress * .pi * 2) * p.sway
                        let angle = Angle.degrees(t * 180 * p.spin)

                        var rect = Path(CGRect(x: -p.size / 2, y: -p.size / 2,
                                               width: p.size, height: p.size * 0.6))
                        let transform = CGAffineTransform(translationX: x, y: y)
                            .rotated(by: angle.radians)
                        rect = rect.applying(transform)

                        let color = p.hue < 0.45
                            ? accent
                            : Color(hue: p.hue, saturation: 0.8, brightness: 0.95)
                        ctx.fill(rect, with: .color(color.opacity(0.9)))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
