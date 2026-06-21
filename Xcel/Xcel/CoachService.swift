import Foundation
import FoundationModels

// A suggested sharper rewrite of a vague task.
struct TaskCoaching: Identifiable {
    let id = UUID()
    let index: Int
    let original: String
    let improved: String
    let reason: String
}

// Reviews the morning plan and tightens weak/vague tasks before lock-in, so the
// judge has something concrete to grade tonight.
enum CoachService {
    static func refine(_ tasks: [String]) async -> [TaskCoaching] {
        let cleaned = tasks.enumerated().compactMap { idx, t -> (Int, String)? in
            let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : (idx, s)
        }
        guard !cleaned.isEmpty else { return [] }

        if let ai = try? await analyzeWithAI(cleaned) { return ai }
        return heuristic(cleaned)
    }

    // MARK: - AI

    private static func analyzeWithAI(_ tasks: [(Int, String)]) async throws -> [TaskCoaching] {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        let instructions = """
        You are a no-nonsense coach reviewing someone's task list for today before it locks in.
        Find the VAGUE or unmeasurable tasks (e.g. "be productive", "work out", "study") and rewrite
        each into a concrete, specific, provable version with a number, a duration, or a clear finish line.
        Only return tasks that genuinely need tightening - leave already-specific ones out.

        Respond ONLY with valid JSON, nothing else - an array:
        [{"index":0,"improved":"sharper version","reason":"one short why"}]
        """

        var prompt = "Tasks:\n"
        for (i, t) in tasks { prompt += "\(i): \(t)\n" }

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw JudgeError.parseFailure(response.content)
        }
        let byIndex = Dictionary(uniqueKeysWithValues: tasks)
        return arr.compactMap { obj in
            guard let idx = obj["index"] as? Int,
                  let improved = obj["improved"] as? String,
                  let original = byIndex[idx] else { return nil }
            return TaskCoaching(index: idx, original: original,
                                improved: improved, reason: (obj["reason"] as? String) ?? "")
        }
    }

    // MARK: - Heuristic fallback

    private static let vagueWords: Set<String> = [
        "productive", "work", "workout", "study", "exercise", "read", "clean",
        "grind", "focus", "better", "stuff", "things", "more", "less", "healthy"
    ]

    private static func heuristic(_ tasks: [(Int, String)]) -> [TaskCoaching] {
        tasks.compactMap { idx, t in
            let words = t.split(separator: " ")
            let hasNumber = t.rangeOfCharacter(from: .decimalDigits) != nil
            let lower = t.lowercased()
            let isVague = words.count <= 2 || (!hasNumber && vagueWords.contains { lower.contains($0) })
            guard isVague else { return nil }
            return TaskCoaching(
                index: idx,
                original: t,
                improved: "\(t) - add a number, a time, or a finish line",
                reason: "Too open-ended to prove tonight. Make it measurable."
            )
        }
    }
}
