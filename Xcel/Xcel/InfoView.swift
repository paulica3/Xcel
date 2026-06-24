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
                             "Seven games, Monday through Sunday. A fresh series starts every week.")
                        rule("calendar", "Each game",
                             "Morning: set your game plan (at least 3 tasks). Night: log how it went with proof. The Judge calls it a W or L.")
                        rule("clock.badge.checkmark", "Logging window",
                             "Grade your day after 6:00 PM and before 11:59 PM. You can prep the entry earlier, but you only submit once you've actually played the day out.")
                        rule("basketball.fill", "The game ball",
                             "Tap the ○ next to your most important task to make it the game ball. The Judge leans hardest on it. Nail it and a close day tips your way.")
                        rule("camera.fill", "Photo proof",
                             "Marked a task done? Back it with a photo. Xcel checks the date and what's in it - all on your phone - and the Judge trusts verified, same-day proof the most.")
                        rule("trophy.fill", "Winning the series",
                             "First to 4 wins takes it. Clinch the series and you've moved on.")
                        rule("trophy.circle.fill", "Road to the Finals",
                             "Win four series to raise a banner and earn a ring. Stack rings to build a dynasty - find it under your profile.")
                        rule("bolt.circle.fill", "Momentum & power-ups",
                             "Win to bank Momentum, then spend it in the Locker Room: a Timeout excuses a past L, a Buzzer Beater re-opens one to replay.")
                        rule("flame.fill", "Comebacks",
                             "Down 1-3? Not dead. Win out and steal it 4-3 - the sweetest comeback in the game.")
                        rule("exclamationmark.triangle.fill", "Elimination",
                             "Three losses and your back's against the wall. Win or go home.")
                        rule("house.fill", "Home court advantage",
                             "When you're down 2+, the Judge eases up to keep you in the fight.")
                        rule("clock.badge.xmark", "Miss a game?",
                             "Skip a day and it's an automatic L. No-shows don't get a pass.")
                        rule("flag.fill", "Challenge Call",
                             "Think a loss was wrong? Contest it once a series. Make your case - own the mistake and how you'll fix it - and the judge can overturn the L into a W. Win or lose, you only get one. Win it and you're on the hook: live out the plan you promised next week, or you lose your challenge the series after.")
                        rule("repeat", "Daily tasks",
                             "Got staples you do every day? Set them in your profile and they'll auto-load into every new game plan - no re-typing.")
                        rule("building.columns.fill", "The Judge",
                             "Tough but fair. Rewards honesty and real effort - sees right through vague proof and excuses.")
                        rule("brain.head.profile", "The GM remembers",
                             "The Judge knows your history - your streak, your weak weekday, the task you keep dropping - and calls it like a GM who's watched every game.")
                        rule("person.wave.2.fill", "Your guide",
                             "Pick your guide's voice in your profile. It changes how the Judge talks to you, never how strictly you're scored.")
                        rule("figure.run", "Warm-up week",
                             "Join mid-week and your first few days are a warm-up - get your reps in. Your first real series tips off the next Monday.")
                    }

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
