import SwiftUI
import AuthenticationServices
import SwiftData
import OSLog

// The Sign in with Apple button plus the full handshake (nonce round-trip,
// credential parsing, first-sign-in history push) - shared between the
// Account row and the first-launch prompt so the auth logic only exists once.
struct AppleSignInCard: View {
    let accent: Color
    var onSignedIn: () -> Void = {}

    @Environment(AppSettings.self) private var settings
    @Environment(\.syncService) private var sync
    @Query private var allSeries: [Series]

    @State private var currentNonce = ""
    @State private var syncStatusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleAppleSignIn)
                .signInWithAppleButtonStyle(.white)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if let syncStatusMessage {
                Text(syncStatusMessage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.eliminationRed)
            }
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName]
        currentNonce = SignInWithApple.randomNonce()
        request.nonce = SignInWithApple.sha256(currentNonce)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                syncStatusMessage = "Couldn't complete sign in. Try again."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            // Apple only ever grants the name on the very first authorization
            // *ever* for this Apple ID + app pairing - if this account has
            // signed in to Xcel before, fullName is empty here every time,
            // even after a reinstall. Logged so an empty grant here isn't
            // mistaken for a sync bug.
            Logger(subsystem: "com.paulefrim.Xcel", category: "SignInWithApple")
                .info("Apple grant fullName=\(fullName.isEmpty ? "EMPTY (not first-ever grant)" : "present", privacy: .public)")
            let nonce = currentNonce
            Task {
                do {
                    _ = try await sync.signIn(appleIDToken: idToken, nonce: nonce, fullName: fullName.isEmpty ? nil : fullName)
                    if !fullName.isEmpty {
                        settings.applyRemoteName(fullName)
                    }
                    // Pull anything already stored on the account (e.g. set on
                    // another device) - a manual local edit always wins over this.
                    if let profile = try? await sync.fetchProfile() {
                        settings.applyRemoteName(profile.displayName)
                        if let b64 = profile.avatarBase64, let data = Data(base64Encoded: b64) {
                            settings.applyRemotePhoto(data)
                        }
                    }
                    await pushExistingHistory()
                    syncStatusMessage = nil
                    onSignedIn()
                } catch {
                    syncStatusMessage = "Sign in didn't go through. Try again."
                }
            }
        case .failure:
            // Silent - user cancelled, or an Apple-side hiccup; no disruptive
            // error UI for a feature that's entirely optional.
            break
        }
    }

    // First sign-in only: push everything already on this device up, since
    // the remote side starts empty. Never wipes anything locally.
    private func pushExistingHistory() async {
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
        let settingsSummary = SyncSettingsSummary(
            accent: settings.accent.rawValue,
            guide: settings.guide.rawValue,
            theme: settings.theme.rawValue,
            recurringTasks: settings.recurringTasks,
            notificationsEnabled: settings.notificationsEnabled,
            morningHour: Calendar.current.component(.hour, from: settings.morningTime),
            morningMinute: Calendar.current.component(.minute, from: settings.morningTime),
            eveningHour: Calendar.current.component(.hour, from: settings.eveningTime),
            eveningMinute: Calendar.current.component(.minute, from: settings.eveningTime)
        )
        let profileSummary = SyncProfileSummary(
            displayName: settings.userName,
            avatarBase64: settings.profileImageData?.base64EncodedString()
        )
        try? await sync.pushSeries(seriesSummaries)
        try? await sync.pushGames(gameSummaries)
        try? await sync.pushSettings(settingsSummary)
        try? await sync.pushProfile(profileSummary)
    }
}
