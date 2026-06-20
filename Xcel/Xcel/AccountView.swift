import SwiftUI

struct AccountView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { settings.accent.color }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    var body: some View {
        @Bindable var settings = settings

        return ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

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

                    section("COMING SOON") {
                        VStack(spacing: 0) {
                            placeholderRow("bell.fill", "Notifications")
                            divider
                            placeholderRow("person.crop.circle", "Profile photo")
                            divider
                            placeholderRow("crown.fill", "Go Premium")
                        }
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
            }
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color(white: 0.35))
            content()
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
