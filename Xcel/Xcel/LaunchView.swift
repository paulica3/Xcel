import SwiftUI
import UIKit

// MARK: Hero handoff plumbing

// Home reports where its wordmark/badge sit (in the shared "hero" coordinate
// space owned by ContentView); the launch overlay flies its own copies exactly
// onto those frames so the final swap is invisible.
struct HeroFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func reportHeroFrame(_ id: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: HeroFrameKey.self,
                                   value: [id: proxy.frame(in: .named("hero"))])
        })
    }
}

// The cold-open. Pure black, then a grainy XCEL wordmark + XTINCT AI
// attribution rise over a faint, slowly turning basketball. After a short hold
// it plays itself out - no swipe: the wordmark/badge fly along a transform-only
// path (offset + scale, never layout) onto their exact Home positions while the
// black clears to reveal the court "out of nowhere" underneath. At the landing
// Home's real wordmark cross-fades in beneath the flying copy, so the swap is
// pixel-perfect and can never pop.
struct LaunchView: View {
    let accent: Color
    let homeWordmarkFrame: CGRect
    let homeBadgeFrame: CGRect
    let onReveal: () -> Void   // land: reveal Home's real wordmark underneath
    let onFinish: () -> Void   // fully done: remove the splash overlay

    // Fine-tune the exact resting spot of each element relative to its measured
    // Home position. (0, 0) = land dead-on Home. Negative height = higher up,
    // negative width = further left. Nudge these if the dock looks a hair off.
    private let wordmarkLandingNudge = CGSize(width: 0, height: -63.5)
    private let badgeLandingNudge = CGSize(width: 0, height: -63.5)

    @State private var appeared = false
    // 0 = resting splash, 1 = docked pixel-exact onto Home's wordmark/badge.
    @State private var progress: CGFloat = 0
    @State private var completing = false
    @State private var faded = false   // flying copies fade out over the cross-dissolve
    @State private var wordmarkFrame: CGRect = .zero
    @State private var badgeFrame: CGRect = .zero

    var body: some View {
        ZStack {
            // Pure black to start; clears as the flight docks, revealing Home's
            // identical court underneath - the arena "appears out of nowhere".
            Color.black
                .opacity(max(0, 1 - progress))
                .ignoresSafeArea()

            // Centered basketball. This opacity is just the appear/transition
            // fade - the ball's faintness and the wave's brightness are separate
            // knobs inside SpinningBasketball (ballOpacity / waveOpacity).
            SpinningBasketball(accent: accent)
                .frame(width: 320, height: 320)
                .opacity(appeared ? (1 - progress) : 0)
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Spacer()

                GrainyWordmark(text: "XCEL", accent: accent, size: 72,
                               blend: progress, renderScale: wordmarkScale)
                    .scaleEffect(wordmarkScale * (appeared ? 1 : 0.92))
                    .offset(travel(from: wordmarkFrame, to: homeWordmarkFrame, nudge: wordmarkLandingNudge))
                    .opacity(appeared ? (faded ? 0 : 1) : 0)
                    .background { measure($wordmarkFrame) }

                XtinctBadge(accent: accent)
                    .offset(travel(from: badgeFrame, to: homeBadgeFrame, nudge: badgeLandingNudge))
                    .opacity(appeared ? (faded ? 0 : 1) : 0)
                    .background { measure($badgeFrame) }

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            // Hold on the wordmark, then play the flight automatically.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { flyHome() }
        }
    }

    // MARK: Flight geometry

    // Captures the resting layout frame exactly once. The layout is static
    // during the hold, so the first non-zero reading is the true resting spot;
    // ignoring later readings guarantees the flight's own offset/scale can never
    // feed back into the measurement and drag the landing target off-position.
    private func measure(_ frame: Binding<CGRect>) -> some View {
        Color.clear.onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named("hero"))
        } action: { newValue in
            if frame.wrappedValue == .zero, newValue != .zero {
                frame.wrappedValue = newValue
            }
        }
    }

    // How much smaller Home's wordmark is than the splash one (~46/72). Taken
    // from the measured widths so it stays exact if either size ever changes.
    private var dockScale: CGFloat {
        guard wordmarkFrame.width > 0, homeWordmarkFrame.width > 0 else { return 46.0 / 72.0 }
        return homeWordmarkFrame.width / wordmarkFrame.width
    }

    private var wordmarkScale: CGFloat { 1 - (1 - dockScale) * progress }

    private func travel(from source: CGRect, to target: CGRect, nudge: CGSize) -> CGSize {
        guard source != .zero, target != .zero else { return .zero }
        return CGSize(width: (target.midX + nudge.width - source.midX) * progress,
                      height: (target.midY + nudge.height - source.midY) * progress)
    }

    // MARK: Flight

    private func flyHome() {
        guard !completing else { return }
        completing = true
        // easeInOut, no overshoot - lands exactly on the measured target so the
        // flying copy and Home's real wordmark occupy the same pixels.
        withAnimation(.timingCurve(0.35, 0, 0.15, 1, duration: 0.9)) {
            progress = 1
        } completion: {
            // Reveal Home's real wordmark underneath, then dissolve the flying
            // copy over it - a cross-fade that hides any sub-pixel difference.
            onReveal()
            withAnimation(.easeOut(duration: 0.2)) { faded = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onFinish() }
        }
        // A soft thunk right as the wordmark touches down.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

// A faint basketball, drawn from seams, turning slowly - pure atmosphere behind
// the wordmark. Every few seconds a short, fast band of the accent color sweeps
// across it, lighting the seams as it passes.
private struct SpinningBasketball: View {
    let accent: Color

    // The ball sways side-to-side around its vertical axis rather than spinning
    // one way: it starts turned `swayAmplitude` degrees to one side, swings
    // through center, and continues to the other side. `swayPeriod` = seconds
    // for a full there-and-back cycle. (bob speed is `* 0.9` below.)
    private let swayAmplitude: Double = 40
    private let swayPeriod: Double = 3.4
    // How often the accent wave fires, and how fast it crosses (short + snappy).
    private let sweepPeriod: Double = 3.2
    private let sweepDuration: Double = 2.0
    // Faintness of the base ball vs. brightness of the accent wave - independent.
    // Bump waveOpacity toward 1 to make the wave pop; ballOpacity keeps the ball
    // ghostly.
    private let ballOpacity: Double = 0.12
    private let waveOpacity: Double = 0.9

    // Anchored to when the splash appears (not wall-clock), so the ball starts
    // at the exact same rotation/bob/sweep on every launch instead of wherever
    // the global clock happens to be.
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            // Starts at -swayAmplitude (one side), swings through 0 (center) at
            // a quarter-period, reaches +swayAmplitude (other side) at the half.
            let spin = Angle.degrees(swayAmplitude * sin(t / swayPeriod * 2 * .pi - .pi / 2))
            let bob = CGFloat(sin(t * 0.9)) * 8

            // 0...1 as the band crosses, then dark until the next period.
            let sweepPhase = t.truncatingRemainder(dividingBy: sweepPeriod)
            let sweeping = sweepPhase < sweepDuration
            let sweep = sweeping ? sweepPhase / sweepDuration : 1

            ZStack {
                // The ball itself - faint neutral seams.
                BasketballSeams()
                    .stroke(Color(white: 0.75), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .opacity(ballOpacity)

                // The accent wave - the seams light up in the user's color only
                // inside the moving band, with a glow so it reads as a flash.
                BasketballSeams()
                    .stroke(accent, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .shadow(color: accent, radius: 6)
                    .shadow(color: accent, radius: 12)
                    .opacity(sweeping ? waveOpacity : 0)
                    .mask(sweepBand(at: sweep))
            }
            .rotation3DEffect(spin, axis: (x: 0, y: 1, z: 0))
            .offset(y: bob)
        }
        .onAppear { start = Date() }
    }

    // A soft-edged vertical stripe of light at horizontal fraction `p`, travelling
    // from just off the left edge to just off the right - so the accent seams
    // only glow where the band currently is.
    private func sweepBand(at p: CGFloat) -> some View {
        let center = -0.25 + p * 1.5
        func clamp(_ x: CGFloat) -> CGFloat { min(1, max(0, x)) }
        return LinearGradient(
            stops: [
                .init(color: .clear, location: clamp(center - 0.16)),
                .init(color: .white, location: clamp(center)),
                .init(color: .clear, location: clamp(center + 0.16)),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

// Classic stylized basketball: the outline, a vertical + horizontal seam, and
// two side seams bowing out to the edges.
private struct BasketballSeams: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.04
        let r = rect.insetBy(dx: inset, dy: inset)
        let cx = r.midX, cy = r.midY

        p.addEllipse(in: r)                                   // ball outline
        p.move(to: CGPoint(x: cx, y: r.minY))                 // vertical seam
        p.addLine(to: CGPoint(x: cx, y: r.maxY))
        p.move(to: CGPoint(x: r.minX, y: cy))                 // horizontal seam
        p.addLine(to: CGPoint(x: r.maxX, y: cy))
        // Left side seam - top to bottom, bowing to the left edge.
        p.move(to: CGPoint(x: cx, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: cx, y: r.maxY),
                       control: CGPoint(x: r.minX - r.width * 0.02, y: cy))
        // Right side seam - mirror.
        p.move(to: CGPoint(x: cx, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: cx, y: r.maxY),
                       control: CGPoint(x: r.maxX + r.width * 0.02, y: cy))
        return p
    }
}

// The wordmark rendered with a drifting film-grain shimmer, sitting over a soft
// accent glow - the "XTINCT" treatment scaled up for the splash. `blend` morphs
// it toward WavingTitle's exact look (grain gone, Home's glow curve - both run
// on the same clock), so at blend 1, scaled down by `renderScale`, it is
// pixel-identical to Home's wordmark and the handoff swap is invisible.
private struct GrainyWordmark: View, Animatable {
    let text: String
    let accent: Color
    var size: CGFloat = 72
    var blend: CGFloat = 0
    var renderScale: CGFloat = 1

    // Animatable so the flight interpolates blend/renderScale per-frame instead
    // of snapping them - plain view parameters don't animate on their own.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(blend, renderScale) }
        set { blend = newValue.first; renderScale = newValue.second }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = 4.0
            let p = (t.truncatingRemainder(dividingBy: cycle)) / cycle
            let grain = pow(max(0, sin(p * .pi)), 3) * 0.5 * max(0, 1 - blend)
            let frame = NoiseTexture.frames[Int(t * 16) % NoiseTexture.frames.count]

            // Launch and Home glow params, breathing on the same shared clock.
            // Blur is divided by renderScale so the *on-screen* radius is right
            // after the outer scaleEffect shrinks the whole view.
            let pulse = (sin(t * 1.6) + 1) / 2
            let homePulse = (sin(t * 1.3) + 1) / 2
            let blur = lerp(14 + pulse * 8, 9 + homePulse * 11, blend) / max(0.1, renderScale)
            let glowOpacity = lerp(0.35 + pulse * 0.25, 0.30 + homePulse * 0.35, blend)

            ZStack {
                // Soft breathing glow behind the letters.
                label
                    .foregroundStyle(accent)
                    .blur(radius: blur)
                    .opacity(glowOpacity)

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

    // Built from individual glyphs (N-1 gaps) rather than `.kerning()`, which
    // adds a trailing gap after the last character with no matching leading
    // gap - that mismatch is what made the centered wordmark drift left.
    // Spacing is proportional to WavingTitle's (3pt at size 46) so the scaled
    // hero docks onto Home's wordmark with identical letter positions.
    private var label: some View {
        HStack(spacing: size * 3 / 46) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
            }
        }
        .font(.system(size: size, weight: .black))
    }
}

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}
