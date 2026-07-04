import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @Environment(\.syncService) private var sync
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    var currentSeries: Series? {
        let monday = Series.mondayOf(Date())
        return allSeries.first { Calendar.current.isDate($0.weekStart, inSameDayAs: monday) }
    }

    @State private var showLaunch = true

    var body: some View {
        ZStack {
            mainContent

            // The cold-open splash sits above everything (including onboarding) on
            // each fresh launch, then swipes away to reveal the app.
            if showLaunch {
                LaunchView(accent: settings.accent.color) {
                    withAnimation(.easeInOut(duration: 0.5)) { showLaunch = false }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }

    private var mainContent: some View {
        NavigationStack {
            HomeView(series: currentSeries,
                     stats: CareerStats.compute(from: allSeries),
                     postseason: Postseason.compute(from: allSeries))
        }
        .onAppear {
            ensureCurrentSeries()
            processMissedGames()
            let today = currentSeries?.games.first { $0.isToday }
            settings.setUpNotifications(
                // Plan's set -> skip today's morning/lock nudges.
                skipTodayMorning: today?.morningCompleted ?? false,
                // Day's already judged -> skip today's logging/evening nudges.
                skipTodayEvening: (today?.verdict ?? .pending) != .pending
            )
            refreshCheckups()
        }
        .task {
            // Judge any pending Challenge Call follow-throughs from completed weeks.
            await FollowThroughService.runPendingEvaluations(in: allSeries, context: modelContext)
        }
        .task {
            await syncOnAppear()
        }
        // Hold onboarding until the cold-open splash has been dismissed, so the
        // sequence reads splash -> onboarding -> home (a fullScreenCover would
        // otherwise present above the splash overlay and hide it).
        .fullScreenCover(isPresented: .constant(!settings.hasOnboarded && !showLaunch)) {
            OnboardingView()
        }
    }

    private func ensureCurrentSeries() {
        guard currentSeries == nil else { return }
        let monday = Series.mondayOf(Date())

        // The user's first-ever week is a warm-up if they joined after Monday -
        // they can't play the full series, so it's reps until the next Monday.
        let isFirstEver = allSeries.isEmpty
        let joinedMidWeek = !Calendar.current.isDate(Date(), inSameDayAs: monday)
            && Calendar.current.startOfDay(for: Date()) > Calendar.current.startOfDay(for: monday)
        let series = Series(weekStart: monday, isWarmup: isFirstEver && joinedMidWeek)
        modelContext.insert(series)

        for offset in 0..<7 {
            let gameDate = Calendar.current.date(byAdding: .day, value: offset, to: monday)!
            let game = Game(date: gameDate, gameNumber: offset + 1)
            series.games.append(game)
            modelContext.insert(game)
        }
        try? modelContext.save()
    }

    // Refresh the state-driven notifications (4pm check-up + high-stakes alerts)
    // with the current series score on each app open.
    private func refreshCheckups() {
        let series = currentSeries
        let wins = series?.wins ?? 0
        let losses = series?.losses ?? 0
        NotificationManager.scheduleCheckups(
            enabled: settings.notificationsEnabled,
            wins: wins, losses: losses
        )
        NotificationManager.scheduleStakes(
            enabled: settings.notificationsEnabled && settings.stakesNotificationsEnabled
                && !(series?.isWarmup ?? false),
            wins: wins, losses: losses
        )
    }

    // Mirrors the unconditional-recompute pattern refreshCheckups() already
    // uses: no persisted sync queue, just re-push the full current state
    // every open when signed in. Failures are swallowed - the next app-open
    // retries with fresh data, and this never blocks the daily ritual.
    private func syncOnAppear() async {
        guard case .signedIn = sync.authState else { return }

        if allSeries.isEmpty {
            if let history = try? await sync.fetchHistory() {
                restoreFromRemote(history)
            }
            return
        }

        let seriesSummaries = allSeries.map { series in
            SyncSeriesSummary(
                id: series.id,
                weekStart: series.weekStart,
                isWarmup: series.isWarmup,
                wins: series.wins,
                losses: series.losses,
                seriesResult: series.seriesResult.rawValue,
                recapHeadline: series.recapHeadline,
                recapBody: series.recapBody,
                followUpEvaluated: series.followUpEvaluated,
                followUpHonored: series.followUpHonored
            )
        }
        let gameSummaries = allSeries.flatMap(\.games).map { game in
            SyncGameSummary(
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
        }
        try? await sync.pushSeries(seriesSummaries)
        try? await sync.pushGames(gameSummaries)
    }

    // Only ever runs when local Series history is empty (a fresh device on an
    // already-signed-in account), so it can never clobber existing local data.
    private func restoreFromRemote(_ history: RemoteHistory) {
        guard !history.series.isEmpty else { return }
        var seriesByID: [UUID: Series] = [:]

        for summary in history.series {
            let series = Series(weekStart: summary.weekStart, isWarmup: summary.isWarmup)
            series.id = summary.id
            series.recapHeadline = summary.recapHeadline
            series.recapBody = summary.recapBody
            series.followUpEvaluated = summary.followUpEvaluated
            series.followUpHonored = summary.followUpHonored
            modelContext.insert(series)
            seriesByID[summary.id] = series
        }

        for summary in history.games {
            guard let series = seriesByID[summary.seriesId] else { continue }
            let game = Game(date: summary.date, gameNumber: summary.gameNumber)
            game.id = summary.id
            game.verdict = GameVerdict(rawValue: summary.verdict) ?? .pending
            game.verdictOneLiner = summary.verdictOneLiner
            game.scoreEffort = summary.scoreEffort
            game.scoreDiscipline = summary.scoreDiscipline
            game.scoreMood = summary.scoreMood
            game.scoreProductivity = summary.scoreProductivity
            game.excused = summary.excused
            game.challenged = summary.challenged
            game.challengeOverturned = summary.challengeOverturned
            game.songTitle = summary.songTitle
            game.songArtist = summary.songArtist
            series.games.append(game)
            modelContext.insert(game)
        }

        try? modelContext.save()
    }

    private func processMissedGames() {
        guard let series = currentSeries else { return }
        var changed = false
        for game in series.games where game.isMissed(seriesCreatedAt: series.createdAt) {
            game.verdict = .loss
            game.verdictOneLiner = "Didn't show up. Automatic L."
            changed = true
        }
        if changed { try? modelContext.save() }
    }
}
