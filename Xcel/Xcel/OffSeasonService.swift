import Foundation
import FoundationModels

// The AI's ruling on a vacation request. Approving pauses every day in the
// window - no auto-loss, no notifications, no effect on streak/record - so
// the bar exists only to keep this an honest "I'm actually traveling" check,
// not a strict interrogation. Mirrors ChallengeService's shape exactly.
struct OffSeasonApproval {
    let approved: Bool
    let verdict: String   // one short sentence shown back to the user
}

enum OffSeasonService {
    static let maxDurationDays = 14
    static let defaultDurationDays = 7
    static let maxPerYear = 2

    static func review(description: String, days: Int) async -> OffSeasonApproval {
        if let ai = try? await AIReviewer().review(description: description, days: days) {
            return ai
        }
        return heuristic(description: description, days: days)
    }

    // MARK: Quota / active-window helpers

    static func periods(in year: Int, from periods: [OffSeasonPeriod]) -> [OffSeasonPeriod] {
        periods.filter { Calendar.current.component(.year, from: $0.startDate) == year }
    }

    static func approvedThisYear(_ periods: [OffSeasonPeriod]) -> Int {
        Self.periods(in: Calendar.current.component(.year, from: Date()), from: periods).count
    }

    static func remainingThisYear(_ periods: [OffSeasonPeriod]) -> Int {
        max(0, maxPerYear - approvedThisYear(periods))
    }

    // The currently-active window covering `date`, if any.
    static func isActive(_ periods: [OffSeasonPeriod], on date: Date) -> OffSeasonPeriod? {
        let day = Calendar.current.startOfDay(for: date)
        return periods.first {
            day >= Calendar.current.startOfDay(for: $0.startDate)
                && day <= Calendar.current.startOfDay(for: $0.endDate)
        }
    }

    private static func heuristic(description: String, days: Int) -> OffSeasonApproval {
        let wordCount = description.split(whereSeparator: { $0.isWhitespace }).count
        let credible = Credibility.isCredible(description) && wordCount >= 6
        if credible {
            return OffSeasonApproval(
                approved: true,
                verdict: "Enjoy the trip - \(days) day\(days == 1 ? "" : "s") off, streak and record untouched."
            )
        }
        return OffSeasonApproval(
            approved: false,
            verdict: "Give a bit more detail - where are you headed and what's the plan?"
        )
    }
}

// MARK: - On-device AI reviewer

private struct AIReviewer {
    private let instructions = """
    You are reviewing an OFF-SEASON (vacation) request in a habit-tracking app that gamifies each
    week as an NBA 7-game series. Approving PAUSES every day in the window - no auto-loss, no
    nudges, no effect on the player's streak or record. This is an honor-system check against
    people using it to dodge accountability, not a strict interrogation - most genuine requests
    should pass.

    APPROVE if the description reads like a real, specific travel/vacation plan - a destination,
    an event, or a clear reason, plus a rough sense of timing. Vague filler ("just need a break",
    "taking some time off", one or two words, gibberish) should be DENIED - ask for specifics.

    Respond ONLY with valid JSON, nothing else:
    {"approved":true,"verdict":"one short, friendly sentence explaining the call"}
    """

    func review(description: String, days: Int) async throws -> OffSeasonApproval {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw JudgeError.modelUnavailable }

        let prompt = "Requested time off: \(days) day(s).\nPlayer's description:\n\(description)"
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt)
        return try parse(response.content)
    }

    private func parse(_ raw: String) throws -> OffSeasonApproval {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JudgeError.parseFailure(raw)
        }
        return OffSeasonApproval(
            approved: (json["approved"] as? Bool) ?? false,
            verdict: (json["verdict"] as? String) ?? ""
        )
    }
}
