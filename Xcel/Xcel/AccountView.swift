import SwiftUI
import PhotosUI
import UIKit
import AuthenticationServices
import SwiftData

struct AccountView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncService) private var sync
    @Environment(\.modelContext) private var modelContext
    @Query private var allSeries: [Series]

    @State private var currentNonce = ""
    @State private var syncStatusMessage: String?

    @State private var photoItem: PhotosPickerItem?
    @State private var cropImage: IdentifiableImage?
    @State private var showInsights = false
    @State private var showTrophies = false
    @State private var showPostseason = false
    @State private var showPowerUps = false
    @State private var showRecurring = false
    @State private var showAwards = false
    @State private var showAppearance = false

    private var accent: Color { settings.accent.color }

    // Accent swatches laid out in fixed rows of 4 (non-lazy - see ACCENT COLOR).
    private var swatchRows: [[AccentTheme]] {
        stride(from: 0, to: AccentTheme.allCases.count, by: 4).map { start in
            Array(AccentTheme.allCases[start..<min(start + 4, AccentTheme.allCases.count)])
        }
    }

    var body: some View {
        @Bindable var settings = settings

        return ZStack {
            Color.arenaBlack.ignoresSafeArea()

            GeometryReader { geo in
              ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    profilePhoto

                    appearanceRow
                    insightsRow
                    postseasonRow
                    awardsRow
                    powerUpsRow
                    recurringRow
                    trophyRow

                    section("ACCOUNT SYNC") {
                        accountSyncContent
                    }

                    section("YOUR NAME") {
                        TextField("Name", text: $settings.userName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color(white: 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    section("ACCENT COLOR") {
                        // A plain (non-lazy) grid: LazyVGrid recalculates as the
                        // ScrollView scrolls and can briefly overflow the width,
                        // dragging the whole page sideways. 8 swatches don't need
                        // laziness, so lay them out in fixed rows of 4.
                        VStack(spacing: 14) {
                            ForEach(swatchRows, id: \.self) { row in
                                HStack(spacing: 14) {
                                    ForEach(row) { theme in
                                        swatch(theme)
                                            .frame(maxWidth: .infinity)
                                    }
                                    // Pad a short final row so cells keep their width.
                                    if row.count < 4 {
                                        ForEach(0..<(4 - row.count), id: \.self) { _ in
                                            Color.clear.frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    section("YOUR GUIDE") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Changes how the Judge talks to you. Never how you're scored.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.4))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 2)
                            ForEach(Guide.allCases) { g in
                                guideRow(g)
                            }
                        }
                    }

                    section("REMINDERS") {
                        VStack(spacing: 0) {
                            Toggle(isOn: $settings.notificationsEnabled) {
                                HStack(spacing: 14) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(accent)
                                        .frame(width: 24)
                                    Text("Daily reminders")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                }
                            }
                            .tint(accent)
                            .padding(16)

                            if settings.notificationsEnabled {
                                divider
                                timeRow("sunrise.fill", "Morning plan", $settings.morningTime)
                                divider
                                timeRow("moon.stars.fill", "Evening log", $settings.eveningTime)
                                divider
                                Toggle(isOn: $settings.stakesNotificationsEnabled) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.eliminationRed)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("High-stakes alerts")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.white)
                                            Text("Elimination & comeback games")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color(white: 0.4))
                                        }
                                    }
                                }
                                .tint(accent)
                                .padding(16)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    section("MORE NOTIFICATIONS") {
                        Text("You also get a noon lock reminder and a 4 PM check-up with your score. All daily reminders turn off with the toggle above.")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("COMING SOON") {
                        VStack(spacing: 0) {
                            placeholderRow("crown.fill", "Go Premium")
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                // Hard-clamp the scroll content to the exact viewport width. A
                // child that reports a width wider than the screen would let the
                // ScrollView pan horizontally - and .frame(maxWidth:) does NOT
                // prevent that (it only proposes a size; a child can still report
                // wider). A fixed width makes horizontal scroll impossible; any
                // overflow is clipped rather than scrollable.
                .padding(24)
                .frame(width: geo.size.width, alignment: .leading)
              }
            }
        }
        .sheet(isPresented: $showInsights) { InsightsView() }
        .sheet(isPresented: $showTrophies) { TrophyCaseView() }
        .sheet(isPresented: $showPostseason) { RoadToFinalsView() }
        .sheet(isPresented: $showPowerUps) { PowerUpsView() }
        .sheet(isPresented: $showRecurring) { RecurringTasksView() }
        .sheet(isPresented: $showAwards) { AwardsView() }
        .sheet(isPresented: $showAppearance) { AppearanceView() }
    }

    private var postseasonRow: some View {
        navRow(icon: "trophy.circle.fill", title: "Road to the Finals",
               subtitle: "Your playoff run · rings & banners") { showPostseason = true }
    }

    private var appearanceRow: some View {
        navRow(icon: "paintpalette.fill", title: "Appearance",
               subtitle: "Court themes · \(settings.theme.displayName)") { showAppearance = true }
    }

    private var awardsRow: some View {
        navRow(icon: "rosette", title: "Awards night",
               subtitle: "Monthly silverware") { showAwards = true }
    }

    private var powerUpsRow: some View {
        navRow(icon: "bolt.circle.fill", title: "Locker room",
               subtitle: "Spend Momentum on power-ups") { showPowerUps = true }
    }

    private var recurringRow: some View {
        navRow(icon: "repeat", title: "Daily tasks",
               subtitle: recurringSubtitle) { showRecurring = true }
    }

    private var recurringSubtitle: String {
        let n = settings.recurringTasks.count
        if n == 0 { return "Auto-add staples to every new day" }
        return "\(n) task\(n == 1 ? "" : "s") added to every new day"
    }

    // Shared styling for the tappable destination rows.
    private func navRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(14)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.25), lineWidth: 1))
        }
    }

    private var trophyRow: some View {
        Button { showTrophies = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trophy case")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("All-time badges & achievements")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(14)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.25), lineWidth: 1))
        }
    }

    private var insightsRow: some View {
        Button { showInsights = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Season insights")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Monthly verdict")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
            }
            .padding(14)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.25), lineWidth: 1))
        }
    }

    private var header: some View {
        HStack {
            Text("ACCOUNT")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(.top, 8)
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color(white: 0.35))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Shows the comic portrait once its asset exists; falls back to a glyph tile.
    @ViewBuilder
    private func guideAvatar(_ g: Guide, selected: Bool) -> some View {
        if UIImage(named: g.imageName) != nil {
            Image(g.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? accent : .clear, lineWidth: 2))
        } else {
            Image(systemName: g.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selected ? .black : accent)
                .frame(width: 46, height: 46)
                .background(selected ? accent : Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func guideRow(_ g: Guide) -> some View {
        let selected = g == settings.guide
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { settings.guide = g }
        } label: {
            HStack(spacing: 14) {
                guideAvatar(g, selected: selected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(g.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(g.blurb)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? accent : Color(white: 0.25))
            }
            .padding(14)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? accent.opacity(0.4) : .clear, lineWidth: 1))
        }
    }

    private func swatch(_ theme: AccentTheme) -> some View {
        let selected = theme == settings.accent
        return Button {
            withAnimation(.spring(duration: 0.3)) { settings.accent = theme }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(theme.color)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: selected ? 3 : 0)
                            .padding(2)
                    )
                    .shadow(color: theme.color.opacity(selected ? 0.6 : 0), radius: 8)
                Text(theme.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(selected ? .white : Color(white: 0.4))
                    .lineLimit(1)
            }
        }
    }

    private func timeRow(_ icon: String, _ label: String, _ time: Binding<Date>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.5))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(accent)
        }
        .padding(16)
    }

    private func placeholderRow(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.4))
                .frame(width: 24)
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.55))
            Spacer()
            Text("Soon")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(16)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(white: 0.12))
            .frame(height: 1)
            .padding(.leading, 54)
    }

    // MARK: Account Sync

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
            VStack(alignment: .leading, spacing: 0) {
                navRow(icon: "checkmark.seal.fill", title: "Signed in", subtitle: name.isEmpty ? "Synced" : name) {}
                    .disabled(true)
                Button {
                    Task { try? await sync.signOut() }
                } label: {
                    Text("Sign out")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.5))
                }
                .padding(.top, 10)
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
            let nonce = currentNonce
            Task {
                do {
                    _ = try await sync.signIn(appleIDToken: idToken, nonce: nonce, fullName: fullName.isEmpty ? nil : fullName)
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
        try? await sync.pushSeries(seriesSummaries)
        try? await sync.pushGames(gameSummaries)
        try? await sync.pushSettings(settingsSummary)
    }
}
