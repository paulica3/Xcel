import SwiftUI

// A one-time, skippable pitch for Sign in with Apple, shown right after
// onboarding instead of leaving the account option buried three taps deep in
// Account. Never blocks entry - "Not now" is just as prominent as signing in,
// and this never shows again once dismissed either way (AppSettings.hasSeenSignInPrompt).
struct WelcomeSignInView: View {
    let onDone: () -> Void

    @Environment(AppSettings.self) private var settings
    private var accent: Color { settings.accent.color }

    private struct Benefit: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let benefits: [Benefit] = [
        Benefit(icon: "arrow.triangle.2.circlepath.icloud.fill",
                title: "Never lose your history",
                body: "New phone, reinstall, whatever - your series, streak, and rings come right back."),
        Benefit(icon: "person.2.fill",
                title: "Ready for leagues",
                body: "Playing with friends is coming - an account is the only thing it needs from you today."),
        Benefit(icon: "lock.fill",
                title: "Your entries stay private",
                body: "Only scores and results ever sync. Your actual journal text never leaves your device.")
    ]

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 44))
                        .foregroundStyle(accent)
                    Text("SAVE YOUR PROGRESS")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(2.5)
                        .foregroundStyle(accent)
                    Text("Back up your season")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 14) {
                    ForEach(benefits) { benefit in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: benefit.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(accent)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(benefit.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(benefit.body)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(white: 0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    AppleSignInCard(accent: accent, onSignedIn: onDone)

                    Button(action: onDone) {
                        Text("Not now")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}
