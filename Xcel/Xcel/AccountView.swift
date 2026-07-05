import SwiftUI

// The landing page: a read-only profile card (tap for identity/sync/off-season
// management), Daily Tasks (kept here since it's touched every morning), and
// 3 category pages for everything else - Achievements, Customization,
// Notifications. Keeps the root scroll-free so nothing gets buried.
struct AccountView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showAccount = false
    @State private var showAchievements = false
    @State private var showCustomization = false
    @State private var showNotifications = false
    @State private var showRecurring = false

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            GeometryReader { geo in
              ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    profileCard

                    accountNavRow(icon: "repeat", title: "Daily tasks",
                                  subtitle: recurringSubtitle, accent: accent) { showRecurring = true }

                    accountNavRow(icon: "chart.bar.fill", title: "Achievements",
                                  subtitle: "Insights · Finals · Awards · Trophies", accent: accent) { showAchievements = true }

                    accountNavRow(icon: "paintpalette.fill", title: "Customization",
                                  subtitle: "Colors · Guide · Themes", accent: accent) { showCustomization = true }

                    accountNavRow(icon: "bell.fill", title: "Notifications",
                                  subtitle: notificationsSubtitle, accent: accent) { showNotifications = true }
                }
                .padding(24)
                .frame(width: geo.size.width, alignment: .leading)
              }
            }
        }
        .sheet(isPresented: $showAccount) { AccountCategoryView() }
        .sheet(isPresented: $showAchievements) { AchievementsView() }
        .sheet(isPresented: $showCustomization) { CustomizationView() }
        .sheet(isPresented: $showNotifications) { NotificationsSettingsView() }
        .sheet(isPresented: $showRecurring) { RecurringTasksView() }
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

    // Read-only display - tap to manage photo, name, sync, and off season.
    private var profileCard: some View {
        Button { showAccount = true } label: {
            HStack(spacing: 14) {
                AvatarView(data: settings.profileImageData, accent: accent, size: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.userName.isEmpty ? "Champ" : settings.userName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Manage account")
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

    private var recurringSubtitle: String {
        let n = settings.recurringTasks.count
        if n == 0 { return "Auto-add staples to every new day" }
        return "\(n) task\(n == 1 ? "" : "s") added to every new day"
    }

    private var notificationsSubtitle: String {
        settings.notificationsEnabled ? "Daily reminders on" : "Daily reminders off"
    }
}
