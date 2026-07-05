import SwiftUI

struct OffSeasonView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var showRequest = false

    private var accent: Color { settings.accent.color }
    private var periods: [OffSeasonPeriod] { settings.offSeasonPeriods }
    private var active: OffSeasonPeriod? { OffSeasonService.isActive(periods, on: Date()) }
    private var remaining: Int { OffSeasonService.remainingThisYear(periods) }
    private var pastPeriods: [OffSeasonPeriod] {
        periods.filter { $0.id != active?.id }.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        quotaCard

                        if let active {
                            activeCard(active)
                        } else {
                            requestButton
                        }

                        if !pastPeriods.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PAST TRIPS")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(2)
                                    .foregroundStyle(Color(white: 0.35))
                                ForEach(pastPeriods) { period in
                                    pastRow(period)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showRequest) { OffSeasonRequestSheet() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OFF SEASON")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Time off")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private var quotaCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "airplane")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(OffSeasonService.approvedThisYear(periods)) of \(OffSeasonService.maxPerYear) used this year")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text("Resets every January")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.45))
            }
            Spacer()
        }
        .padding(14)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func activeCard(_ period: OffSeasonPeriod) -> some View {
        let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: period.endDate)).day ?? 0) + 1
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "airplane.circle.fill")
                    .foregroundStyle(accent)
                Text("On vacation - \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(period.description)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.55))
                .fixedSize(horizontal: false, vertical: true)
            Text("Every game in this window is paused - no auto-loss, no reminders, no effect on your record.")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private var requestButton: some View {
        if remaining > 0 {
            Button { showRequest = true } label: {
                Text("Request time off")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        } else {
            Text("You've used both trips this year. Back next January.")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pastRow(_ period: OffSeasonPeriod) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "airplane")
                .font(.system(size: 14))
                .foregroundStyle(accent.opacity(0.7))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(period.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(period.durationDays) day\(period.durationDays == 1 ? "" : "s") · \(period.startDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
            }
            Spacer()
        }
        .padding(12)
        .background(Color(white: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
