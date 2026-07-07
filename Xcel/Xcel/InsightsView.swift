import SwiftUI
import SwiftData

// The monthly "vs life" verdict plus where you're winning and struggling.
struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    @State private var insights: MonthlyInsights?
    @State private var loading = true

    private var accent: Color { settings.accent.color }
    private var topSongs: [SongStat] { MusicStats.topSongs(from: allSeries) }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if loading {
                        loadingView
                    } else if let insights, insights.hasEnoughData {
                        content(insights)
                    } else {
                        notEnoughData
                    }
                }
                .padding(24)
            }
        }
        .task {
            loading = true
            insights = await InsightsService.compute(from: allSeries)
            loading = false
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THE TAPE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Season insights")
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

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().tint(accent).scaleEffect(1.4)
            Text("Breaking down your tape…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var notEnoughData: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.25))
            Text("Not enough tape yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text("Play a few more games and your patterns, struggles, and monthly verdict will show up here.")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 70)
    }

    @ViewBuilder
    private func content(_ i: MonthlyInsights) -> some View {
        verdictCard(i)

        ShareCardButton(content: ShareCardContent(
            tag: "LAST 30 DAYS",
            big: i.wonAgainstLife ? "W" : "L",
            bigIsWin: i.wonAgainstLife,
            headline: i.headline,
            sub: "\(i.wins)–\(i.losses) · \(i.gamesPlayed) games"
        ), accent: accent)

        if let c = i.comparison, c.hasPrev {
            comparisonCard(c)
        }

        if i.boxAverages.hasData {
            AverageBoxScoreView(averages: i.boxAverages, accent: accent)
        }

        if i.boxTrend.hasData {
            BoxTrendView(trend: i.boxTrend, accent: accent)
        }

        if !topSongs.isEmpty {
            sectionTitle("MOST PLAYED", "music.note.list")
            VStack(spacing: 10) {
                ForEach(topSongs) { topSongRow($0) }
            }
        }

        if !i.summary.isEmpty {
            Text(i.summary)
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.7))
                .fixedSize(horizontal: false, vertical: true)
        }

        if !i.struggles.isEmpty {
            sectionTitle("WHERE YOU'RE STRUGGLING", "exclamationmark.triangle.fill")
            VStack(spacing: 10) {
                ForEach(i.struggles) { struggleRow($0) }
            }
        }

        if !i.bright.isEmpty {
            sectionTitle("WHAT'S WORKING", "checkmark.seal.fill")
            VStack(spacing: 10) {
                ForEach(i.bright) { brightRow($0) }
            }
        }

        if !i.successPatterns.isEmpty {
            bulletCard("SUCCESS PATTERNS", i.successPatterns, icon: "bolt.fill")
        }
        if !i.blockers.isEmpty {
            bulletCard("WHAT'S HOLDING YOU BACK", i.blockers, icon: "hand.raised.fill")
        }
        if !i.suggestions.isEmpty {
            bulletCard("COACH'S PLAYBOOK", i.suggestions, icon: "list.clipboard.fill")
        }

        if JudgeService.practiceJudgeNote != nil {
            Text("Tip: turn on Apple Intelligence for a sharper, personalized breakdown.")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.35))
                .padding(.top, 4)
        }
    }

    private func verdictCard(_ i: MonthlyInsights) -> some View {
        let won = i.wonAgainstLife
        let color = won ? accent : Color.eliminationRed
        return VStack(spacing: 12) {
            Text("\(i.periodLabel.uppercased()) · VERDICT")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color(white: 0.4))

            Text(won ? "YOU vs LIFE" : "LIFE vs YOU")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(white: 0.5))

            Text(won ? "W" : "L")
                .font(.system(size: 88, weight: .black))
                .foregroundStyle(color)

            Text(i.headline)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("\(i.wins)–\(i.losses) · \(i.gamesPlayed) games")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(white: 0.4))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.3), lineWidth: 1))
    }

    private func comparisonCard(_ c: SeasonComparison) -> some View {
        let winPts = Int((c.winRateDelta * 100).rounded())
        let boxD = c.boxDelta
        return VStack(alignment: .leading, spacing: 12) {
            Text("YOU vs PRIOR 30 DAYS")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(accent)
            HStack(spacing: 12) {
                compareTile(
                    label: "WIN RATE",
                    value: "\(Int((c.currentWinRate * 100).rounded()))%",
                    deltaText: "\(winPts >= 0 ? "+" : "−")\(abs(winPts)) pts",
                    up: winPts >= 0, flat: winPts == 0
                )
                compareTile(
                    label: "AVG BOX",
                    value: String(format: "%.1f", c.currentBox),
                    deltaText: "\(boxD >= 0 ? "+" : "−")\(String(format: "%.1f", abs(boxD)))",
                    up: boxD >= 0, flat: abs(boxD) < 0.05
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func compareTile(label: String, value: String, deltaText: String, up: Bool, flat: Bool) -> some View {
        let color = flat ? Color(white: 0.5) : (up ? accent : Color.eliminationRed)
        return VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .kerning(1)
                .foregroundStyle(Color(white: 0.4))
            Text(value)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
            HStack(spacing: 3) {
                Image(systemName: flat ? "minus" : (up ? "arrow.up.right" : "arrow.down.right"))
                    .font(.system(size: 10, weight: .bold))
                Text(flat ? "flat" : deltaText)
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(white: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sectionTitle(_ text: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color(white: 0.5))
        }
        .padding(.top, 4)
    }

    private func struggleRow(_ s: TaskStruggle) -> some View {
        statRow(s, barColor: Color.eliminationRed)
    }

    private func brightRow(_ s: TaskStruggle) -> some View {
        statRow(s, barColor: accent)
    }

    private func statRow(_ s: TaskStruggle, barColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(s.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("\(s.done)/\(s.total)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(barColor)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.14)).frame(height: 6)
                    Capsule().fill(barColor)
                        .frame(width: max(6, geo.size.width * s.rate), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func topSongRow(_ song: SongStat) -> some View {
        HStack(spacing: 12) {
            SongArtworkThumbnail(appleMusicID: song.id, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(song.playCount)×")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                if song.hasReliableWinRate {
                    Text("\(Int((song.winRate * 100).rounded()))% W")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                }
            }
        }
        .padding(12)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func bulletCard(_ title: String, _ items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title, icon)
            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(accent).frame(width: 5, height: 5).padding(.top, 7)
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
