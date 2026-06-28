import Foundation
import FoundationModels

// Turns a one-line intention ("get back on track with training and eat clean")
// into a concrete, provable checklist for the day. Prefers the on-device model;
// falls back to a deterministic split when Apple Intelligence isn't available.
enum PlanService {
    static func generate(from intention: String, count: Int = 4) async -> [String] {
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
        You are a sharp day-planning coach. The user gives you a short intention for today.
        Turn it into \(count) concrete, specific, PROVABLE tasks they could check off tonight.
        Rules:
        - Each task gets a number, a duration, or a clear finish line (e.g. "Read 20 pages", "30-min run", "Inbox to zero").
        - Make them realistic for ONE day and directly serve the intention.
        - Keep each task under 8 words. No vague verbs like "be productive" or "work on".
        - Return between 3 and \(count) tasks.

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
        // If the intention already lists several things, split it into tasks.
        let separators = CharacterSet(charactersIn: ",;\n•")
        var parts = goal
            .components(separatedBy: separators)
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
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
}
