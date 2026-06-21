import SwiftUI

// The day's box score — four 0-10 ratings shown as labeled bars.
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

    // Low scores lean red, high scores lean accent — quick visual read.
    private func barColor(_ v: Int) -> Color {
        if v <= 3 { return Color.eliminationRed }
        if v <= 6 { return Color(white: 0.55) }
        return accent
    }
}
