import SwiftUI
import UIKit

// The cold-open. A grainy XCEL wordmark + XTINCT AI attribution flash up on the
// black arena floor, hold a beat, then a swipe-up carries you into the app. Auto-
// advances, or the user can swipe up / tap to skip.
struct LaunchView: View {
    let accent: Color
    let onEnter: () -> Void

    @State private var appeared = false
    @State private var dismissing = false
    @GestureState private var dragUp: CGFloat = 0

    var body: some View {
        ZStack {
            CourtBackground()

            VStack(spacing: 18) {
                Spacer()

                GrainyWordmark(text: "XCEL", accent: accent, size: 72)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92)

                XtinctBadge(accent: accent)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accent)
                        .offset(y: appeared ? -4 : 4)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: appeared)
                    Text("Swipe up to enter")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                }
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 60)
            }
        }
        .offset(y: -dragUp)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragUp) { value, state, _ in
                    state = max(0, -value.translation.height)
                }
                .onEnded { value in
                    if -value.translation.height > 80 { enter() }
                }
        )
        .onTapGesture { enter() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            // Auto-advance after a short hold if the user doesn't swipe.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                if !dismissing { enter() }
            }
        }
    }

    private func enter() {
        guard !dismissing else { return }
        dismissing = true
        onEnter()
    }
}

// The wordmark rendered with a drifting film-grain shimmer, sitting over a soft
// accent glow - the "XTINCT" treatment scaled up for the splash.
private struct GrainyWordmark: View {
    let text: String
    let accent: Color
    var size: CGFloat = 72

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = 4.0
            let p = (t.truncatingRemainder(dividingBy: cycle)) / cycle
            let grain = pow(max(0, sin(p * .pi)), 3) * 0.5
            let frame = NoiseTexture.frames[Int(t * 16) % NoiseTexture.frames.count]
            let pulse = (sin(t * 1.6) + 1) / 2

            ZStack {
                // Soft breathing glow behind the letters.
                label
                    .foregroundStyle(accent)
                    .blur(radius: 14 + pulse * 8)
                    .opacity(0.35 + pulse * 0.25)

                // Crisp white letters with a grain wash drifting across them.
                label
                    .foregroundStyle(.white)
                    .opacity(1 - grain * 0.5)
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
    }

    private var label: some View {
        Text(text)
            .font(.system(size: size, weight: .black))
            .kerning(6)
    }
}
