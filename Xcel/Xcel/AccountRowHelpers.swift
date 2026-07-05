import SwiftUI

// Shared visual language for the Account landing page and its category pages
// (AccountCategoryView, AchievementsView, CustomizationView,
// NotificationsSettingsView) - extracted so none of them have to duplicate
// this styling. `swatch`, `guideRow`, and `timeRow` stay single-owner in
// whichever page actually uses them.

func accountSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .kerning(2)
            .foregroundStyle(Color(white: 0.35))
        content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

func accountNavRow(icon: String, title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
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

func accountDivider() -> some View {
    Rectangle()
        .fill(Color(white: 0.12))
        .frame(height: 1)
        .padding(.leading, 54)
}

func accountPlaceholderRow(_ icon: String, _ label: String) -> some View {
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

// Shared header chrome (kicker + big title + dismiss) used by every Account
// category page - mirrors the pattern already used by RecurringTasksView,
// AwardsView, AppearanceView, etc.
struct AccountCategoryHeader: View {
    let kicker: String
    let title: String
    let accent: Color
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kicker)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}
