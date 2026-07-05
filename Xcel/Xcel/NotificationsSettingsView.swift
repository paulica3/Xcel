import SwiftUI

struct NotificationsSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { settings.accent.color }

    var body: some View {
        @Bindable var settings = settings

        return ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                AccountCategoryHeader(kicker: "NOTIFICATIONS", title: "Reminders", accent: accent, dismiss: { dismiss() })
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        accountSection("REMINDERS") {
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
                                    accountDivider()
                                    timeRow("sunrise.fill", "Morning plan", $settings.morningTime)
                                    accountDivider()
                                    timeRow("moon.stars.fill", "Evening log", $settings.eveningTime)
                                    accountDivider()
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

                        accountSection("MORE NOTIFICATIONS") {
                            Text("You also get a noon lock reminder and a 4 PM check-up with your score. All daily reminders turn off with the toggle above.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.4))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(24)
                }
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
}
