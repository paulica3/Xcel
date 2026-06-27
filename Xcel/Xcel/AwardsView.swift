import SwiftUI
import SwiftData

// Awards Night: the monthly hardware case. Each calendar month with enough play
// shows its record, box score, and any awards it earned (MVP / MIP / DPOY / 6MOY).
struct AwardsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    private var accent: Color { settings.accent.color }
    private var months: [MonthlyAwards] { AwardsService.compute(from: allSeries) }
    private var totalHardware: Int { months.reduce(0) { $0 + $1.awards.count } }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if months.allSatisfy({ !$0.hasHardware }) && months.allSatisfy({ $0.games < AwardsService.minGames }) {
                        emptyState
                    } else {
                        ForEach(months) { month in
                            monthCard(month)
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AWARDS NIGHT")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                }
            }
            Text(totalHardware > 0
                 ? "\(totalHardware) piece\(totalHardware == 1 ? "" : "s") of hardware in the case."
                 : "Win your months. The hardware follows.")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.5))
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "trophy")
                .font(.system(size: 44))
                .foregroundStyle(Color(white: 0.25))
            Text("No hardware yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text("Play a full month - at least \(AwardsService.minGames) judged days - and the league starts handing out awards. MVP, Most Improved, Defensive Player, Sixth Man. All earned from your wins and box score.")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 12)
    }

    private func monthCard(_ m: MonthlyAwards) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.monthLabel)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(m.wins)–\(m.losses)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                Text("· \(String(format: "%.1f", m.avgBox)) box")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.45))
            }

            if m.hasHardware {
                ForEach(m.awards) { award in
                    awardRow(award, m)
                }
            } else if m.games >= AwardsService.minGames {
                Text("No hardware this month. Stack wins and raise the box score to put yourself in the running.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(m.games) of \(AwardsService.minGames) games played - not enough yet to qualify for awards.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(m.hasHardware ? accent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }

    private func awardRow(_ award: Award, _ m: MonthlyAwards) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accent)
                    .frame(width: 46, height: 46)
                Image(systemName: award.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(award.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(award.abbrev)
                        .font(.system(size: 9, weight: .black))
                        .kerning(1)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent)
                        .clipShape(Capsule())
                }
                Text(award.blurb(for: m))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
