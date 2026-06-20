import SwiftUI

struct HomeView: View {
    let series: Series?
    @Environment(AppSettings.self) private var settings

    @State private var showAccount = false
    @State private var showFeedback = false
    @State private var quote = Quotes.random()

    private var accent: Color { settings.accent.color }
    private var todayGame: Game? { series?.games.first { $0.isToday } }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                welcome
                Spacer()
                seriesButton
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .onAppear { quote = Quotes.random() }
        .sheet(isPresented: $showAccount) { AccountView() }
        .alert("Feedback", isPresented: $showFeedback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Feedback is coming soon. Thanks for wanting to help shape Xcel.")
        }
    }

    // MARK: Top — wordmark + account avatar

    private var topBar: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Button { showAccount = true } label: {
                    Circle()
                        .fill(Color(white: 0.1))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(accent.opacity(0.6), lineWidth: 1.5))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color(white: 0.55))
                        )
                }
            }

            WavingTitle(text: "XCEL", accent: accent)
            XtinctBadge(accent: accent)
        }
        .padding(.top, 16)
    }

    // MARK: Center — greeting + quote

    private var welcome: some View {
        VStack(spacing: 18) {
            Text("Welcome back,")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(white: 0.45))
            + Text(" \(settings.userName)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(quote)
                .font(.system(size: 15, weight: .medium))
                .italic()
                .foregroundStyle(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    // MARK: Series status entry point

    @ViewBuilder
    private var seriesButton: some View {
        if let series {
            NavigationLink {
                SeriesView(series: series)
            } label: {
                VStack(spacing: 10) {
                    Text(statusHeadline(series))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .kerning(1.5)

                    HStack(spacing: 16) {
                        Text("\(series.wins)")
                            .foregroundStyle(accent)
                        Text("–")
                            .foregroundStyle(Color(white: 0.25))
                        Text("\(series.losses)")
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .font(.system(size: 52, weight: .black))
                    .monospacedDigit()

                    Text("Enter the arena")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(Color(white: 0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    // MARK: Bottom — feedback

    private var bottomBar: some View {
        Button { showFeedback = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "paperplane")
                Text("Send feedback")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(white: 0.4))
        }
        .padding(.bottom, 32)
    }

    private func statusHeadline(_ series: Series) -> String {
        switch series.seriesResult {
        case .won:  return "SERIES WON"
        case .lost: return "SERIES LOST"
        case .inProgress:
            if series.userFacingElimination { return "WIN OR GO HOME" }
            if let game = todayGame, game.verdict == .pending {
                return "GAME \(game.gameNumber) TONIGHT"
            }
            return "SERIES IN PROGRESS"
        }
    }
}
