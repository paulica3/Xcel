import SwiftUI
import SwiftData

struct SubmitView: View {
    let game: Game
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncService) private var sync
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]
    @State private var phase: Phase = .ready
    @State private var result: JudgeResult? = nil
    @State private var errorMessage: String? = nil
    @State private var play: VerdictPlay? = nil
    @State private var showCelebration = false
    @State private var celebrationTitle = ""
    @State private var celebrationSubtitle = ""

    private var accent: Color { settings.accent.color }

    // The judge's long-term read of the player, built fresh from history. The
    // current week is excluded so today's in-progress series doesn't skew it.
    private var seasonMemory: SeasonMemory {
        SeasonMemory.build(from: allSeries, excluding: game.series?.id)
    }

    enum Phase { case ready, judging, revealing, verdict }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            switch phase {
            case .ready:   readyView
            case .judging: judgingView
            case .revealing:
                if let p = play {
                    VerdictRevealView(
                        play: p,
                        accent: accent,
                        onClimax: { p.isWin ? FX.win() : FX.loss() },
                        onFinished: revealFinished
                    )
                }
            case .verdict: if let r = result { verdictView(r) }
            }

            if showCelebration {
                CelebrationOverlay(
                    title: celebrationTitle,
                    subtitle: celebrationSubtitle,
                    accent: accent,
                    onDismiss: { withAnimation { showCelebration = false } }
                )
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: Ready - confirm the day

    private var readyView: some View {
        VStack(spacing: 0) {
            // Last chance to back out before the verdict - pop back to the entry.
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
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
            if let nudge = seasonMemory.nudge {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text(nudge)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(accent.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 4)
            }
            if let note = JudgeService.practiceJudgeNote {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }
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

    // MARK: Verdict - W/L + coach's notes

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

                if r.effort + r.discipline + r.mood + r.productivity > 0 {
                    BoxScoreView(effort: r.effort, discipline: r.discipline,
                                 mood: r.mood, productivity: r.productivity, accent: accent)
                        .padding(.horizontal, 28)
                }

                if let series = game.series {
                    Text("\(series.wins)–\(series.losses) in the series")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.38))
                }

                ShareCardButton(content: shareContent(r), accent: accent)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
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

    private func shareContent(_ r: JudgeResult) -> ShareCardContent {
        let wins = game.series?.wins ?? 0
        let losses = game.series?.losses ?? 0
        return ShareCardContent(
            tag: "GAME \(game.gameNumber)",
            big: r.verdict == .win ? "W" : "L",
            bigIsWin: r.verdict == .win,
            headline: r.oneLiner,
            sub: "\(wins)–\(losses) in the series",
            songCredit: game.hasSong ? "🎵 \(game.songTitle) — \(game.songArtist)" : ""
        )
    }

    // MARK: After the reveal animation - show verdict, then any celebration

    private func revealFinished() {
        withAnimation(.spring(duration: 0.45)) { phase = .verdict }

        guard let series = game.series, result?.verdict == .win else { return }

        if series.seriesResult == .won {
            // A series win that completes a 4-series run raises a banner - the
            // biggest moment in the app, so it trumps the usual series celebration.
            let ring = Postseason.ringClinched(by: series, in: allSeries)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                FX.comeback()
                if ring {
                    let rings = Postseason.compute(from: allSeries).rings
                    celebrationTitle = "CHAMPIONS"
                    celebrationSubtitle = rings <= 1
                        ? "Four series. One ring. You're a champion."
                        : "Banner number \(rings). Build the dynasty."
                } else if series.wasComeback {
                    celebrationTitle = "COMEBACK"
                    celebrationSubtitle = "Down and out - and you took the series anyway."
                } else if series.wins == series.losses {
                    celebrationTitle = "SERIES WON"
                    celebrationSubtitle = "Level at \(series.wins)–\(series.losses) - you took it on grit when life got a vote."
                } else {
                    celebrationTitle = "SERIES WON"
                    celebrationSubtitle = "You took the series \(series.wins)–\(series.losses)."
                }
                withAnimation(.spring(duration: 0.5)) { showCelebration = true }
            }
        }
    }

    // MARK: Submit

    private func submit() {
        errorMessage = nil
        phase = .judging
        let wins = game.series?.wins ?? 0
        let losses = game.series?.losses ?? 0
        // Snapshot the memory briefing on the main actor before the async hop.
        let memoryBriefing = seasonMemory.briefing

        Task {
            do {
                let judgeResult = try await JudgeService().judge(
                    checklist: game.checklist,
                    extraNotes: game.extraNotes,
                    wins: wins,
                    losses: losses,
                    gameNumber: game.gameNumber,
                    guide: settings.guide,
                    memory: memoryBriefing
                )
                await MainActor.run {
                    game.verdict = judgeResult.verdict
                    game.verdictOneLiner = judgeResult.oneLiner
                    game.verdictFeedback = judgeResult.feedback
                    game.scoreEffort = judgeResult.effort
                    game.scoreDiscipline = judgeResult.discipline
                    game.scoreMood = judgeResult.mood
                    game.scoreProductivity = judgeResult.productivity
                    try? modelContext.save()
                    result = judgeResult

                    // Hand off to the animated play; FX + verdict fire from there.
                    play = VerdictPlay.random(for: judgeResult.verdict)
                    withAnimation(.easeInOut(duration: 0.3)) { phase = .revealing }

                    // Best-effort - a future league standings view shouldn't wait
                    // for the next app-open to see today's result.
                    if case .signedIn = sync.authState {
                        let summary = SyncGameSummary(
                            id: game.id,
                            seriesId: game.series?.id ?? UUID(),
                            date: game.date,
                            gameNumber: game.gameNumber,
                            verdict: game.verdict.rawValue,
                            verdictOneLiner: game.verdictOneLiner,
                            scoreEffort: game.scoreEffort,
                            scoreDiscipline: game.scoreDiscipline,
                            scoreMood: game.scoreMood,
                            scoreProductivity: game.scoreProductivity,
                            excused: game.excused,
                            challenged: game.challenged,
                            challengeOverturned: game.challengeOverturned,
                            songTitle: game.songTitle,
                            songArtist: game.songArtist
                        )
                        Task { try? await sync.pushGames([summary]) }
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
