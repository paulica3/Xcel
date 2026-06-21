import SwiftUI
import SwiftData
import UIKit

// Read-only recap of a single game: verdict, one-liner, checklist, coach's notes.
struct GameResultView: View {
    let game: Game
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var accent: Color { settings.accent.color }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: game.date)
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    topBar

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GAME \(game.gameNumber)")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(2.5)
                            .foregroundStyle(accent)
                        Text(dateLabel)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                    }

                    verdictBlock

                    injuredReserveBlock

                    if game.hasBoxScore {
                        BoxScoreView(effort: game.scoreEffort, discipline: game.scoreDiscipline,
                                     mood: game.scoreMood, productivity: game.scoreProductivity,
                                     accent: accent)
                    }

                    if !game.checklist.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(game.checklist) { item in
                                checklistRow(item)
                            }
                        }
                    }

                    if !game.extraNotes.isEmpty {
                        labeledCard("WENT BEYOND THE PLAN", game.extraNotes)
                    }

                    if !game.verdictFeedback.isEmpty {
                        labeledCard("COACH'S NOTES", game.verdictFeedback)
                    }
                }
                .padding(24)
            }
        }
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var verdictBlock: some View {
        switch game.verdict {
        case .pending:
            Text(game.isMissed(seriesCreatedAt: game.series?.createdAt ?? .distantPast)
                 ? "Not played." : "Not played yet.")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(white: 0.45))
        case .win, .loss:
            HStack(alignment: .center, spacing: 16) {
                Text(game.verdict == .win ? "W" : "L")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(game.verdict == .win ? accent : Color(white: 0.35))
                if !game.verdictOneLiner.isEmpty {
                    Text(game.verdictOneLiner)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder
    private var injuredReserveBlock: some View {
        if game.excused {
            HStack(spacing: 10) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(accent)
                Text("Injured Reserve - this loss doesn't count.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if game.verdict == .loss, game.series?.canUseInjuredReserve == true {
            VStack(alignment: .leading, spacing: 10) {
                Text("Real life got in the way? You've got one Injured Reserve this series - use it to wipe this L from the record.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.6))
                Button {
                    game.excused = true
                    try? modelContext.save()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cross.case.fill")
                        Text("Place on Injured Reserve")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.3), lineWidth: 1))
        }
    }

    private func checklistRow(_ item: ChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(item.isDone ? accent : Color(white: 0.4))
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .strikethrough(item.isDone, color: Color(white: 0.4))
                Spacer()
            }
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.leading, 28)
            }
            if let data = item.photoData, let ui = UIImage(data: data) {
                HStack(spacing: 10) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 4) {
                        Image(systemName: item.photoVerified ? "checkmark.seal.fill" : "photo")
                            .font(.system(size: 11))
                        Text(item.photoVerified ? "Photo verified" : "Photo attached")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(item.photoVerified ? accent : Color(white: 0.5))
                    Spacer()
                }
                .padding(.leading, 28)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func labeledCard(_ label: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(accent)
            Text(body)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.65))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// All 7 games of a past series; tap a played one to review it.
struct SeriesDetailView: View {
    let series: Series
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    private var accent: Color { settings.accent.color }

    private var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: series.weekStart)!
        return "\(f.string(from: series.weekStart)) – \(f.string(from: end))"
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(white: 0.5))
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(weekLabel)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                        Text("\(series.wins)–\(series.losses)  ·  \(resultLabel)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(series.seriesResult == .won ? accent : Color(white: 0.45))
                    }

                    SeriesRecapCard(series: series, accent: accent)

                    VStack(spacing: 10) {
                        ForEach(series.games.sorted { $0.gameNumber < $1.gameNumber }) { game in
                            gameRow(game)
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationBarHidden(true)
    }

    private var resultLabel: String {
        switch series.seriesResult {
        case .won: return "Series W"
        case .lost: return "Series L"
        case .inProgress: return "Unfinished"
        }
    }

    @ViewBuilder
    private func gameRow(_ game: Game) -> some View {
        let played = game.verdict != .pending
        let row = HStack(spacing: 14) {
            Text("Game \(game.gameNumber)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text(badge(for: game))
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(color(for: game))
            if played {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
            }
        }
        .padding(16)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))

        if played {
            NavigationLink { GameResultView(game: game) } label: { row }
        } else {
            row
        }
    }

    private func badge(for game: Game) -> String {
        if game.excused { return "IR" }
        switch game.verdict {
        case .win: return "W"
        case .loss: return "L"
        case .pending: return game.isMissed(seriesCreatedAt: series.createdAt) ? "-" : "·"
        }
    }

    private func color(for game: Game) -> Color {
        if game.excused { return accent.opacity(0.7) }
        switch game.verdict {
        case .win: return accent
        case .loss: return Color(white: 0.4)
        case .pending: return Color(white: 0.25)
        }
    }
}
