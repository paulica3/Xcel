import SwiftUI

// The animated moment between "judge is watching" and the W/L card.
// A short basketball play resolves into the verdict — a different play each time.
enum VerdictPlay: CaseIterable {
    // Wins
    case slamDunk, buzzerBeater, fromDowntown
    // Losses
    case brick, airball, rejected

    static func random(for verdict: GameVerdict) -> VerdictPlay {
        let wins: [VerdictPlay] = [.slamDunk, .buzzerBeater, .fromDowntown]
        let losses: [VerdictPlay] = [.brick, .airball, .rejected]
        return (verdict == .win ? wins : losses).randomElement() ?? .slamDunk
    }

    var isWin: Bool {
        switch self {
        case .slamDunk, .buzzerBeater, .fromDowntown: return true
        case .brick, .airball, .rejected: return false
        }
    }

    var headline: String {
        switch self {
        case .slamDunk:     return "SLAM!"
        case .buzzerBeater: return "BUZZER BEATER!"
        case .fromDowntown: return "FROM DOWNTOWN!"
        case .brick:        return "BRICK."
        case .airball:      return "AIRBALL."
        case .rejected:     return "REJECTED."
        }
    }

    // Total runtime and the instant the ball "arrives" (haptic/sound + headline).
    var total: Double {
        switch self {
        case .slamDunk:     return 1.15
        case .buzzerBeater: return 1.25
        case .fromDowntown: return 1.30
        case .brick:        return 1.20
        case .airball:      return 1.20
        case .rejected:     return 1.10
        }
    }

    var climax: Double {
        switch self {
        case .slamDunk:     return 0.58
        case .buzzerBeater: return 0.72
        case .fromDowntown: return 0.78
        case .brick:        return 0.52
        case .airball:      return 0.55
        case .rejected:     return 0.42
        }
    }

    // Ball trajectory as normalized keyframes (0..1 within the play area).
    // First entry is the start; the rest are animated to in sequence.
    var frames: [BallFrame] {
        switch self {
        case .slamDunk:
            return [
                BallFrame(0.50, 0.92, scale: 0.85, rot: 0,    dur: 0),
                BallFrame(0.50, 0.16, scale: 1.25, rot: 360,  dur: 0.55),   // soars above rim
                BallFrame(0.50, 0.40, scale: 1.05, rot: 520,  dur: 0.16),   // hammered down
                BallFrame(0.50, 0.66, scale: 0.95, rot: 540,  dur: 0.22),
            ]
        case .buzzerBeater:
            return [
                BallFrame(0.12, 0.90, scale: 0.7,  rot: 0,    dur: 0),
                BallFrame(0.50, 0.22, scale: 1.0,  rot: 540,  dur: 0.72),   // deep high arc
                BallFrame(0.50, 0.52, scale: 0.92, rot: 600,  dur: 0.26),   // swish
            ]
        case .fromDowntown:
            return [
                BallFrame(0.86, 0.91, scale: 0.68, rot: 0,    dur: 0),
                BallFrame(0.50, 0.24, scale: 1.0,  rot: -540, dur: 0.78),   // rainbow three
                BallFrame(0.50, 0.54, scale: 0.92, rot: -600, dur: 0.24),
            ]
        case .brick:
            return [
                BallFrame(0.50, 0.92, scale: 0.82, rot: 0,    dur: 0),
                BallFrame(0.46, 0.34, scale: 1.0,  rot: 320,  dur: 0.50),   // clangs front rim
                BallFrame(0.30, 0.22, scale: 0.95, rot: 460,  dur: 0.16),   // kicks back out
                BallFrame(0.16, 0.86, scale: 0.85, rot: 620,  dur: 0.40),   // bounces away
            ]
        case .airball:
            return [
                BallFrame(0.50, 0.93, scale: 0.8,  rot: 0,    dur: 0),
                BallFrame(0.64, 0.42, scale: 0.95, rot: 300,  dur: 0.55),   // short and wide
                BallFrame(0.74, 0.92, scale: 0.85, rot: 470,  dur: 0.45),   // nothing but air
            ]
        case .rejected:
            return [
                BallFrame(0.50, 0.93, scale: 0.82, rot: 0,    dur: 0),
                BallFrame(0.50, 0.46, scale: 1.0,  rot: 300,  dur: 0.40),   // rises into the block
                BallFrame(0.88, 0.56, scale: 0.92, rot: 520,  dur: 0.18),   // swatted away
                BallFrame(1.12, 0.82, scale: 0.8,  rot: 720,  dur: 0.34),
            ]
        }
    }
}

struct BallFrame {
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var rot: CGFloat   // degrees
    var dur: Double
    init(_ x: CGFloat, _ y: CGFloat, scale: CGFloat, rot: CGFloat, dur: Double) {
        self.x = x; self.y = y; self.scale = scale; self.rot = rot; self.dur = dur
    }
}

private struct BallState {
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var rot: CGFloat
}

struct VerdictRevealView: View {
    let play: VerdictPlay
    let accent: Color
    var onClimax: () -> Void
    var onFinished: () -> Void

    @State private var animate = false
    @State private var showHeadline = false
    @State private var flash = false

    private var ballColor: Color { Color(red: 0.92, green: 0.45, blue: 0.13) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Play area: a tall centered box.
            let boxW = min(w * 0.8, 320)
            let boxH = min(h * 0.62, 440)
            let originX = (w - boxW) / 2
            let originY = (h - boxH) / 2 - 10

            ZStack {
                Color.arenaBlack.ignoresSafeArea()

                // A quick accent flash at the climax.
                Rectangle()
                    .fill(accent)
                    .opacity(flash ? 0.18 : 0)
                    .ignoresSafeArea()

                Hoop(accent: play.isWin ? accent : Color(white: 0.45))
                    .frame(width: 120, height: 96)
                    .position(x: originX + boxW * 0.5, y: originY + boxH * 0.20)

                if play == .rejected {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Color(white: 0.3))
                        .position(x: originX + boxW * 0.5, y: originY + boxH * 0.30)
                        .opacity(showHeadline ? 1 : 0)
                }

                ball(boxW: boxW, boxH: boxH, originX: originX, originY: originY)

                if showHeadline {
                    Text(play.headline)
                        .font(.system(size: 30, weight: .black))
                        .kerning(1)
                        .foregroundStyle(play.isWin ? accent : Color(white: 0.55))
                        .shadow(color: .black.opacity(0.6), radius: 8)
                        .position(x: originX + boxW * 0.5, y: originY + boxH * 0.86)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
        }
        .onAppear(perform: run)
    }

    private func ball(boxW: CGFloat, boxH: CGFloat, originX: CGFloat, originY: CGFloat) -> some View {
        let frames = play.frames
        let start = frames.first!
        return KeyframeAnimator(
            initialValue: BallState(x: start.x, y: start.y, scale: start.scale, rot: start.rot),
            trigger: animate
        ) { state in
            Basketball(color: ballColor)
                .frame(width: 44, height: 44)
                .scaleEffect(state.scale)
                .rotationEffect(.degrees(state.rot))
                .position(
                    x: originX + state.x * boxW,
                    y: originY + state.y * boxH
                )
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                for f in frames.dropFirst() { CubicKeyframe(f.x, duration: f.dur) }
            }
            KeyframeTrack(\.y) {
                for f in frames.dropFirst() { CubicKeyframe(f.y, duration: f.dur) }
            }
            KeyframeTrack(\.scale) {
                for f in frames.dropFirst() { CubicKeyframe(f.scale, duration: f.dur) }
            }
            KeyframeTrack(\.rot) {
                for f in frames.dropFirst() { LinearKeyframe(f.rot, duration: f.dur) }
            }
        }
    }

    private func run() {
        // Kick off the trajectory on the next runloop so KeyframeAnimator sees the change.
        DispatchQueue.main.async { animate = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + play.climax) {
            onClimax()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { showHeadline = true }
            withAnimation(.easeOut(duration: 0.12)) { flash = true }
            withAnimation(.easeIn(duration: 0.35).delay(0.12)) { flash = false }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + play.total + 0.55) {
            onFinished()
        }
    }
}

// MARK: - Drawn pieces

private struct Basketball: View {
    let color: Color
    var body: some View {
        ZStack {
            Circle().fill(color)
            Circle().stroke(.black.opacity(0.55), lineWidth: 1.5)
            // Seams.
            Path { p in
                p.move(to: CGPoint(x: 22, y: 0)); p.addLine(to: CGPoint(x: 22, y: 44))
                p.move(to: CGPoint(x: 0, y: 22)); p.addLine(to: CGPoint(x: 44, y: 22))
            }
            .stroke(.black.opacity(0.55), lineWidth: 1.5)
            Path { p in
                p.addArc(center: CGPoint(x: -8, y: 22), radius: 30,
                         startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
                p.addArc(center: CGPoint(x: 52, y: 22), radius: 30,
                         startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
            }
            .stroke(.black.opacity(0.45), lineWidth: 1.3)
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
    }
}

private struct Hoop: View {
    let accent: Color
    var body: some View {
        ZStack(alignment: .top) {
            // Backboard.
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(white: 0.5), lineWidth: 3)
                .frame(width: 90, height: 56)
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(white: 0.5), lineWidth: 2)
                .frame(width: 34, height: 24)
                .padding(.top, 14)
            // Rim.
            Ellipse()
                .stroke(accent, lineWidth: 4)
                .frame(width: 54, height: 14)
                .padding(.top, 50)
            // Net.
            NetShape()
                .stroke(Color(white: 0.65), lineWidth: 1)
                .frame(width: 54, height: 30)
                .padding(.top, 56)
        }
        .frame(width: 120, height: 96)
    }
}

private struct NetShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cols = 6
        let topInset = rect.width * 0.04
        let botInset = rect.width * 0.28
        for i in 0...cols {
            let tx = rect.minX + topInset + (rect.width - 2 * topInset) * CGFloat(i) / CGFloat(cols)
            let bx = rect.minX + botInset + (rect.width - 2 * botInset) * CGFloat(i) / CGFloat(cols)
            p.move(to: CGPoint(x: tx, y: rect.minY))
            p.addLine(to: CGPoint(x: bx, y: rect.maxY))
        }
        // Cross strands.
        for r in 1...2 {
            let y = rect.minY + rect.height * CGFloat(r) / 3
            let inset = topInset + (botInset - topInset) * CGFloat(r) / 3
            p.move(to: CGPoint(x: rect.minX + inset, y: y))
            p.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
        }
        return p
    }
}
