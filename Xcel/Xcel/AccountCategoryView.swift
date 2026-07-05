import SwiftUI
import PhotosUI
import UIKit
import AuthenticationServices
import SwiftData
import OSLog

// Identity & account status: photo, name, cross-device sync, off-season
// requests, and the premium placeholder. Everything here is about "who you
// are" and "what tier you're on" - as opposed to stats (AchievementsView),
// cosmetics (CustomizationView), or reminders (NotificationsSettingsView).
struct AccountCategoryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncService) private var sync
    @Query private var allSeries: [Series]

    @State private var currentNonce = ""
    @State private var syncStatusMessage: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var cropImage: IdentifiableImage?
    @State private var showAccountDetail = false
    @State private var showOffSeason = false

    private var accent: Color { settings.accent.color }

    var body: some View {
        @Bindable var settings = settings

        return ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                AccountCategoryHeader(kicker: "ACCOUNT", title: "Manage account", accent: accent, dismiss: { dismiss() })
                GeometryReader { geo in
                  ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        profilePhoto

                        accountSection("ACCOUNT SYNC") {
                            accountSyncContent
                        }

                        accountSection("YOUR NAME") {
                            TextField("Name", text: Binding(
                                get: { settings.userName },
                                set: { settings.userName = $0; settings.userNameIsCustom = true }
                            ))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(Color(white: 0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        accountNavRow(icon: "airplane", title: "Off season",
                                      subtitle: offSeasonSubtitle, accent: accent) { showOffSeason = true }

                        accountSection("COMING SOON") {
                            VStack(spacing: 0) {
                                accountPlaceholderRow("crown.fill", "Go Premium")
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(white: 0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(24)
                    .frame(width: geo.size.width, alignment: .leading)
                  }
                }
            }
        }
        .sheet(isPresented: $showAccountDetail) {
            AccountSyncDetailSheet(
                accent: accent,
                displayName: currentSyncDisplayName,
                avatarData: settings.profileImageData,
                onSignOut: { Task { try? await sync.signOut() } }
            )
        }
        .sheet(isPresented: $showOffSeason) { OffSeasonView() }
    }

    private var offSeasonSubtitle: String {
        let periods = settings.offSeasonPeriods
        if OffSeasonService.isActive(periods, on: Date()) != nil { return "Currently on vacation" }
        return "\(OffSeasonService.remainingThisYear(periods)) of \(OffSeasonService.maxPerYear) trips left this year"
    }

    private var profilePhoto: some View {
        VStack(spacing: 12) {
            AvatarView(data: settings.profileImageData, accent: accent, size: 96)

            // The name sits right under the photo - the profile's headline.
            Text(settings.userName.isEmpty ? "Champ" : settings.userName)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(settings.profileImageData == nil ? "Choose photo" : "Change photo")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(accent)
                        .clipShape(Capsule())
                }

                if settings.profileImageData != nil {
                    Button {
                        settings.profileImageData = nil
                        settings.profileImageIsCustom = true
                        photoItem = nil
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(white: 0.6))
                            .padding(10)
                            .background(Color(white: 0.12))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                // Load the picked image, then let the user crop it to the circle
                // before it's set as their avatar.
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    await MainActor.run { cropImage = IdentifiableImage(image: ui) }
                }
            }
        }
        .fullScreenCover(item: $cropImage) { wrapper in
            ProfileCropView(
                image: wrapper.image,
                accent: accent,
                onCrop: { data in
                    settings.profileImageData = data
                    settings.profileImageIsCustom = true
                    cropImage = nil
                    photoItem = nil
                },
                onCancel: {
                    cropImage = nil
                    photoItem = nil
                }
            )
        }
    }

    // MARK: Account Sync

    private var currentSyncDisplayName: String {
        if case .signedIn(_, let name) = sync.authState { return name }
        return ""
    }

    @ViewBuilder
    private var accountSyncContent: some View {
        switch sync.authState {
        case .signedOut:
            VStack(alignment: .leading, spacing: 10) {
                SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleAppleSignIn)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("Sign in to back up your history and unlock leagues later. Optional - everything works fully offline without this.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
                if let syncStatusMessage {
                    Text(syncStatusMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.eliminationRed)
                }
            }
        case .signedIn(_, let name):
            accountNavRow(icon: "checkmark.seal.fill", title: "Signed in",
                          subtitle: name.isEmpty ? "Tap for account details" : name, accent: accent) {
                showAccountDetail = true
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
