import SwiftData
import Foundation
import FoundationModels

// Holds the player accountable for a won Challenge Call. When a challenge is
// overturned, the player promises a concrete fix. The FOLLOWING series, once it's
// complete, is judged against that promise. If they didn't live it out, they lose
// the Challenge Call for the series after that - earn the privilege back by
// actually doing what you said you would.
enum FollowThroughService {

    // The real (non-warm-up) series immediately before `series`, by calendar week.
    static func priorRealSeries(before series: Series, in all: [Series]) -> Series? {
        all.filter { !$0.isWarmup && $0.weekStart < series.weekStart }
            .max { $0.weekStart < $1.weekStart }
    }

    // A series can't use its Challenge Call if the series right before it was
    // evaluated for follow-through and the player did NOT honor their promise.
    // The lockout lasts exactly one series.
    static func challengeLocked(for series: Series, in all: [Series]) -> Bool {
        guard let prior = priorRealSeries(before: series, in: all) else { return false }
        return prior.followUpEvaluated && !prior.followUpHonored
    }

    // Lazy background pass (run on app open): for any completed real series that
    // follows a series with an overturned Challenge Call, judge whether the
    // promise was lived out and persist the result. Guarded so it runs once.
    static func runPendingEvaluations(in all: [Series], context: ModelContext) async {
        for series in all where !series.isWarmup {
            guard !series.followUpEvaluated, series.isComplete else { continue }
            guard let prior = priorRealSeries(before: series, in: all),
                  let plan = prior.overturnedChallengePlan,
                  !plan.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let summary = weekSummary(series)
            let honored = await evaluate(plan: plan, week: summary)
            await MainActor.run {
                series.followUpEvaluated = true
                series.followUpHonored = honored
                try? context.save()
            }
        }
    }

    // Everything the player actually did across the judged games of a series.
    private static func weekSummary(_ s: Series) -> String {
        var out = ""
        for game in s.games.sorted(by: { $0.gameNumber < $1.gameNumber }) where game.verdict != .pending {
            for item in game.checklist {
                out += item.isDone ? "[done] " : "[missed] "
                out += item.title
                if !item.note.isEmpty { out += " - \(item.note)" }
                out += "\n"
            }
            if !game.extraNotes.isEmpty { out += "Extra: \(game.extraNotes)\n" }
        }
        return out
    }

    private static func evaluate(plan: String, week: String) async -> Bool {
        do { return try await AIFollowThrough().judge(plan: plan, week: week) }
        catch { return MockFollowThrough.judge(plan: plan, week: week) }
    }
}

// MARK: - On-device AI follow-through check

private struct AIFollowThrough {
    private let instructions = """
    Last week the player won a CHALLENGE CALL by promising a specific fix. You are checking whether
    they actually followed through the next week. You'll get THE PROMISE, then EVERYTHING THEY DID the
    following week (their daily tasks and notes).

    Decide: did they genuinely act on the promise? Be fair but firm - real, visible effort toward the
    promised change counts as honored; ignoring it, or vague unrelated activity, does not.

    Respond ONLY with valid JSON, nothing else:
    {"honored": true}
    """

    func judge(plan: String, week: String) async throws -> Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        let prompt = "THE PROMISE:\n\(plan)\n\nWHAT THEY DID THIS WEEK:\n\(week.isEmpty ? "(no logged days)" : week)\n"
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)

        let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JudgeError.parseFailure(response.content)
        }
        return (json["honored"] as? Bool) ?? true
    }
}

// MARK: - Heuristic fallback (no AI on device)

private enum MockFollowThrough {
    private static let stop: Set<String> = [
        "will", "i'll", "next", "time", "plan", "going", "im", "the", "and", "more",
        "that", "this", "with", "for", "from", "now", "make", "sure", "instead",
        "better", "improve", "tomorrow", "every", "day", "have", "been", "than",
        "because", "about", "would", "should", "could", "into", "them", "they"
    ]

    // Followed through if a meaningful share of the promise's keywords actually
    // show up in what the player did the next week.
    static func judge(plan: String, week: String) -> Bool {
        let planWords = Set(
            plan.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count >= 4 && !stop.contains($0) }
        )
        guard !planWords.isEmpty else { return true }   // nothing concrete to check - give the benefit
        let weekText = week.lowercased()
        let hits = planWords.filter { weekText.contains($0) }.count
        return Double(hits) >= max(1.0, Double(planWords.count) * 0.34)
    }
}
