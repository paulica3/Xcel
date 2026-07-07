import SwiftUI

struct InfoView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    Text("Every week is a best-of-seven playoff series. Every day is a game. It's you vs. you - and the Judge is keeping score.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.6))

                    VStack(spacing: 12) {
                        rule("basketball.fill", "The series",
                             "Seven games, Monday through Sunday. First to 4 wins takes it.")
                        rule("calendar", "Each game",
                             "Morning: set your game plan. Night: log how it went. The Judge calls it a W or an L - tough but fair.")
                        rule("clock.badge.checkmark", "Logging window",
                             "You can only submit between 6:00 PM and 11:59 PM - prep earlier, but you grade after the day's actually played out.")
                        rule("clock.badge.xmark", "Miss a game?",
                             "Skip a day and it's an automatic L. No-shows don't get a pass.")
                        rule("flame.fill", "Comebacks happen",
                             "Down 1-3 isn't dead. Win out and steal it 4-3.")
                    }

                    Text("Everything else - game balls, photo proof, Challenge Calls, power-ups, awards, themes - is explained right where you use it.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.4))

                    XtinctBadge(accent: accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAYOFF MODE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("How it works")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(.top, 8)
    }

    private func rule(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
