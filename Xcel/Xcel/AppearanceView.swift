import SwiftUI

// The cosmetics screen: pick a bundled court/arena "look". Light touch - a theme
// swaps the backdrop, court lines, and glow; the accent color stays its own pick.
// Everything is unlocked for the testing build.
struct AppearanceView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    Text("Pick your court. Your accent color rides on top of whichever look you choose.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.5))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(ArenaTheme.allCases) { theme in
                        themeCard(theme)
                    }
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("APPEARANCE")
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

    private func themeCard(_ theme: ArenaTheme) -> some View {
        let selected = theme == settings.theme
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { settings.theme = theme }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Live preview of the actual themed court.
                ZStack(alignment: .topTrailing) {
                    CourtBackground(theme: theme)
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                        .clipped()

                    // Show the accent layering on top, just like in-app.
                    Circle()
                        .fill(accent)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                        .padding(12)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(theme.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text(theme.tagline)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? accent : Color(white: 0.28))
                }
                .padding(16)
            }
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? accent : Color.white.opacity(0.06), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
