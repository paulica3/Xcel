import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    var pastSeries: [Series] {
        let thisMonday = Series.mondayOf(Date())
        return allSeries.filter { !Calendar.current.isDate($0.weekStart, inSameDayAs: thisMonday) }
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("CAREER")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 28)

                if pastSeries.isEmpty {
                    Spacer()
                    Text("No past series yet.\nComplete this week first.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.3))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(pastSeries) { series in
                                SeriesRowView(series: series)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
    }
}

private struct SeriesRowView: View {
    let series: Series
    @Environment(AppSettings.self) private var settings

    var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: series.weekStart)!
        return "\(f.string(from: series.weekStart)) – \(f.string(from: end))"
    }

    var resultColor: Color {
        switch series.seriesResult {
        case .won: return settings.accent.color
        case .lost: return Color(white: 0.38)
        case .inProgress: return .white
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(series.seriesResult == .won ? "Series W" : series.seriesResult == .lost ? "Series L" : "In progress")
                    .font(.system(size: 13))
                    .foregroundStyle(resultColor)
            }
            Spacer()
            Text("\(series.wins)–\(series.losses)")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(resultColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
