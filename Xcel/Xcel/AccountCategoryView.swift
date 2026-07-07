import SwiftUI
import PhotosUI
import UIKit

// Identity & account status: photo, name, cross-device sync, off-season
// requests, and the premium placeholder. Everything here is about "who you
// are" and "what tier you're on" - as opposed to stats (AchievementsView),
// cosmetics (CustomizationView), or reminders (NotificationsSettingsView).
struct AccountCategoryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syncService) private var sync

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
                AppleSignInCard(accent: accent)
                Text("Sign in to back up your history and unlock leagues later. Optional - everything works fully offline without this.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .signedIn(_, let name):
            accountNavRow(icon: "checkmark.seal.fill", title: "Signed in",
                          subtitle: name.isEmpty ? "Tap for account details" : name, accent: accent) {
                showAccountDetail = true
            }
        }
    }
}
