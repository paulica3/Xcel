import Foundation
import FoundationModels

struct JudgeResult {
    let verdict: GameVerdict
    let oneLiner: String
}

// Routes to MockJudge on simulator (no Neural Engine), real judge on device.
struct JudgeService {
    func judge(intention: String?, entry: String, seriesRecord: String, gameNumber: Int) async throws -> JudgeResult {
        #if targetEnvironment(simulator)
        return try await MockJudge().judge(intention: intention, entry: entry, seriesRecord: seriesRecord, gameNumber: gameNumber)
        #else
        return try await AppleIntelligenceJudge().judge(intention: intention, entry: entry, seriesRecord: seriesRecord, gameNumber: gameNumber)
        #endif
    }
}

// MARK: - Apple Intelligence (device only)

private struct AppleIntelligenceJudge {
    private let systemPrompt = """
    You are the Judge — a tough-but-fair NBA-style commentator reviewing someone's daily journal entry.

    Decide if they had a W (win) or L (loss) today, then deliver one punchy broadcast-style sentence.

    Judge by:
    - Honesty and specificity. Vague entries and excuses earn an L.
    - Effort shown, not just outcomes. A hard day where they competed is a W.
    - If a morning intention was set, factor in whether they followed through.

    Always frame the verdict within the series. Never treat a single loss as a life judgment.

    Respond ONLY with valid JSON, nothing else:
    {"verdict":"win","oneLiner":"One sentence here."}
    """

    func judge(intention: String?, entry: String, seriesRecord: String, gameNumber: Int) async throws -> JudgeResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw JudgeError.modelUnavailable
        }

        var prompt = "Series going into Game \(gameNumber): \(seriesRecord)\n\n"
        if let intention, !intention.isEmpty {
            prompt += "Morning intention: \(intention)\n\n"
        }
        prompt += "End of day entry: \(entry)"

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
        return JudgeResult(verdict: verdict, oneLiner: oneLiner)
    }
}

// MARK: - Mock (simulator)

private struct MockJudge {
    private let lines: [(GameVerdict, String)] = [
        (.win,  "Showed up, did the work — that's all the judge needed to see."),
        (.win,  "Not pretty, but they competed. W on the board."),
        (.loss, "Vague entry, no receipts. The judge sees through it."),
        (.win,  "Tough day, honest entry — the judge respects the honesty."),
        (.loss, "Excuses don't score points. L."),
        (.win,  "Specificity. Effort. That's a W."),
        (.loss, "The judge needed more than that. Come back tomorrow."),
    ]

    func judge(intention: String?, entry: String, seriesRecord: String, gameNumber: Int) async throws -> JudgeResult {
        try await Task.sleep(for: .seconds(1.5))
        let pick = lines[gameNumber % lines.count]
        return JudgeResult(verdict: pick.0, oneLiner: pick.1)
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
