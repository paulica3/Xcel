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
    case timeout, buzzerBeater
    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeout:      return "Timeout"
        case .buzzerBeater: return "Buzzer Beater"
        }
    }
    var icon: String {
        switch self {
        case .timeout:      return "pause.circle.fill"
        case .buzzerBeater: return "clock.arrow.circlepath"
        }
    }
    var cost: Int {
        switch self {
        case .timeout:      return 40
        case .buzzerBeater: return 75
        }
    }
    var blurb: String {
        switch self {
        case .timeout:      return "Excuse one past L so it doesn't count - life happens."
        case .buzzerBeater: return "Re-open a past L and take it back to the judge."
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
    @State private var balanceTick = 0   // forces a refresh after a purchase

    private var accent: Color { settings.accent.color }
    private var balance: Int { _ = balanceTick; return PowerUpStore.balance(allSeries) }

    // Lost, non-excused games are the targets for both power-ups.
    private var eligibleGames: [Game] {
        allSeries.filter { !$0.isWarmup }
            .flatMap { $0.games }
            .filter { $0.verdict == .loss && !$0.excused }
            .sorted { $0.date > $1.date }
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
                if !affordable {
                    cardNote("Not enough Momentum yet - win to bank more.")
                } else if eligibleGames.isEmpty {
                    cardNote("No eligible games. This works on a past L.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(eligibleGames) { game in
                            gamePickRow(p, game)
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
            message: Text("Spend \(choice.power.cost) Momentum on Game \(choice.game.gameNumber). \(choice.power == .timeout ? "This L will be excused." : "This game re-opens for a new entry.")"),
            primaryButton: .default(Text("Use it")) { apply(choice.power, to: choice.game) },
            secondaryButton: .cancel()
        )
    }

    private func apply(_ p: PowerUp, to game: Game) {
        guard balance >= p.cost else { return }
        switch p {
        case .timeout:
            game.excused = true
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
}
