import SwiftUI
import UIKit

struct HomeView: View {
    let series: Series?
    let stats: CareerStats
    let postseason: Postseason
    // True while the launch splash is still up - Home's own wordmark/badge stay
    // hidden so the splash's flying copies are the only ones visible, then swap
    // in pixel-exact once the flight docks.
    var heroActive: Bool
    @Environment(AppSettings.self) private var settings

    @State private var showAccount = false
    @State private var showInfo = false
    @State private var showFeedback = false
    @State private var quote = Quotes.random()

    private var accent: Color { settings.accent.color }
    private var todayGame: Game? { series?.games.first { $0.isToday } }

    // True elimination: lose tonight and the series is over.
    private var eliminationActive: Bool {
        guard let series, series.seriesResult == .inProgress else { return false }
        return series.userFacingElimination
    }

    var body: some View {
        ZStack {
            CourtBackground()

            VStack(spacing: 0) {
                topBar
                Spacer()
                welcome
                Spacer()
                seriesButton
                if stats.hasHistory {
                    statsStrip
                        .padding(.top, 18)
                }
                if postseason.rings > 0, let title = postseason.dynastyTitle {
                    championshipBanner(title)
                        .padding(.top, 10)
                }
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
        .onAppear { quote = Quotes.random() }
        .sheet(isPresented: $showAccount) { AccountView() }
        .sheet(isPresented: $showInfo) { InfoView() }
        .sheet(isPresented: $showFeedback) { FeedbackSheet(accent: accent) }
    }

    // MARK: Top - wordmark + account avatar

    private var topBar: some View {
        VStack(spacing: 6) {
            HStack {
                Button { showInfo = true } label: {
                    Circle()
                        .fill(Color(white: 0.1))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(accent.opacity(0.6), lineWidth: 1.5))
                        .overlay(
                            Image(systemName: "info")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(white: 0.55))
                        )
                }
                Spacer()
                Button { showAccount = true } label: {
                    AvatarView(data: settings.profileImageData, accent: accent, size: 40)
                }
            }

            WavingTitle(text: "XCEL", accent: accent)
                .reportHeroFrame("wordmark")
                .opacity(heroActive ? 0 : 1)
            XtinctBadge(accent: accent)
                .reportHeroFrame("badge")
                .opacity(heroActive ? 0 : 1)
        }
        .padding(.top, 16)
    }

    // MARK: Center - greeting + quote

    private var welcome: some View {
        VStack(spacing: 14) {
            let greeting: AttributedString = {
                var s = AttributedString("Welcome back,")
                s.font = .system(size: 20, weight: .semibold)
                s.foregroundColor = Color(white: 0.6)
                var name = AttributedString(" \(settings.userName)")
                name.font = .system(size: 22, weight: .black)
                name.foregroundColor = accent
                s.append(name)
                return s
            }()
            Text(greeting)

            Text("\u{201C}\(quote)\u{201D}")
                .font(.system(size: 16, weight: .semibold))
                .italic()
                .foregroundStyle(Color(white: 0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
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
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(eliminationActive ? Color.eliminationRed : accent)
                        .kerning(1.5)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Text("\(series.wins)")
                            .foregroundStyle(eliminationActive ? Color.eliminationRed : accent)
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
                .overlay(seriesBorder)
            }
        }
    }

    @ViewBuilder
    private var seriesBorder: some View {
        if eliminationActive {
            // Pulsing red ring - the stakes follow you to the landing page.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.35 + 0.45 * (0.5 + 0.5 * sin(t * 3.0))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.eliminationRed.opacity(pulse), lineWidth: 2)
                    .shadow(color: Color.eliminationRed.opacity(pulse * 0.6), radius: 10)
            }
        } else {
            RoundedRectangle(cornerRadius: 20)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: Season identity - record, streak, best comeback

    private var statsStrip: some View {
        HStack(spacing: 12) {
            statTile(value: "\(stats.wins)–\(stats.losses)", label: "RECORD", hot: false)
            statTile(
                value: stats.currentStreak > 0 ? "\(stats.currentStreak)🔥" : "-",
                label: "STREAK",
                hot: stats.currentStreak >= 3
            )
            statTile(
                value: stats.bestComebackDeficit > 0 ? "−\(stats.bestComebackDeficit)" : "-",
                label: "BEST COMEBACK",
                hot: false
            )
        }
    }

    // Banner on the wall: shown once the user has won it all at least once.
    private func championshipBanner(_ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 13))
            Text(title)
                .font(.system(size: 12, weight: .black))
                .kerning(1.5)
            if postseason.rings > 1 {
                Text("· \(postseason.rings) RINGS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.07))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
    }

    private func statTile(value: String, label: String, hot: Bool) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(hot ? accent : .white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .kerning(1)
                .foregroundStyle(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Bottom - feedback

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
            if series.isWarmup { return "WARM-UP WEEK" }
            if series.userFacingElimination { return "ELIMINATION GAME TONIGHT" }
            if let game = todayGame, game.verdict == .pending {
                return "GAME \(game.gameNumber) TONIGHT"
            }
            return "SERIES IN PROGRESS"
        }
    }
}
