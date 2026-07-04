import SwiftUI

// A pushed summary row - never raw journal text/checklist/photos. Only
// series/games/verdicts/box scores/settings sync, per the Accounts & Sync
// design: raw entries stay private to the author.
struct SyncSeriesSummary: Codable {
    let id: UUID
    let weekStart: Date
    let isWarmup: Bool
    let wins: Int
    let losses: Int
    let seriesResult: String
    let recapHeadline: String
    let recapBody: String
    let followUpEvaluated: Bool
    let followUpHonored: Bool
}

struct SyncGameSummary: Codable {
    let id: UUID
    let seriesId: UUID
    let date: Date
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
}

struct SyncSettingsSummary: Codable {
    let accent: String
    let guide: String
    let theme: String
    let recurringTasks: [String]
    let notificationsEnabled: Bool
    let morningHour: Int
    let morningMinute: Int
    let eveningHour: Int
    let eveningMinute: Int
}

// Everything restored on a fresh device after sign-in.
struct RemoteHistory {
    let series: [SyncSeriesSummary]
    let games: [SyncGameSummary]
    let settings: SyncSettingsSummary?
}

enum SyncAuthState: Equatable {
    case signedOut
    case signedIn(userId: String, displayName: String)
}

enum SyncError: Error {
    case notSignedIn
    case network(Error)
    case appleCredentialFailed
}

// Mirrors JudgeService's protocol-shaped seam: views/services never talk to
// Supabase directly, only through this. A local-only build (or a signed-out
// user) uses NoOpSyncService and nothing about the daily ritual changes.
protocol SyncService {
    var authState: SyncAuthState { get }

    func signIn(appleIDToken: String, nonce: String, fullName: String?) async throws -> SyncAuthState
    func signOut() async throws

    // Never blocks the daily ritual on network - callers use `try?` and
    // silently swallow failures; the next app-open naturally retries with
    // fresh data since every push is a full-state upsert, not a queued diff.
    func pushSeries(_ series: [SyncSeriesSummary]) async throws
    func pushGames(_ games: [SyncGameSummary]) async throws
    func pushSettings(_ settings: SyncSettingsSummary) async throws

    // Restore-on-new-device: pulls everything back down once, after sign-in,
    // only when local history is empty.
    func fetchHistory() async throws -> RemoteHistory
}

// Default when signed out, or when Supabase isn't wired up yet. Every method
// is a safe no-op / empty result so call sites never need to branch on
// whether sync is actually configured.
@Observable
final class NoOpSyncService: SyncService {
    private(set) var authState: SyncAuthState = .signedOut
    func signIn(appleIDToken: String, nonce: String, fullName: String?) async throws -> SyncAuthState {
        throw SyncError.notSignedIn
    }
    func signOut() async throws {}
    func pushSeries(_ series: [SyncSeriesSummary]) async throws {}
    func pushGames(_ games: [SyncGameSummary]) async throws {}
    func pushSettings(_ settings: SyncSettingsSummary) async throws {}
    func fetchHistory() async throws -> RemoteHistory {
        RemoteHistory(series: [], games: [], settings: nil)
    }
}

// SyncService is a protocol (existential), so it can't ride through
// `.environment(_:)` the way a concrete @Observable class like AppSettings
// does - that API is generic over a concrete Observable type. This gives
// services (e.g. a future LeagueService) a way to reach it without knowing
// the concrete conformance.
private struct SyncServiceKey: EnvironmentKey {
    static let defaultValue: any SyncService = NoOpSyncService()
}
extension EnvironmentValues {
    var syncService: any SyncService {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
}
