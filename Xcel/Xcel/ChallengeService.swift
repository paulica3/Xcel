import SwiftUI
import SwiftData
import FoundationModels

// The judge's ruling on a Challenge Call. Overturning a loss flips it into a win
// (the call goes the player's way); upholding leaves the L on the board. Either
// way the challenge is spent - and an overturn puts the player on the hook for the
// plan they promised, which next series' follow-through check verifies.
struct ChallengeRuling {
    let overturned: Bool
    let ruling: String   // one-to-two sentence broadcast-style verdict
}

// Reviews a contested loss. The bar is deliberately high: a challenge is granted
// only for a legitimate, specific reason the day shouldn't have counted, AND when
// the user owns their mistakes with a concrete plan to fix them. Vague excuses are
// denied - that's what stops the feature from becoming a weekly free pass.
struct ChallengeService {
    func review(game: Game, statement: String, wins: Int, losses: Int) async throws -> ChallengeRuling {
        let summary = Self.taskSummary(game)
        do {
            return try await AIReferee().review(summary: summary, original: game.verdictOneLiner,
                                                statement: statement, gameNumber: game.gameNumber,
                                                wins: wins, losses: losses)
        } catch {
            return MockReferee.review(statement: statement)
        }
    }

    static func taskSummary(_ game: Game) -> String {
        var s = ""
        for item in game.checklist {
            let mark = item.isDone ? "[done]" : "[not done]"
            s += "\(mark) \(item.title) - \(item.note)\n"
        }
        if !game.extraNotes.isEmpty { s += "Extra: \(game.extraNotes)\n" }
        return s
    }
}

// MARK: - On-device AI referee

private struct AIReferee {
    private let instructions = """
    You are the Judge reviewing a CHALLENGE CALL - like an NBA coach's challenge. The player is
    contesting a day you previously ruled a LOSS. Read their case and decide: OVERTURN (the loss is
    wiped) or UPHOLD (the loss stands).

    OVERTURN flips the loss into a WIN in the player's favour. So the bar is high. OVERTURN ONLY IF
    BOTH are true:
    1. There is a legitimate, specific reason this day shouldn't have counted against them - genuine
       hardship (illness, emergency, injury, family crisis), or real work/context the original review
       clearly missed. NOT "I was tired", "I didn't feel like it", "I was busy", or vague complaints.
    2. They OWN it - they acknowledge what went wrong and give a concrete, specific plan to do better.
       They WILL be held to this plan next week, so it must be real and actionable.

    If either is missing - no real reason, or no honest plan - UPHOLD the loss. Be strict and fair:
    a frivolous or entitled challenge is denied. Reward accountability, not excuses.

    Respond ONLY with valid JSON, nothing else:
    {"overturned":true,"ruling":"one or two punchy broadcast-style sentences explaining the call"}
    """

    func review(summary: String, original: String, statement: String, gameNumber: Int, wins: Int, losses: Int) async throws -> ChallengeRuling {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        var prompt = "Series: \(wins)-\(losses). Contesting Game \(gameNumber).\n"
        if !original.isEmpty { prompt += "Original ruling: \(original)\n" }
        prompt += "\nThat day's plan and proof:\n\(summary)\n"
        prompt += "\nThe player's challenge:\n\(statement)\n"

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return try parse(response.content)
    }

    private func parse(_ raw: String) throws -> ChallengeRuling {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JudgeError.parseFailure(raw)
        }
        return ChallengeRuling(
            overturned: (json["overturned"] as? Bool) ?? false,
            ruling: (json["ruling"] as? String) ?? ""
        )
    }
}

// MARK: - Heuristic fallback (no AI on device)

private enum MockReferee {
    private static let hardship = ["hospital", "sick", "ill", "illness", "emergency", "injured",
                                   "injury", "family", "funeral", "death", "crisis", "accident"]
    private static let planWords = ["will ", "i'll", "next time", "plan", "going to", "im going",
                                    "i am going", "improve", "tomorrow", "from now", "commit",
                                    "make sure", "schedule", "instead of"]

    static func review(statement: String) -> ChallengeRuling {
        let text = statement.lowercased()
        let wordCount = statement.split(whereSeparator: { $0.isWhitespace }).count
        let credible = Credibility.isCredible(statement) && wordCount >= 12
        let hasReason = hardship.contains { text.contains($0) } || wordCount >= 25
        let hasPlan = planWords.contains { text.contains($0) }

        if credible && hasReason && hasPlan {
            return ChallengeRuling(
                overturned: true,
                ruling: "Challenge granted. You made a real case and owned the fix - the call's overturned and it goes in the win column. Now you're on the hook: live out that plan or you lose the challenge next series."
            )
        }
        if !hasPlan {
            return ChallengeRuling(
                overturned: false,
                ruling: "Challenge denied. You explained what happened but didn't show how you'll fix it. The L stands - turn the plan into the next win."
            )
        }
        return ChallengeRuling(
            overturned: false,
            ruling: "Challenge denied. Not enough here to overturn the call. The L stands - make the next one undeniable."
        )
    }
}

// MARK: - The challenge sheet

struct ChallengeSheet: View {
    let game: Game
    let onComplete: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var statement = ""
    @State private var reviewing = false

    private var accent: Color { settings.accent.color }
    private var ready: Bool {
        statement.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0.isWhitespace }).count >= 8
            && !reviewing
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("You get ONE challenge a series - win or lose, it's spent. Make it count.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("YOUR CASE")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(2)
                                .foregroundStyle(accent)
                            Text("Why shouldn't this have counted? Own what went wrong, and show exactly how you'll fix it. Excuses get denied.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.45))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(alignment: .bottom, spacing: 8) {
                                TextField("Make your case to the judge…", text: $statement, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .lineLimit(4...10)
                                    .padding(12)
                                    .background(Color(white: 0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                MicButton(text: $statement, accent: accent)
                            }
                        }
                    }
                    .padding(24)
                }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        if reviewing { ProgressView().tint(.black).scaleEffect(0.9) }
                        Text(reviewing ? "The judge is reviewing…" : "Submit challenge")
                    }
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
                .animation(.easeInOut(duration: 0.15), value: ready)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CHALLENGE CALL")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Contest the L")
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

    private func submit() {
        reviewing = true
        let wins = game.series?.wins ?? 0
        let losses = game.series?.losses ?? 0
        let text = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ruling = (try? await ChallengeService().review(game: game, statement: text, wins: wins, losses: losses))
                ?? ChallengeRuling(overturned: false, ruling: "The challenge couldn't be reviewed. The L stands.")
            await MainActor.run {
                game.challenged = true
                game.challengeStatement = text
                game.challengeOverturned = ruling.overturned
                game.challengeRuling = ruling.ruling
                if ruling.overturned {
                    // The call is overturned in the player's favour - the L flips
                    // to a W, just like an NBA challenge. They're now on the hook
                    // for the plan they promised; next series checks the follow-up.
                    game.verdict = .win
                    game.excused = false
                    // Replace the loss one-liner so the W header reads coherently;
                    // the full ruling still shows in the challenge card.
                    game.verdictOneLiner = "Challenge won - the call's overturned."
                    FX.comeback()
                }
                try? modelContext.save()
                reviewing = false
                onComplete()
                dismiss()
            }
        }
    }
}
