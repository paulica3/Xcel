import Foundation
import FoundationModels

struct JudgeResult {
    let verdict: GameVerdict
    let oneLiner: String
    let feedback: String
}

// How hard the judge leans, based on the current series state.
enum JudgeStance {
    case homeCourt    // down 2+ — ease up, keep them in the fight
    case elimination  // 3 losses — win or the series is over
    case lockedIn     // cruising (3-0) — raise the bar
    case standard

    static func forSeries(wins: Int, losses: Int) -> JudgeStance {
        if losses == 3 && wins < 4 { return .elimination }
        if losses - wins >= 2 { return .homeCourt }
        if wins >= 3 && losses == 0 { return .lockedIn }
        return .standard
    }

    var directive: String {
        switch self {
        case .homeCourt:
            return "HOME COURT ADVANTAGE: They're down in the series and need a lifeline. Give honest effort the benefit of the doubt. A genuine attempt earns a W. Only clear non-effort or pure excuse-making earns an L."
        case .elimination:
            return "ELIMINATION GAME: They're down 1-3 (or worse) — one more L ends the series. Be fair but make the stakes vivid. Reward real fight."
        case .lockedIn:
            return "RAISE THE BAR: They're dominating. Judge strictly — vague wins don't cut it anymore. Demand specificity, real effort, and follow-through."
        case .standard:
            return "Judge tough-but-fair at the normal bar."
        }
    }
}

// Prefers the real on-device model (works on device, and on Apple-Silicon
// simulators when Apple Intelligence is enabled in macOS). Falls back to a
// credibility-aware heuristic judge only when the model is unavailable.
struct JudgeService {
    func judge(checklist: [ChecklistItem], extraNotes: String, wins: Int, losses: Int, gameNumber: Int) async throws -> JudgeResult {
        let stance = JudgeStance.forSeries(wins: wins, losses: losses)
        do {
            return try await AppleIntelligenceJudge().judge(checklist: checklist, extraNotes: extraNotes, wins: wins, losses: losses, gameNumber: gameNumber, stance: stance)
        } catch {
            return try await MockJudge().judge(checklist: checklist, extraNotes: extraNotes, wins: wins, losses: losses, gameNumber: gameNumber, stance: stance)
        }
    }
}

// MARK: - Apple Intelligence (device only)

private struct AppleIntelligenceJudge {
    private let basePrompt = """
    You are the Judge — a tough-but-fair NBA-style commentator reviewing someone's daily game plan.

    They set tasks this morning. Tonight they marked each done or not done, with proof (if done) or a reason (if not).

    BE CRITICAL AND SKEPTICAL. This is the most important rule:
    - Proof must be specific and believable. Gibberish, random characters ("asdasd"), single vague words ("done", "yes", "did it"), or proof that doesn't actually describe HOW the task was accomplished is NOT valid — treat that task as effectively NOT done and call it out.
    - A checkbox ticked with no real proof earns no credit. Do not reward a checkmark on its own.
    - If most of the proof is empty, vague, or nonsense, the day is a LOSS regardless of how many boxes were checked.

    Decide the day: W (win) or L (loss), then write:
    - oneLiner: one punchy broadcast-style sentence delivering the verdict, framed within the series.
    - feedback: 2-4 sentences of coach's notes — name specific tasks, call out weak/nonsense proof directly, say what could've been better and what to improve tomorrow.

    Other rules:
    - Reward honesty, specificity, and real effort. Penalize vague proof and flimsy excuses.
    - Judge fairly on reasons for incomplete tasks. GENUINE hardship (illness, hospital, family emergency, injury) is NOT the user's fault — do not be harsh; a day derailed by real hardship can still be a W if they handled it with integrity. Flimsy excuses ("didn't feel like it", "too tired") earn an L.
    - Never frame a loss as a standalone life judgment.

    Respond ONLY with valid JSON, nothing else:
    {"verdict":"win","oneLiner":"...","feedback":"..."}
    """

    func judge(checklist: [ChecklistItem], extraNotes: String, wins: Int, losses: Int, gameNumber: Int, stance: JudgeStance) async throws -> JudgeResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw JudgeError.modelUnavailable
        }

        let systemPrompt = basePrompt + "\n\n" + stance.directive

        var prompt = "Series going into Game \(gameNumber): \(wins)–\(losses)\n\nTasks:\n"
        for item in checklist {
            let mark = item.isDone ? "[DONE]" : "[NOT DONE]"
            let label = item.isDone ? "proof" : "reason"
            prompt += "\(mark) \(item.title) — \(label): \(item.note)\n"
        }
        if !extraNotes.isEmpty {
            prompt += "\nExtra (beyond the plan — reward genuine initiative): \(extraNotes)\n"
        }

        let session = LanguageModelSession(instructions: systemPrompt)
        let response = try await session.respond(to: prompt)
        return try parse(response.content)
    }

    private func parse(_ raw: String) throws -> JudgeResult {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let verdictStr = json["verdict"],
              let oneLiner = json["oneLiner"] else {
            throw JudgeError.parseFailure(raw)
        }
        let verdict: GameVerdict = verdictStr.lowercased() == "win" ? .win : .loss
        return JudgeResult(verdict: verdict, oneLiner: oneLiner, feedback: json["feedback"] ?? "")
    }
}

// MARK: - Mock (simulator)

private struct MockJudge {
    func judge(checklist: [ChecklistItem], extraNotes: String, wins: Int, losses: Int, gameNumber: Int, stance: JudgeStance) async throws -> JudgeResult {
        try await Task.sleep(for: .seconds(1.2))

        let total = max(checklist.count, 1)

        // Only count a task if it's checked AND the proof is actually credible.
        let credited = checklist.filter { $0.isDone && Credibility.isCredible($0.note) }.count
        let fakeProof = checklist.filter { $0.isDone && !Credibility.isCredible($0.note) }
        let hasExtra = Credibility.isCredible(extraNotes)
        let ratio = Double(credited) / Double(total) + (hasExtra ? 0.15 : 0)

        let hardshipWords = ["hospital", "sick", "ill", "emergency", "injured", "injury", "family", "funeral"]
        let hadHardship = checklist.contains { item in
            !item.isDone && Credibility.isCredible(item.note)
                && hardshipWords.contains { item.note.lowercased().contains($0) }
        }

        // Nonsense proof is an automatic red flag — the judge is not fooled.
        if !fakeProof.isEmpty && credited == 0 {
            let names = fakeProof.prefix(2).map { "“\($0.title)”" }.joined(separator: ", ")
            return JudgeResult(
                verdict: .loss,
                oneLiner: "Checked the boxes, but the proof was smoke. The judge isn't buying it — L.",
                feedback: "The proof on \(names) doesn't describe how you actually did anything. A checkmark with no real receipt counts for nothing. Tomorrow: write one concrete sentence of evidence per task — what you did, when, and how."
            )
        }

        let threshold: Double
        switch stance {
        case .homeCourt, .elimination: threshold = 0.34
        case .lockedIn:                threshold = 0.8
        case .standard:                threshold = 0.5
        }
        let verdict: GameVerdict = (ratio >= threshold || hadHardship) ? .win : .loss

        let oneLiner: String
        let feedback: String
        if verdict == .win {
            oneLiner = hadHardship
                ? "Life threw a curveball and you kept your integrity. The judge respects it — W."
                : "\(credited) of \(total) backed up with real proof. That's a W."
            var notes = "You showed up where it counted."
            if !fakeProof.isEmpty {
                notes += " But the proof on \(fakeProof.count) item\(fakeProof.count == 1 ? "" : "s") was thin — tighten it up so it can't be questioned."
            }
            notes += " Stack two clean days in a row to build real momentum."
            feedback = notes
        } else {
            oneLiner = "\(credited) of \(total) held up. Not enough — L."
            feedback = "The plan was there; the credible follow-through wasn't. Pick the one task that mattered most and protect it tomorrow — win the small battle first, with proof you'd stand behind."
        }
        return JudgeResult(verdict: verdict, oneLiner: oneLiner, feedback: feedback)
    }
}

// Heuristic gibberish / low-effort detector for the offline fallback judge.
enum Credibility {
    static func isCredible(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.count >= 8 else { return false }

        let words = text.split(whereSeparator: { !$0.isLetter }).filter { $0.count >= 2 }
        guard words.count >= 2 else { return false }   // needs at least a couple of real words

        let letters = text.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        let vowels = letters.filter { "aeiou".contains($0) }.count
        let vowelRatio = Double(vowels) / Double(letters.count)
        guard vowelRatio > 0.18 && vowelRatio < 0.85 else { return false }  // real words have balance

        // Reject long keyboard-mash runs of the same/adjacent char with no vowels.
        if longestConsonantRun(letters) >= 6 { return false }

        return true
    }

    private static func longestConsonantRun(_ letters: String) -> Int {
        var longest = 0, current = 0
        for ch in letters {
            if "aeiou".contains(ch) { current = 0 } else { current += 1; longest = max(longest, current) }
        }
        return longest
    }
}

// MARK: - Errors

enum JudgeError: LocalizedError {
    case modelUnavailable
    case parseFailure(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence isn't available on this device."
        case .parseFailure(let raw):
            return "Couldn't parse the judge's response: \(raw)"
        }
    }
}
