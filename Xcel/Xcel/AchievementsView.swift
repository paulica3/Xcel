import SwiftUI

// Everything derived from game history: stats, season arc, and hardware.
struct AchievementsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showInsights = false
    @State private var showPostseason = false
    @State private var showAwards = false
    @State private var showPowerUps = false
    @State private var showTrophies = false

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                AccountCategoryHeader(kicker: "ACHIEVEMENTS", title: "Stats & hardware", accent: accent, dismiss: { dismiss() })
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        accountNavRow(icon: "chart.line.uptrend.xyaxis", title: "Season insights",
                                      subtitle: "Monthly verdict", accent: accent) { showInsights = true }
                        accountNavRow(icon: "trophy.circle.fill", title: "Road to the Finals",
                                      subtitle: "Your playoff run · rings & banners", accent: accent) { showPostseason = true }
                        accountNavRow(icon: "rosette", title: "Awards night",
                                      subtitle: "Monthly silverware", accent: accent) { showAwards = true }
                        accountNavRow(icon: "bolt.circle.fill", title: "Locker room",
                                      subtitle: "Spend Momentum on power-ups", accent: accent) { showPowerUps = true }
                        accountNavRow(icon: "trophy.fill", title: "Trophy case",
                                      subtitle: "All-time badges & achievements", accent: accent) { showTrophies = true }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showInsights) { InsightsView() }
        .sheet(isPresented: $showPostseason) { RoadToFinalsView() }
        .sheet(isPresented: $showAwards) { AwardsView() }
        .sheet(isPresented: $showPowerUps) { PowerUpsView() }
        .sheet(isPresented: $showTrophies) { TrophyCaseView() }
    }
}
