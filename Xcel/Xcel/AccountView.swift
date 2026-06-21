import SwiftUI
import PhotosUI
import UIKit

struct AccountView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var showInsights = false
    @State private var showTrophies = false

    private var accent: Color { settings.accent.color }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        @Bindable var settings = settings

        return ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    profilePhoto

                    insightsRow
                    trophyRow

                    section("YOUR NAME") {
                        TextField("Name", text: $settings.userName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(Color(white: 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    section("ACCENT COLOR") {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(AccentTheme.allCases) { theme in
                                swatch(theme)
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
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showInsights) { InsightsView() }
        .sheet(isPresented: $showTrophies) { TrophyCaseView() }
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
                    Text("Monthly verdict · where you're struggling")
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
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    settings.profileImageData = data
                }
            }
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
                    Text(g.blurb)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.45))
                        .fixedSize(horizontal: false, vertical: true)
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
}
