import SwiftUI
import SwiftData

// The solo season arc. Each won series is a playoff-series win; stack 4 of them
// (Round 1 -> Conference Semifinals -> Conference Finals -> The Finals) to raise
// a banner and earn a ring. Rings are championships; stacking rings is a dynasty.
//
// Computed read-only from existing series history - it never alters the weekly
// loop, so it's a pure framing layer on top of what the user already plays.
struct Postseason {
    var rings: Int          // championships won (every 4 series wins = 1 ring)
    var roundWins: Int      // series wins toward the current ring (0...3)
    var seriesWon: Int      // all-time won series (non-warm-up)
    var seriesLost: Int

    static let rounds = ["Round 1", "Conf. Semifinals", "Conf. Finals", "The Finals"]
    static let ringTarget = rounds.count   // 4

    // Index of the round the user is currently fighting through (0-based).
    var currentRoundIndex: Int { roundWins }
    var currentRoundName: String { Postseason.rounds[min(roundWins, Postseason.ringTarget - 1)] }
    var winsToRing: Int { Postseason.ringTarget - roundWins }

    var hasStarted: Bool { seriesWon + seriesLost > 0 }

    // Banners on the wall - the marquee identity once they've won it all.
    var dynastyTitle: String? {
        switch rings {
        case 0:  return nil
        case 1:  return "CHAMPION"
        case 2:  return "BACK-TO-BACK"
        case 3:  return "THREE-PEAT"
        default: return "DYNASTY"
        }
    }

    static func compute(from allSeries: [Series]) -> Postseason {
        let completed = allSeries
            .filter { !$0.isWarmup && $0.seriesResult != .inProgress }
            .sorted { $0.weekStart < $1.weekStart }

        var rings = 0, run = 0, won = 0, lost = 0
        for series in completed {
            if series.seriesResult == .won {
                won += 1
                run += 1
                if run == ringTarget { rings += 1; run = 0 }
            } else {
                lost += 1
                // A series loss doesn't reset the run - progress only accrues on
                // wins, keeping the climb motivating rather than punishing.
            }
        }
        return Postseason(rings: rings, roundWins: run, seriesWon: won, seriesLost: lost)
    }

    // Did winning `clinchedSeries` just complete a ring? Used for the ceremony.
    // True when the count of won series up to and including it is a multiple of 4.
    static func ringClinched(by clinchedSeries: Series, in allSeries: [Series]) -> Bool {
        guard clinchedSeries.seriesResult == .won else { return false }
        let wonUpToHere = allSeries
            .filter { !$0.isWarmup && $0.seriesResult == .won && $0.weekStart <= clinchedSeries.weekStart }
            .count
        return wonUpToHere > 0 && wonUpToHere % ringTarget == 0
    }
}

// "Road to the Finals" - the bracket ladder, current progress, and banners.
struct RoadToFinalsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    private var accent: Color { settings.accent.color }
    private var post: Postseason { Postseason.compute(from: allSeries) }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if let title = post.dynastyTitle {
                        banner(title)
                    }

                    intro

                    ladder

                    ringsRow
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("POSTSEASON")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Road to the Finals")
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

    private func banner(_ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 26))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .kerning(1)
                Text(post.rings == 1 ? "1 ring" : "\(post.rings) rings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.4), lineWidth: 1))
    }

    private var intro: some View {
        Text(post.hasStarted
             ? "Win four series to raise a banner. You're \(post.winsToRing) \(post.winsToRing == 1 ? "series" : "series wins") from a ring."
             : "Win your first series to start your playoff run. Four series wins raises a banner.")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color(white: 0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var ladder: some View {
        VStack(spacing: 12) {
            ForEach(Array(Postseason.rounds.enumerated()), id: \.offset) { idx, name in
                roundRow(index: idx, name: name)
            }
        }
    }

    private func roundRow(index: Int, name: String) -> some View {
        let cleared = index < post.roundWins
        let current = index == post.roundWins
        let icon = cleared ? "checkmark.circle.fill" : (current ? "circle.dotted" : "lock.fill")
        let tint: Color = cleared ? accent : (current ? accent.opacity(0.8) : Color(white: 0.28))
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(name)
                .font(.system(size: 16, weight: current ? .bold : .semibold))
                .foregroundStyle(cleared || current ? .white : Color(white: 0.4))
            Spacer()
            if index == Postseason.ringTarget - 1 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(tint)
            }
            if current {
                Text("YOU ARE HERE")
                    .font(.system(size: 9, weight: .black))
                    .kerning(1)
                    .foregroundStyle(accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: current ? 0.09 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(current ? accent.opacity(0.4) : .clear, lineWidth: 1))
    }

    @ViewBuilder
    private var ringsRow: some View {
        if post.hasStarted {
            HStack(spacing: 16) {
                miniStat("\(post.rings)", "RINGS")
                miniStat("\(post.seriesWon)", "SERIES W")
                miniStat("\(post.seriesLost)", "SERIES L")
            }
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
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
}
