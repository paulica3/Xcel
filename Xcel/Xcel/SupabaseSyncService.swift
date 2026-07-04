import Foundation
import Supabase

// The real SyncService conformance, wrapping the Supabase client. Lives in
// its own file so NoOpSyncService.swift (and the rest of the app) has zero
// dependency on the SDK - only this file and SyncService's environment
// wiring in XcelApp.swift need to know Supabase exists.
@Observable
final class SupabaseSyncService: SyncService {
    private let client: SupabaseClient
    private(set) var authState: SyncAuthState = .signedOut

    init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://fhpmrpnsjdsuvqbeylsc.supabase.co")!,
            supabaseKey: "sb_publishable_YVApB6jE8ntxSo6LQ5QZtQ_nhCBr42d"
        )
        Task { await restoreSession() }
    }

    // Restores from the SDK's own Keychain-persisted session on launch -
    // this is the actual source of truth, never duplicated into
    // AppSettings/UserDefaults.
    private func restoreSession() async {
        guard let session = try? await client.auth.session else { return }
        let name = (try? await fetchDisplayName(for: session.user.id)) ?? ""
        authState = .signedIn(userId: session.user.id.uuidString, displayName: name)
    }

    private func fetchDisplayName(for id: UUID) async throws -> String {
        struct Row: Decodable {
            let displayName: String
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
        let rows: [Row] = try await client.from("profiles")
            .select("display_name")
            .eq("id", value: id)
            .execute()
            .value
        return rows.first?.displayName ?? ""
    }

    func signIn(appleIDToken: String, nonce: String, fullName: String?) async throws -> SyncAuthState {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: appleIDToken, nonce: nonce)
            )
            let userId = session.user.id
            let profile = ProfileRow(id: userId, displayName: fullName ?? "")
            try? await client.from("profiles").upsert(profile).execute()

            let state = SyncAuthState.signedIn(userId: userId.uuidString, displayName: fullName ?? "")
            authState = state
            return state
        } catch {
            throw SyncError.appleCredentialFailed
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        authState = .signedOut
    }

    func pushSeries(_ series: [SyncSeriesSummary]) async throws {
        guard case .signedIn(let userIdString, _) = authState, let userId = UUID(uuidString: userIdString) else {
            throw SyncError.notSignedIn
        }
        guard !series.isEmpty else { return }
        let rows = series.map { SeriesRow(from: $0, userId: userId) }
        try await client.from("series").upsert(rows).execute()
    }

    func pushGames(_ games: [SyncGameSummary]) async throws {
        guard case .signedIn(let userIdString, _) = authState, let userId = UUID(uuidString: userIdString) else {
            throw SyncError.notSignedIn
        }
        guard !games.isEmpty else { return }
        let rows = games.map { GameRow(from: $0, userId: userId) }
        try await client.from("games").upsert(rows).execute()
    }

    func pushSettings(_ settings: SyncSettingsSummary) async throws {
        guard case .signedIn(let userIdString, _) = authState, let userId = UUID(uuidString: userIdString) else {
            throw SyncError.notSignedIn
        }
        let row = SettingsRow(from: settings, userId: userId)
        try await client.from("settings").upsert(row).execute()
    }

    func fetchHistory() async throws -> RemoteHistory {
        guard case .signedIn = authState else { throw SyncError.notSignedIn }
        let seriesRows: [SeriesRow] = try await client.from("series").select().execute().value
        let gameRows: [GameRow] = try await client.from("games").select().execute().value
        let settingsRows: [SettingsRow] = try await client.from("settings").select().execute().value
        return RemoteHistory(
            series: seriesRows.map { $0.toSummary() },
            games: gameRows.map { $0.toSummary() },
            settings: settingsRows.first?.toSummary()
        )
    }

    // "date" columns are Postgres `date` type - encode/decode as plain
    // yyyy-MM-dd strings in the device's local calendar day, matching how
    // the rest of the app already reasons about "today" (Calendar.current).
    fileprivate static func dateOnlyString(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    fileprivate static func dateOnlyDate(_ string: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        var comps = DateComponents()
        comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
        return cal.date(from: comps) ?? Date()
    }
}

// MARK: Row types - internal wire format, distinct from the public summary
// structs in SyncService.swift, since the DB rows carry `user_id` while the
// summary structs deliberately don't (they're user-agnostic payloads).

private struct ProfileRow: Encodable {
    let id: UUID
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

private struct SeriesRow: Codable {
    let id: UUID
    let userId: UUID
    let weekStart: String
    let isWarmup: Bool
    let wins: Int
    let losses: Int
    let seriesResult: String
    let recapHeadline: String
    let recapBody: String
    let followUpEvaluated: Bool
    let followUpHonored: Bool

    enum CodingKeys: String, CodingKey {
        case id, wins, losses
        case userId = "user_id"
        case weekStart = "week_start"
        case isWarmup = "is_warmup"
        case seriesResult = "series_result"
        case recapHeadline = "recap_headline"
        case recapBody = "recap_body"
        case followUpEvaluated = "follow_up_evaluated"
        case followUpHonored = "follow_up_honored"
    }

    init(from summary: SyncSeriesSummary, userId: UUID) {
        id = summary.id
        self.userId = userId
        weekStart = SupabaseSyncService.dateOnlyString(summary.weekStart)
        isWarmup = summary.isWarmup
        wins = summary.wins
        losses = summary.losses
        seriesResult = summary.seriesResult
        recapHeadline = summary.recapHeadline
        recapBody = summary.recapBody
        followUpEvaluated = summary.followUpEvaluated
        followUpHonored = summary.followUpHonored
    }

    func toSummary() -> SyncSeriesSummary {
        SyncSeriesSummary(
            id: id,
            weekStart: SupabaseSyncService.dateOnlyDate(weekStart),
            isWarmup: isWarmup,
            wins: wins,
            losses: losses,
            seriesResult: seriesResult,
            recapHeadline: recapHeadline,
            recapBody: recapBody,
            followUpEvaluated: followUpEvaluated,
            followUpHonored: followUpHonored
        )
    }
}

private struct GameRow: Codable {
    let id: UUID
    let seriesId: UUID
    let userId: UUID
    let date: String
    let gameNumber: Int
    let verdict: String
    let verdictOneLiner: String
    let scoreEffort: Double
    let scoreDiscipline: Double
    let scoreMood: Double
    let scoreProductivity: Double
    let excused: Bool
    let challenged: Bool
    let challengeOverturned: Bool
    let songTitle: String
    let songArtist: String

    enum CodingKeys: String, CodingKey {
        case id, verdict, excused, challenged, date
        case seriesId = "series_id"
        case userId = "user_id"
        case gameNumber = "game_number"
        case verdictOneLiner = "verdict_one_liner"
        case scoreEffort = "score_effort"
        case scoreDiscipline = "score_discipline"
        case scoreMood = "score_mood"
        case scoreProductivity = "score_productivity"
        case challengeOverturned = "challenge_overturned"
        case songTitle = "song_title"
        case songArtist = "song_artist"
    }

    init(from summary: SyncGameSummary, userId: UUID) {
        id = summary.id
        seriesId = summary.seriesId
        self.userId = userId
        date = SupabaseSyncService.dateOnlyString(summary.date)
        gameNumber = summary.gameNumber
        verdict = summary.verdict
        verdictOneLiner = summary.verdictOneLiner
        scoreEffort = summary.scoreEffort
        scoreDiscipline = summary.scoreDiscipline
        scoreMood = summary.scoreMood
        scoreProductivity = summary.scoreProductivity
        excused = summary.excused
        challenged = summary.challenged
        challengeOverturned = summary.challengeOverturned
        songTitle = summary.songTitle
        songArtist = summary.songArtist
    }

    func toSummary() -> SyncGameSummary {
        SyncGameSummary(
            id: id,
            seriesId: seriesId,
            date: SupabaseSyncService.dateOnlyDate(date),
            gameNumber: gameNumber,
            verdict: verdict,
            verdictOneLiner: verdictOneLiner,
            scoreEffort: scoreEffort,
            scoreDiscipline: scoreDiscipline,
            scoreMood: scoreMood,
            scoreProductivity: scoreProductivity,
            excused: excused,
            challenged: challenged,
            challengeOverturned: challengeOverturned,
            songTitle: songTitle,
            songArtist: songArtist
        )
    }
}

private struct SettingsRow: Codable {
    let userId: UUID
    let accent: String
    let guide: String
    let theme: String
    let recurringTasks: [String]
    let notificationsEnabled: Bool
    let morningHour: Int
    let morningMinute: Int
    let eveningHour: Int
    let eveningMinute: Int

    enum CodingKeys: String, CodingKey {
        case accent, guide, theme
        case userId = "user_id"
        case recurringTasks = "recurring_tasks"
        case notificationsEnabled = "notifications_enabled"
        case morningHour = "morning_hour"
        case morningMinute = "morning_minute"
        case eveningHour = "evening_hour"
        case eveningMinute = "evening_minute"
    }

    init(from summary: SyncSettingsSummary, userId: UUID) {
        self.userId = userId
        accent = summary.accent
        guide = summary.guide
        theme = summary.theme
        recurringTasks = summary.recurringTasks
        notificationsEnabled = summary.notificationsEnabled
        morningHour = summary.morningHour
        morningMinute = summary.morningMinute
        eveningHour = summary.eveningHour
        eveningMinute = summary.eveningMinute
    }

    func toSummary() -> SyncSettingsSummary {
        SyncSettingsSummary(
            accent: accent,
            guide: guide,
            theme: theme,
            recurringTasks: recurringTasks,
            notificationsEnabled: notificationsEnabled,
            morningHour: morningHour,
            morningMinute: morningMinute,
            eveningHour: eveningHour,
            eveningMinute: eveningMinute
        )
    }
}
