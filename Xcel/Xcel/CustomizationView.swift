import SwiftUI
import UIKit

// Cosmetics: arena theme, accent color, guide voice. None of this changes
// scoring or layout - purely how the app looks/talks.
struct CustomizationView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showAppearance = false

    private var accent: Color { settings.accent.color }

    // Accent swatches laid out in fixed rows of 4 - see swatch grid below.
    private var swatchRows: [[AccentTheme]] {
        stride(from: 0, to: AccentTheme.allCases.count, by: 4).map { start in
            Array(AccentTheme.allCases[start..<min(start + 4, AccentTheme.allCases.count)])
        }
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                AccountCategoryHeader(kicker: "CUSTOMIZATION", title: "Look & feel", accent: accent, dismiss: { dismiss() })
                GeometryReader { geo in
                  ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                    accountNavRow(icon: "paintpalette.fill", title: "Appearance",
                                  subtitle: "Court themes · \(settings.theme.displayName)", accent: accent) { showAppearance = true }

                    accountSection("ACCENT COLOR") {
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

                    accountSection("YOUR GUIDE") {
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
                    }
                    .padding(24)
                    .frame(width: geo.size.width, alignment: .leading)
                  }
                }
            }
        }
        .sheet(isPresented: $showAppearance) { AppearanceView() }
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
}
