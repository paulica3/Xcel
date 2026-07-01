import Foundation
import FoundationModels

// Turns a one-line intention ("get back on track with training and eat clean")
// into a concrete, provable checklist for the day. Prefers the on-device model;
// falls back to a deterministic split when Apple Intelligence isn't available.
enum PlanService {
    static func generate(from intention: String, count: Int = 6) async -> [String] {
        let goal = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else { return [] }

        if let ai = try? await generateWithAI(goal, count: count), !ai.isEmpty {
            return ai
        }
        return heuristic(goal, count: count)
    }

    // MARK: - AI

    private static func generateWithAI(_ goal: String, count: Int) async throws -> [String] {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        let instructions = """
        You turn a person's short intention for today into a clean, checkable to-do list.

        MOST IMPORTANT - respect what they actually said:
        - If they already listed several distinct tasks, return EACH ONE as its own item, in their order. Do NOT split a single coherent task into two (e.g. "cook dinner and clean up" if they meant it as one errand stays one item), and do NOT merge two different tasks into one.
        - If they gave one broad goal with no clear sub-tasks, break it into 3-5 concrete steps that serve it.
        - Never invent tasks they didn't imply. Prefer fidelity to their intention over adding filler.

        Then make each item provable:
        - Give it a number, a duration, or a clear finish line where it helps (e.g. "Read 20 pages", "30-min run", "Inbox to zero").
        - Keep each item tight - under 8 words. No vague verbs like "be productive" or "work on stuff".

        Return between 3 and \(count) items total.

        Respond ONLY with valid JSON, nothing else - an array of strings:
        ["task one","task two","task three"]
        """

        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: "Intention: \(goal)")
        let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            throw JudgeError.parseFailure(response.content)
        }
        let cleanedTasks = arr
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(cleanedTasks.prefix(count))
    }

    // MARK: - Heuristic fallback

    private static func heuristic(_ goal: String, count: Int) -> [String] {
        // Split ONLY on strong list separators (commas, semicolons, newlines,
        // bullets, numbered markers, " then "). Deliberately NOT on " and " -
        // that wrongly chops single tasks like "rest and recover" in two.
        let separators = CharacterSet(charactersIn: ",;\n•")
        var parts = goal
            .replacingOccurrences(of: " then ", with: ",")
            .components(separatedBy: separators)
            .map { stripListMarker($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
            .map { (s: String) -> String in
                guard let first = s.first else { return s }
                return first.uppercased() + String(s.dropFirst())
            }

        if parts.count >= 2 {
            return Array(parts.prefix(count))
        }

        // Otherwise scaffold a single goal into a few concrete steps.
        let g = parts.first ?? goal
        parts = [
            "30 focused minutes: \(g)",
            "One concrete step on \(g)",
            "Review \(g) progress tonight",
        ]
        return Array(parts.prefix(count))
    }

    // Drop a leading list marker like "1.", "2)", or "- " from a split fragment.
    private static func stripListMarker(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        while let f = t.first, f == "-" || f == "*" || f.isNumber || f == "." || f == ")" {
            t.removeFirst()
        }
        return t
    }
}
