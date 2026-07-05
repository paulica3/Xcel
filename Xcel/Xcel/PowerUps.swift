import SwiftUI
import SwiftData

// Momentum: the in-app currency you bank by competing. Earned amounts are derived
// from history (so they can never be faked); spent amounts are persisted. The
// balance is earned minus spent. This keeps the economy honest with zero backend.
enum PowerUpStore {
    private static let spentKey = "momentumSpent"

    // Earn rates - winning is the only way to bank Momentum.
    static let perWin = 10
    static let perSeriesWin = 30
    static let perComeback = 20
    static let perRing = 50

    static func earned(from allSeries: [Series]) -> Int {
        let stats = CareerStats.compute(from: allSeries)
        let real = allSeries.filter { !$0.isWarmup }
        let seriesWon = real.filter { $0.seriesResult == .won }.count
        let comebacks = real.filter { $0.wasComeback }.count
        let rings = Postseason.compute(from: allSeries).rings
        return stats.wins * perWin
            + seriesWon * perSeriesWin
            + comebacks * perComeback
            + rings * perRing
    }

    static var spent: Int { UserDefaults.standard.integer(forKey: spentKey) }

    static func balance(_ allSeries: [Series]) -> Int { max(0, earned(from: allSeries) - spent) }

    static func canAfford(_ cost: Int, _ allSeries: [Series]) -> Bool { balance(allSeries) >= cost }

    static func charge(_ cost: Int) {
        UserDefaults.standard.set(spent + cost, forKey: spentKey)
    }
}

// A spendable comeback mechanic.
enum PowerUp: String, CaseIterable, Identifiable {
    case buzzerBeater, tradeDeadline
    var id: String { rawValue }

    var title: String {
        switch self {
        case .buzzerBeater:  return "Buzzer Beater"
        case .tradeDeadline: return "Trade Deadline"
        }
    }
    var icon: String {
        switch self {
        case .buzzerBeater:  return "clock.arrow.circlepath"
        case .tradeDeadline: return "arrow.left.arrow.right.circle.fill"
        }
    }
    var cost: Int {
        switch self {
        case .buzzerBeater:  return 75
        case .tradeDeadline: return 35
        }
    }
    var blurb: String {
        switch self {
        case .buzzerBeater:  return "Re-open a past L and take it back to the judge."
        case .tradeDeadline: return "Swap one task on today's or an upcoming plan for something you'll actually hit."
        }
    }
}

struct PowerUpsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Series.weekStart, order: .reverse) private var allSeries: [Series]

    @State private var expanded: PowerUp?
    @State private var pending: (power: PowerUp, game: Game)?
    @State private var tradingGame: Game?
    @State private var balanceTick = 0   // forces a refresh after a purchase

    private var accent: Color { settings.accent.color }
    private var balance: Int { _ = balanceTick; return PowerUpStore.balance(allSeries) }

    // Lost, non-excused games are Buzzer Beater's targets; still-pending
    // today/upcoming games (with a plan already on them) are Trade Deadline's.
    private func eligibleGames(for p: PowerUp) -> [Game] {
        switch p {
        case .buzzerBeater:
            return allSeries.filter { !$0.isWarmup }
                .flatMap { $0.games }
                .filter { $0.verdict == .loss && !$0.excused }
                .sorted { $0.date > $1.date }
        case .tradeDeadline:
            let todayStart = Calendar.current.startOfDay(for: Date())
            return allSeries.filter { !$0.isWarmup }
                .flatMap { $0.games }
                .filter {
                    $0.verdict == .pending && !$0.checklist.isEmpty
                        && Calendar.current.startOfDay(for: $0.date) >= todayStart
                }
                .sorted { $0.date < $1.date }
        }
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    balanceCard
                    earnHint
                    ForEach(PowerUp.allCases) { powerCard($0) }
                }
                .padding(24)
            }
        }
        .alert(item: pendingBox) { box in
            confirmAlert(box.value)
        }
        .sheet(isPresented: Binding(
            get: { tradingGame != nil },
            set: { if !$0 { tradingGame = nil } }
        )) {
            if let game = tradingGame {
                TradeDeadlineSheet(game: game, cost: PowerUp.tradeDeadline.cost, accent: accent) { index, newTitle in
                    applyTrade(index: index, newTitle: newTitle, to: game)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LOCKER ROOM")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Power-ups")
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

    private var balanceCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 24))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(balance)")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("MOMENTUM")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Color(white: 0.45))
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.3), lineWidth: 1))
    }

    private var earnHint: some View {
        Text("Bank Momentum by winning: +\(PowerUpStore.perWin) a game, +\(PowerUpStore.perSeriesWin) a series, +\(PowerUpStore.perComeback) a comeback, +\(PowerUpStore.perRing) a ring.")
            .font(.system(size: 12))
            .foregroundStyle(Color(white: 0.4))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func powerCard(_ p: PowerUp) -> some View {
        let affordable = balance >= p.cost
        let isOpen = expanded == p
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded = isOpen ? nil : p }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: p.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(affordable ? accent : Color(white: 0.35))
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(p.blurb)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.45))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(spacing: 2) {
                        Text("\(p.cost)")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(affordable ? accent : Color(white: 0.35))
                            .monospacedDigit()
                        Text("MP")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(white: 0.4))
                    }
                }
                .padding(16)
            }

            if isOpen {
                Divider().overlay(Color(white: 0.15))
                let games = eligibleGames(for: p)
                if !affordable {
                    cardNote("Not enough Momentum yet - win to bank more.")
                } else if games.isEmpty {
                    cardNote(p == .buzzerBeater
                        ? "No eligible games. This works on a past L."
                        : "No eligible days. This works on today's or an upcoming plan.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(games) { game in
                            if p == .buzzerBeater {
                                gamePickRow(p, game)
                            } else {
                                tradeGamePickRow(game)
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isOpen ? accent.opacity(0.3) : .clear, lineWidth: 1))
    }

    private func cardNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color(white: 0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
    }

    private func gamePickRow(_ p: PowerUp, _ game: Game) -> some View {
        Button { pending = (p, game) } label: {
            HStack(spacing: 12) {
                Text("L")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color(white: 0.5))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Game \(game.gameNumber) · \(dayLabel(game.date))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if !game.verdictOneLiner.isEmpty {
                        Text(game.verdictOneLiner)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.45))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
            }
            .padding(12)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func tradeGamePickRow(_ game: Game) -> some View {
        Button { tradingGame = game } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Game \(game.gameNumber) · \(dayLabel(game.date))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(game.checklist.count) task\(game.checklist.count == 1 ? "" : "s") planned")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
            }
            .padding(12)
            .background(Color(white: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    // MARK: Confirmation

    // Lightweight Identifiable wrapper so .alert(item:) can carry the choice.
    private struct PendingBox: Identifiable { let id = UUID(); let value: (power: PowerUp, game: Game) }
    private var pendingBox: Binding<PendingBox?> {
        Binding(
            get: { pending.map { PendingBox(value: $0) } },
            set: { if $0 == nil { pending = nil } }
        )
    }

    private func confirmAlert(_ choice: (power: PowerUp, game: Game)) -> Alert {
        Alert(
            title: Text("Use \(choice.power.title)?"),
            message: Text("Spend \(choice.power.cost) Momentum on Game \(choice.game.gameNumber). This game re-opens for a new entry."),
            primaryButton: .default(Text("Use it")) { apply(choice.power, to: choice.game) },
            secondaryButton: .cancel()
        )
    }

    // Only ever reached via gamePickRow, which is wired up for Buzzer Beater
    // alone - Trade Deadline has its own flow through TradeDeadlineSheet/applyTrade.
    private func apply(_ p: PowerUp, to game: Game) {
        guard balance >= p.cost else { return }
        switch p {
        case .tradeDeadline:
            return
        case .buzzerBeater:
            game.verdict = .pending
            game.verdictOneLiner = ""
            game.verdictFeedback = ""
            game.scoreEffort = 0; game.scoreDiscipline = 0
            game.scoreMood = 0; game.scoreProductivity = 0
            // Clear evening proof so the day is replayed cleanly; the morning plan stays.
            for i in game.checklist.indices {
                game.checklist[i].isDone = false
                game.checklist[i].note = ""
            }
            game.extraNotes = ""
        }
        PowerUpStore.charge(p.cost)
        try? modelContext.save()
        pending = nil
        expanded = nil
        balanceTick += 1
    }

    // Swaps one task's title on an unjudged day and resets its done/note/photo
    // state (it's a different task now) - never touches a judged verdict.
    private func applyTrade(index: Int, newTitle: String, to game: Game) {
        guard balance >= PowerUp.tradeDeadline.cost, game.checklist.indices.contains(index) else { return }
        game.checklist[index].title = newTitle
        game.checklist[index].isDone = false
        game.checklist[index].note = ""
        game.checklist[index].isGameBall = false
        game.checklist[index].photoData = nil
        game.checklist[index].photoVerified = false
        game.checklist[index].photoNote = ""
        PowerUpStore.charge(PowerUp.tradeDeadline.cost)
        try? modelContext.save()
        tradingGame = nil
        expanded = nil
        balanceTick += 1
    }
}

// Pick a task from an eligible day's plan, then write in its replacement.
private struct TradeDeadlineSheet: View {
    let game: Game
    let cost: Int
    let accent: Color
    let onApply: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int?
    @State private var newTitle = ""

    private var ready: Bool {
        selectedIndex != nil && !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pick the task you want to trade, then write in something you'll actually hit.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 8) {
                            ForEach(Array(game.checklist.enumerated()), id: \.offset) { index, item in
                                taskRow(index, item)
                            }
                        }

                        if selectedIndex != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NEW TASK")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(2)
                                    .foregroundStyle(accent)
                                TextField("What will you actually do instead?", text: $newTitle, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .lineLimit(2...5)
                                    .padding(12)
                                    .background(Color(white: 0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(24)
                }

                Button {
                    if let index = selectedIndex {
                        onApply(index, newTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    dismiss()
                } label: {
                    Text("Trade it - \(cost) MP")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ready ? .black : Color(white: 0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(ready ? accent : Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!ready)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .dismissKeyboardOnScroll()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRADE DEADLINE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Swap a task")
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
    }

    private func taskRow(_ index: Int, _ item: ChecklistItem) -> some View {
        let selected = selectedIndex == index
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedIndex = index }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? accent : Color(white: 0.3))
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .strikethrough(selected)
                Spacer()
            }
            .padding(12)
            .background(Color(white: 0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? accent.opacity(0.4) : .clear, lineWidth: 1))
        }
    }
}
