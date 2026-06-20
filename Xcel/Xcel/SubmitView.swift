import SwiftUI
import SwiftData

struct SubmitView: View {
    let game: Game
    let entry: String
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var phase: Phase = .ready
    @State private var result: JudgeResult? = nil
    @State private var errorMessage: String? = nil

    enum Phase { case ready, judging, verdict }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            switch phase {
            case .ready:   readyView
            case .judging: judgingView
            case .verdict: if let r = result { verdictView(r) }
            }
        }
        .navigationBarHidden(true)
    }

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

                Text(entry)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .padding(.horizontal, 36)

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
                    .background(Color.neonGreen)
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
                .tint(Color.neonGreen)
                .scaleEffect(1.6)
            Text("The judge is watching…")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.38))
            Spacer()
        }
    }

    private func verdictView(_ r: JudgeResult) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Text(r.verdict == .win ? "W" : "L")
                    .font(.system(size: 120, weight: .black))
                    .foregroundStyle(r.verdict == .win ? Color.neonGreen : Color(white: 0.3))

                Text(r.oneLiner)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

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
                    .background(r.verdict == .win ? Color.neonGreen : Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }

    private func submit() {
        errorMessage = nil
        phase = .judging
        let record = game.series.map { "\($0.wins)–\($0.losses)" } ?? "0–0"

        Task {
            do {
                let judgeResult = try await JudgeService().judge(
                    intention: game.morningIntention.isEmpty ? nil : game.morningIntention,
                    entry: entry,
                    seriesRecord: record,
                    gameNumber: game.gameNumber
                )
                await MainActor.run {
                    game.eveningEntry = entry
                    game.verdict = judgeResult.verdict
                    game.verdictOneLiner = judgeResult.oneLiner
                    try? modelContext.save()
                    result = judgeResult
                    withAnimation(.spring(duration: 0.5)) { phase = .verdict }
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
