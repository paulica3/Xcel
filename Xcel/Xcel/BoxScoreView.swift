import SwiftUI

// The day's box score - four 0-10 ratings shown as labeled bars.
struct BoxScoreView: View {
    let effort: Int
    let discipline: Int
    let mood: Int
    let productivity: Int
    let accent: Color

    private var rows: [(String, Int)] {
        [("EFFORT", effort), ("DISCIPLINE", discipline), ("MOOD", mood), ("PRODUCTIVITY", productivity)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BOX SCORE")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(accent)

            ForEach(rows, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1)
                            .foregroundStyle(Color(white: 0.6))
                        Spacer()
                        Text("\(value)")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        + Text("/10")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.4))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(white: 0.14)).frame(height: 6)
                            Capsule().fill(barColor(value))
                                .frame(width: max(6, geo.size.width * CGFloat(value) / 10), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Low scores lean red, high scores lean accent - quick visual read.
    private func barColor(_ v: Int) -> Color {
        if v <= 3 { return Color.eliminationRed }
        if v <= 6 { return Color(white: 0.55) }
        return accent
    }
}

// Season averages - the same four ratings carried as floats (one decimal),
// with a headline overall average. Shown in Season insights.
struct AverageBoxScoreView: View {
    let averages: BoxScoreAverages
    let accent: Color

    private var rows: [(String, Double)] {
        [("EFFORT", averages.effort), ("DISCIPLINE", averages.discipline),
         ("MOOD", averages.mood), ("PRODUCTIVITY", averages.productivity)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("AVG BOX SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(accent)
                Spacer()
                Text(fmt(averages.overall))
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(barColor(averages.overall))
                    .monospacedDigit()
                + Text(" / 10")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(white: 0.4))
            }

            ForEach(rows, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(1)
                            .foregroundStyle(Color(white: 0.6))
                        Spacer()
                        Text(fmt(value))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(white: 0.14)).frame(height: 6)
                            Capsule().fill(barColor(value))
                                .frame(width: max(6, geo.size.width * CGFloat(value) / 10), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }

            Text("Averaged across \(averages.count) scored game\(averages.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.35))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func fmt(_ v: Double) -> String { String(format: "%.1f", v) }

    private func barColor(_ v: Double) -> Color {
        if v <= 3 { return Color.eliminationRed }
        if v <= 6 { return Color(white: 0.55) }
        return accent
    }
}

// A minimal line chart (0-maxValue) drawn across the available width.
struct Sparkline: Shape {
    let values: [Double]
    var maxValue: Double = 10

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count >= 2, maxValue > 0 else { return p }
        let stepX = rect.width / CGFloat(values.count - 1)
        for (i, v) in values.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            let y = rect.maxY - CGFloat(min(v, maxValue) / maxValue) * rect.height
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

// Per-dimension box-score trend - one sparkline per rating over recent games.
struct BoxTrendView: View {
    let trend: BoxScoreTrend
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FORM · LAST \(trend.effort.count) SCORED GAMES")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(accent)

            ForEach(trend.series, id: \.0) { label, vals in
                HStack(spacing: 12) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(white: 0.55))
                        .frame(width: 88, alignment: .leading)
                    Sparkline(values: vals)
                        .stroke(lineColor(vals),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(height: 26)
                        .frame(maxWidth: .infinity)
                    Text(String(format: "%.0f", vals.last ?? 0))
                        .font(.system(size: 13, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 20, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Rising line reads accent, falling reads red, steady reads grey.
    private func lineColor(_ vals: [Double]) -> Color {
        guard let last = vals.last, vals.count >= 2 else { return accent }
        let earlier = vals.dropLast()
        let baseline = earlier.reduce(0, +) / Double(earlier.count)
        if last > baseline + 0.5 { return accent }
        if last < baseline - 0.5 { return Color.eliminationRed }
        return Color(white: 0.5)
    }
}
