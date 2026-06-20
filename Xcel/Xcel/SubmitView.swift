import SwiftUI
import SwiftData

struct SubmitView: View {
    let game: Game
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var phase: Phase = .ready
    @State private var result: JudgeResult? = nil
    @State private var errorMessage: String? = nil
    @State private var isComeback = false

    private var accent: Color { settings.accent.color }

    enum Phase { case ready, judging, verdict }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            switch phase {
            case .ready:   readyView
            case .judging: judgingView
            case .verdict: if let r = result { verdictView(r) }
            }

            if isComeback { comebackOverlay }
        }
        .navigationBarHidden(true)
    }

    // MARK: Ready — confirm the day

    private var readyView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text("GAME \(game.gameNumber)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.32))
                    .kerning(2.5)
                Text("No take-backs.")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    ForEach(game.checklist) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(item.isDone ? accent : Color(white: 0.4))
                            Text(item.title)
                                .font(.system(size: 15))
                                .foregroundStyle(Color(white: 0.7))
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            Spacer()
            Button { submit() } label: {
                Text("Submit Game \(game.gameNumber)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }

    private var judgingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .tint(accent)
                .scaleEffect(1.6)
            Text("The judge is watching…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.38))
            Spacer()
        }
    }

    // MARK: Verdict — W/L + coach's notes

    private func verdictView(_ r: JudgeResult) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Text(r.verdict == .win ? "W" : "L")
                    .font(.system(size: 120, weight: .black))
                    .foregroundStyle(r.verdict == .win ? accent : Color(white: 0.3))

                Text(r.oneLiner)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                if !r.feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COACH'S NOTES")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(2)
                            .foregroundStyle(accent)
                        Text(r.feedback)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.65))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 28)
                }

                if let series = game.series {
                    Text("\(series.wins)–\(series.losses) in the series")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.38))
                }
            }
            Spacer()
            Button(action: onComplete) {
                Text("Back to the court")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(r.verdict == .win ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(r.verdict == .win ? accent : Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }

    // MARK: Comeback celebration

    private var comebackOverlay: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("COMEBACK")
                    .font(.system(size: 44, weight: .black))
                    .kerning(2)
                    .foregroundStyle(accent)
                Text("Down and out — and you took the series anyway.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button { withAnimation { isComeback = false } } label: {
                    Text("Let it sink in")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(accent)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: Submit

    private func submit() {
        errorMessage = nil
        phase = .judging
        let wins = game.series?.wins ?? 0
        let losses = game.series?.losses ?? 0

        Task {
            do {
                let judgeResult = try await JudgeService().judge(
                    checklist: game.checklist,
                    extraNotes: game.extraNotes,
                    wins: wins,
                    losses: losses,
                    gameNumber: game.gameNumber
                )
                await MainActor.run {
                    game.verdict = judgeResult.verdict
                    game.verdictOneLiner = judgeResult.oneLiner
                    game.verdictFeedback = judgeResult.feedback
                    try? modelContext.save()
                    result = judgeResult

                    let clinchedComeback = judgeResult.verdict == .win
                        && (game.series?.seriesResult == .won)
                        && (game.series?.wasComeback ?? false)

                    if judgeResult.verdict == .win { FX.win() } else { FX.loss() }
                    withAnimation(.spring(duration: 0.5)) { phase = .verdict }

                    if clinchedComeback {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            FX.comeback()
                            withAnimation(.spring(duration: 0.6)) { isComeback = true }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .ready
                }
            }
        }
    }
}
