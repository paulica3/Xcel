import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @State private var page = 0

    private var accent: Color { settings.accent.color }

    private struct Slide: Identifiable {
        let id = UUID()
        let icon: String
        let kicker: String
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        Slide(icon: "basketball.fill",
              kicker: "THE FORMAT",
              title: "Your week is a playoff series",
              body: "Seven games, Monday to Sunday. Each day is one game. Win 4 and you take the series."),
        Slide(icon: "building.columns.fill",
              kicker: "THE JUDGE",
              title: "Every night, you get a verdict",
              body: "Set a game plan in the morning - tap one task as your game ball, the one that matters most. The Judge calls the day a W or an L. Tough but fair."),
        Slide(icon: "clock.badge.checkmark",
              kicker: "THE WINDOW",
              title: "Prove it after 6 PM",
              body: "Prep your plan any time, but the result only logs between 6:00 PM and 11:59 PM. Back a done task with a photo - it's checked on your phone, and proof the Judge can trust counts for more."),
        Slide(icon: "flame.fill",
              kicker: "THE STAKES",
              title: "A loss isn't the end",
              body: "Down 1-3? Storm back and steal it 4-3 - the best feeling in the game. Miss a day and it's an automatic L. Show up."),
        Slide(icon: "flag.fill",
              kicker: "THE CHALLENGE",
              title: "Think a call was wrong?",
              body: "Contest one loss a series. Own the mistake and show how you'll fix it - the Judge can overturn it into a W. Win it and you're on the hook: live out your plan next week, or you lose your challenge."),
        Slide(icon: "trophy.circle.fill",
              kicker: "THE LONG GAME",
              title: "Build a dynasty",
              body: "Win four series to raise a banner and earn a ring. Bank Momentum from your wins and spend it on power-ups. The Judge even remembers your history - it coaches like a GM who's seen every game."),
        Slide(icon: "person.crop.circle.fill",
              kicker: "MAKE IT YOURS",
              title: "Set your style",
              body: "Pick your accent color, your court theme, and your guide's voice in your profile. Set recurring daily tasks so your staples load into every plan - or draft a whole plan with AI from a one-line intention.")
    ]

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        slideView(slide).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                dots
                    .padding(.bottom, 20)

                button
                    .padding(.horizontal, 24)
                    .padding(.bottom, 44)
            }
        }
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: slide.icon)
                .font(.system(size: 64))
                .foregroundStyle(accent)
            VStack(spacing: 12) {
                Text(slide.kicker)
                    .font(.system(size: 12, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text(slide.title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(slide.body)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(slides.indices, id: \.self) { i in
                Circle()
                    .fill(i == page ? accent : Color(white: 0.25))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var button: some View {
        Button {
            if page < slides.count - 1 {
                withAnimation { page += 1 }
            } else {
                withAnimation { settings.hasOnboarded = true }
            }
        } label: {
            Text(page < slides.count - 1 ? "Next" : "Enter the arena")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
