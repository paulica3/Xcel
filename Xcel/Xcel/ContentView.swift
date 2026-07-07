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
    // Home's wordmark/badge fade in only once the launch flight has docked onto
    // them (heroRevealed) - until then the splash's flying copies are the only
    // visible ones, so nothing shows doubled.
    @State private var heroRevealed = false
    // Where Home's wordmark/badge sit on screen, reported via HeroFrameKey in
    // the shared "hero" coordinate space. The launch splash flies its copies
    // exactly onto these frames, so the handoff swap is invisible.
    @State private var heroFrames: [String: CGRect] = [:]

    var body: some View {
        ZStack {
            mainContent

            // The cold-open splash sits above everything (including onboarding)
            // on each fresh launch. It auto-plays the hero transition, then
            // cross-fades: onReveal brings Home's real wordmark up underneath
            // the flying copy, onFinish removes the splash once they've fused.
            if showLaunch {
                LaunchView(accent: settings.accent.color,
                           homeWordmarkFrame: heroFrames["wordmark"] ?? .zero,
                           homeBadgeFrame: heroFrames["badge"] ?? .zero,
                           onReveal: {
                               withAnimation(.easeOut(duration: 0.2)) { heroRevealed = true }
                           },
                           onFinish: { showLaunch = false })
                .zIndex(1)
            }
        }
        .coordinateSpace(.named("hero"))
        .onPreferenceChange(HeroFrameKey.self) { heroFrames = $0 }
    }

    private var mainContent: some View {
        NavigationStack {
            HomeView(series: currentSeries,
                     stats: CareerStats.compute(from: allSeries),
                     postseason: Postseason.compute(from: allSeries),
                     heroActive: !heroRevealed)
        }
        .onAppear {
            ensureCurrentSeries()
            // Must run before processMissedGames() - it settles any day inside
            // an approved Off Season window so isMissed() (which only fires on
            // still-.pending days) never turns it into an auto-loss.
            applyOffSeasonPause()
            processMissedGames()
            let today = currentSeries?.games.first { $0.isToday }
            let isOffSeasonToday = OffSeasonService.isActive(settings.offSeasonPeriods, on: Date()) != nil
            // Don't request notification permission on the very first launch -
            // that system alert can appear stacked with the onboarding
            // fullScreenCover trying to present at the same instant, which is
            // exactly what testers reported as "a couple popups" burying
            // onboarding. Once onboarding is done, OnboardingView's own finish
            // action requests it instead, at a moment with nothing competing.
            if settings.hasOnboarded {
                settings.setUpNotifications(
                    // Plan's set -> skip today's morning/lock nudges.
                    skipTodayMorning: today?.morningCompleted ?? false,
                    // Day's already judged -> skip today's logging/evening nudges.
                    skipTodayEvening: (today?.verdict ?? .pending) != .pending,
                    suppressAll: isOffSeasonToday
                )
            }
            refreshCheckups(suppressAll: isOffSeasonToday)
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
        // otherwise present above the splash overlay and hide it). Ineligible
        // hardware gets the unsupported-device screen instead of onboarding,
        // and it takes priority - there's no path from it into the app.
        .fullScreenCover(isPresented: .constant(!JudgeService.isDeviceEligible && !showLaunch)) {
            UnsupportedDeviceView()
        }
        .fullScreenCover(isPresented: .constant(JudgeService.isDeviceEligible && !settings.hasOnboarded && !showLaunch)) {
            OnboardingView()
        }
        // Shown exactly once, right after onboarding - skippable, and skipped
        // entirely if the user is somehow already signed in (e.g. restored
        // from a backup that had synced before).
        .fullScreenCover(isPresented: .constant(
            JudgeService.isDeviceEligible && settings.hasOnboarded && !settings.hasSeenSignInPrompt
                && !showLaunch && !isSignedIn
        )) {
            WelcomeSignInView(onDone: { settings.hasSeenSignInPrompt = true })
        }
    }

    private var isSignedIn: Bool {
        if case .signedIn = sync.authState { return true }
        return false
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
    // with the current series score on each app open. `suppressAll` mutes both
    // without touching the user's actual notification preferences - used while
    // an Off Season vacation is active.
    private func refreshCheckups(suppressAll: Bool = false) {
        let series = currentSeries
        let wins = series?.wins ?? 0
        let losses = series?.losses ?? 0
        NotificationManager.scheduleCheckups(
            enabled: settings.notificationsEnabled && !suppressAll,
            wins: wins, losses: losses
        )
        NotificationManager.scheduleStakes(
            enabled: settings.notificationsEnabled && settings.stakesNotificationsEnabled
                && !(series?.isWarmup ?? false) && !suppressAll,
            wins: wins, losses: losses
        )
    }

    // Pre-settles any day inside an approved Off Season window: paused, not
    // scored, doesn't touch the streak/record (reuses the same `excused` flag
    // the Timeout power-up already relies on for that exclusion), and never
    // becomes an auto-loss since processMissedGames() only acts on days still
    // `.pending`.
    private func applyOffSeasonPause() {
        guard let series = currentSeries else { return }
        var changed = false
        for game in series.games where game.verdict == .pending
            && OffSeasonService.isActive(settings.offSeasonPeriods, on: game.date) != nil {
            game.verdict = .loss
            game.excused = true
            game.offSeason = true
            game.verdictOneLiner = "Off-season - this day is paused."
            changed = true
        }
        if changed { try? modelContext.save() }
    }

    // Mirrors the unconditional-recompute pattern refreshCheckups() already
    // uses: no persisted sync queue, just re-push the full current state
    // every open when signed in. Failures are swallowed - the next app-open
    // retries with fresh data, and this never blocks the daily ritual.
    private func syncOnAppear() async {
        guard case .signedIn = sync.authState else { return }

        // Pull in a name/photo set on another device before pushing this
        // device's state back up - a manual local edit always wins.
        if let profile = try? await sync.fetchProfile() {
            settings.applyRemoteName(profile.displayName)
            if let b64 = profile.avatarBase64, let data = Data(base64Encoded: b64) {
                settings.applyRemotePhoto(data)
            }
        }

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
                offSeason: game.offSeason,
                challenged: game.challenged,
                challengeOverturned: game.challengeOverturned,
                songTitle: game.songTitle,
                songArtist: game.songArtist
            )
        }
        try? await sync.pushSeries(seriesSummaries)
        try? await sync.pushGames(gameSummaries)
        try? await sync.pushProfile(SyncProfileSummary(
            displayName: settings.userName,
            avatarBase64: settings.profileImageData?.base64EncodedString()
        ))
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
            game.offSeason = summary.offSeason
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
