import Foundation
import FoundationModels

struct JudgeResult {
    let verdict: GameVerdict
    let oneLiner: String
    let feedback: String
    // Box score, each 0-10 to one decimal. Defaults to zeros (= not scored).
    var effort: Double = 0
    var discipline: Double = 0
    var mood: Double = 0
    var productivity: Double = 0
}

struct BoxScore {
    let effort: Double
    let discipline: Double
    let mood: Double
    let productivity: Double

    static let dimensions = ["Effort", "Discipline", "Mood", "Productivity"]
    var values: [Double] { [effort, discipline, mood, productivity] }
    var average: Double { (effort + discipline + mood + productivity) / 4.0 }
}

// How hard the judge leans, based on the current series state.
enum JudgeStance {
    case homeCourt    // down 2+ - ease up, keep them in the fight
    case elimination  // 3 losses - win or the series is over
    case lockedIn     // cruising (3-0) - raise the bar
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
            return "ELIMINATION GAME: They're down 1-3 (or worse) - one more L ends the series. Be fair but make the stakes vivid. Reward real fight."
        case .lockedIn:
            return "RAISE THE BAR: They're dominating. Judge strictly - vague wins don't cut it anymore. Demand specificity, real effort, and follow-through."
        case .standard:
            return "Judge tough-but-fair at the normal bar."
        }
    }
}

// The guide whose voice the judge speaks in. These are original characters whose
// personalities are INSPIRED BY the nicknames of three all-time greats - no real
// names, likenesses, or trademarks are used, which keeps it clear of publicity
// rights. Tone only; the verdict standard never changes with the guide.
enum Guide: String, CaseIterable, Identifiable {
    case ant, maestro, king

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ant:     return "The Ant"
        case .maestro: return "The Maestro"
        case .king:    return "The King"
        }
    }

    var blurb: String {
        switch self {
        case .ant:     return "Confident, hard to please. Pure ATL energy."
        case .maestro: return "Deep, team-first reads. Old-world flavor."
        case .king:    return "A vet of the game. Wise, a little corny."
        }
    }

    // SF Symbol shown until a custom comic portrait asset is added.
    var icon: String {
        switch self {
        case .ant:     return "bolt.fill"
        case .maestro: return "brain.head.profile"
        case .king:    return "crown.fill"
        }
    }

    // Optional comic-portrait asset (drop a matching image into Assets.xcassets).
    var imageName: String {
        switch self {
        case .ant:     return "guide_ant"
        case .maestro: return "guide_maestro"
        case .king:    return "guide_king"
        }
    }

    // Injected into the judge's instructions to set delivery only.
    var directive: String {
        switch self {
        case .ant:
            return "VOICE - THE ANT: Young, supremely confident, hard to impress, pure Atlanta swagger and slang (\"bro\", \"on God\", \"that's crazy\", \"we hooping\", \"too easy\"). Hype the real dogs, but call out anything soft - praise is earned, never cheap. Brash and charismatic, never mean. Tone only; do NOT change how strictly you judge."
        case .maestro:
            return "VOICE - THE MAESTRO: A calm, humble, brilliant big man who sees the whole floor. Give cerebral, team-first reads on what actually moved the day; value the little things and the 'assist' tasks that set up everything else. Dry, deadpan humor with a light old-world (Eastern-European) flavor (\"my friend\"). Understated, never flashy. Tone only; do NOT change how strictly you judge."
        case .king:
            return "VOICE - THE KING: A wise veteran and all-time great. Big-picture advice about longevity, consistency, and the long game; measured and motivational, with the occasional corny dad-joke (\"literally\", \"at the end of the day\", \"young king\"). Tone only; do NOT change how strictly you judge."
        }
    }
}

// Prefers the real on-device model (works on device, and on Apple-Silicon
// simulators when Apple Intelligence is enabled in macOS). Falls back to a
// credibility-aware heuristic judge only when the model is unavailable.
struct JudgeService {
    // False only for hardware that can never run Apple Intelligence, no
    // matter what Settings toggle is flipped or how long you wait for a
    // model download. Used to hard-gate app entry, unlike practiceJudgeNote's
    // other (recoverable) unavailable cases below.
    static var isDeviceEligible: Bool {
        if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability {
            return false
        }
        return true
    }

    // nil when the real on-device AI judge is ready; otherwise a short, friendly
    // line explaining why the practice judge is standing in.
    static var practiceJudgeNote: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Practice judge - turn on Apple Intelligence in Settings for the real AI."
        case .unavailable(.deviceNotEligible):
            return "Practice judge - this device doesn't support Apple Intelligence."
        case .unavailable(.modelNotReady):
            return "Practice judge - the AI is still downloading. Try again shortly."
        case .unavailable:
            return "Practice judge - Apple Intelligence isn't available right now."
        }
    }

    func judge(checklist: [ChecklistItem], extraNotes: String, wins: Int, losses: Int, gameNumber: Int, guide: Guide = .king, memory: String = "") async throws -> JudgeResult {
        let stance = JudgeStance.forSeries(wins: wins, losses: losses)
        do {
            return try await AppleIntelligenceJudge().judge(checklist: checklist, extraNotes: extraNotes, wins: wins, losses: losses, gameNumber: gameNumber, stance: stance, guide: guide, memory: memory)
        } catch {
            return try await MockJudge().judge(checklist: checklist, extraNotes: extraNotes, wins: wins, losses: losses, gameNumber: gameNumber, stance: stance, guide: guide, memory: memory)
        }
    }
}

// MARK: - Apple Intelligence (device only)

private struct AppleIntelligenceJudge {
    private let basePrompt = """
    You are the Judge - a tough-but-fair NBA-style commentator reviewing someone's daily game plan.

    They set tasks this morning. Tonight they marked each done or not done, with proof (if done) or a reason (if not).

    BE CRITICAL AND SKEPTICAL. This is the most important rule:
    - Proof must be specific and believable. Gibberish, random characters ("asdasd"), single vague words ("done", "yes", "did it"), or proof that doesn't actually describe HOW the task was accomplished is NOT valid - treat that task as effectively NOT done and call it out.
    - A checkbox ticked with no real proof earns no credit. Do not reward a checkmark on its own.
    - If most of the proof is empty, vague, or nonsense, the day is a LOSS regardless of how many boxes were checked.

    WRITE IT FRESH EVERY TIME. This is critical: vary your sentence structure, length, opening, and word choice from one day to the next. Do NOT follow a fixed template or recycle stock phrases across verdicts - two different days should never read like they were filled into the same mould. React to THIS day's specific tasks and proof, not a formula.

    Decide the day: W (win) or L (loss), then write:
    - oneLiner: one punchy broadcast-style sentence delivering the verdict, framed within the series. Open it a different way each time.
    - feedback: 2-4 sentences of coach's notes. ALWAYS quote or name the actual tasks and proof - never speak in generic terms.
      • On a WIN: make the praise EARNED and SPECIFIC. Name the exact task(s) they executed and what in their proof sold it. Call out the single strongest moment of the day. Then give one concrete way to push further tomorrow. BANNED - never write empty filler like "you showed up", "good job", "keep it up", "nice work", "stay consistent", "build momentum". If you can't point to something specific they did, it wasn't a win.
      • On a LOSS: name the weak/nonsense/empty proof directly and the one task to protect tomorrow.

    Other rules:
    - PHOTO PROOF: a task may include verified photo evidence taken today [PHOTO PROOF: verified, taken today]. Treat that as strong, credible proof - the user backed it up with a same-day picture. An [attached, unverified] photo is weaker (no same-day timestamp) - acknowledge it but don't fully trust it.
    - GAME BALL: if a task is tagged [GAME BALL], that's the user's declared priority for the day - weight it heavily. Nailing the game ball with real proof can carry a borderline day to a W; whiffing on it (skipped, or fake/empty proof) should drag the day toward an L even if smaller tasks got done. Name the game ball explicitly in your notes.
    - Reward honesty, specificity, and real effort. Penalize vague proof and flimsy excuses.
    - Judge fairly on reasons for incomplete tasks. GENUINE hardship (illness, hospital, family emergency, injury) is NOT the user's fault - do not be harsh; a day derailed by real hardship can still be a W if they handled it with integrity. Flimsy excuses ("didn't feel like it", "too tired") earn an L.
    - Never frame a loss as a standalone life judgment.

    Also rate the day 0-10 on four dimensions (the "box score"), to ONE DECIMAL (e.g. 7.4, 8.9):
    - effort: how hard they actually worked / showed up
    - discipline: sticking to the plan and resisting excuses
    - mood: emotional state / attitude as reflected in their entry
    - productivity: how much of real value got done
    SCORE STRICTLY. A 10.0 is a perfect, elite, no-flaws day - it should be RARE; almost no day earns it. Use the decimal to be precise instead of rounding up: a strong, clean win usually lands 7.5-9.0, a good-not-great day 6.0-7.4, a loss below 5.0, and nonsense proof near 0. Do not give a 9 or 10 unless they truly earned it with specific, verified, complete execution. Reward real excellence, but make the top of the scale something to chase.

    Respond ONLY with valid JSON, nothing else:
    {"verdict":"win","oneLiner":"...","feedback":"...","effort":7.4,"discipline":6.8,"mood":8.1,"productivity":7.2}
    """

    func judge(checklist: [ChecklistItem], extraNotes: String, wins: Int, losses: Int, gameNumber: Int, stance: JudgeStance, guide: Guide, memory: String = "") async throws -> JudgeResult {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw JudgeError.modelUnavailable
        }

        var systemPrompt = basePrompt + "\n\n" + stance.directive + "\n\n" + guide.directive
        if !memory.isEmpty {
            systemPrompt += "\n\nSEASON MEMORY (what you know about this player long-term). Use it to personalize - call out a real pattern when it's relevant today - but it does NOT change how strictly you score:\n" + memory
        }

        var prompt = "Series going into Game \(gameNumber): \(wins)–\(losses)\n\nTasks:\n"
        for item in checklist {
            let mark = item.isDone ? "[DONE]" : "[NOT DONE]"
            let star = item.isGameBall ? " [GAME BALL]" : ""
            let label = item.isDone ? "proof" : "reason"
            var photo = ""
            if item.photoData != nil {
                photo = item.photoVerified ? " [PHOTO PROOF: verified, taken today]" : " [PHOTO PROOF: attached, unverified]"
            }
            prompt += "\(mark)\(star) \(item.title) - \(label): \(item.note)\(photo)\n"
        }
        if !extraNotes.isEmpty {
            prompt += "\nExtra (beyond the plan - reward genuine initiative): \(extraNotes)\n"
        }

        let session = LanguageModelSession(instructions: systemPrompt)
        let response = try await session.respond(to: prompt)
        return try parse(response.content)
    }

    private func parse(_ raw: String) throws -> JudgeResult {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verdictStr = json["verdict"] as? String,
              let oneLiner = json["oneLiner"] as? String else {
            throw JudgeError.parseFailure(raw)
        }
        let verdict: GameVerdict = verdictStr.lowercased() == "win" ? .win : .loss
        func score(_ key: String) -> Double {
            let v = (json[key] as? Double) ?? Double((json[key] as? Int) ?? 0)
            // Keep one decimal of precision, clamped to 0...10.
            return min(10, max(0, (v * 10).rounded() / 10))
        }
        return JudgeResult(
            verdict: verdict,
            oneLiner: oneLiner,
            feedback: (json["feedback"] as? String) ?? "",
            effort: score("effort"),
            discipline: score("discipline"),
            mood: score("mood"),
            productivity: score("productivity")
        )
    }
}

// MARK: - Mock (simulator)

private struct MockJudge {
    func judge(checklist: [ChecklistItem], extraNotes: String, wins: Int, losses: Int, gameNumber: Int, stance: JudgeStance, guide: Guide, memory: String = "") async throws -> JudgeResult {
        try await Task.sleep(for: .seconds(1.2))

        let total = max(checklist.count, 1)

        // Verbatim notes reused across multiple tasks are copy-paste, not
        // individual evidence - neither occurrence counts as real proof.
        let doneNotes = checklist.filter { $0.isDone }.map { $0.note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let reusedNotes = Set(Dictionary(grouping: doneNotes, by: { $0 }).filter { $0.value.count > 1 }.keys)

        // A task counts if it's checked AND backed up - either with credible text
        // proof or with a verified, same-day photo.
        func backed(_ i: ChecklistItem) -> Bool {
            if i.photoVerified { return true }
            guard Credibility.isCredible(i.note) else { return false }
            let note = i.note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            // Restating the task title back isn't evidence of doing it.
            if note == i.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() { return false }
            if reusedNotes.contains(note) { return false }
            return true
        }
        let credited = checklist.filter { $0.isDone && backed($0) }.count
        let fakeProof = checklist.filter { $0.isDone && !backed($0) }
        let hasExtra = Credibility.isCredible(extraNotes)
        var ratio = Double(credited) / Double(total) + (hasExtra ? 0.15 : 0)

        // Game ball: the declared priority swings the day more than a normal task.
        let gameBall = checklist.first { $0.isGameBall }
        let gameBallNailed = gameBall.map { $0.isDone && Credibility.isCredible($0.note) } ?? false
        if gameBall != nil { ratio += gameBallNailed ? 0.12 : -0.18 }

        let hardshipWords = ["hospital", "sick", "ill", "emergency", "injured", "injury", "family", "funeral"]
        let hadHardship = checklist.contains { item in
            !item.isDone && Credibility.isCredible(item.note)
                && hardshipWords.contains { item.note.lowercased().contains($0) }
        }

        // Nonsense proof is an automatic red flag - the judge is not fooled.
        if !fakeProof.isEmpty && credited == 0 {
            let names = fakeProof.prefix(2).map { "“\($0.title)”" }.joined(separator: ", ")
            return JudgeResult(
                verdict: .loss,
                oneLiner: "Checked the boxes, but the proof was smoke. The judge isn't buying it - L.",
                feedback: "The proof on \(names) doesn't describe how you actually did anything. A checkmark with no real receipt counts for nothing. Tomorrow: write one concrete sentence of evidence per task - what you did, when, and how.",
                effort: 2, discipline: 1, mood: 3, productivity: 1
            )
        }

        let threshold: Double
        switch stance {
        case .homeCourt, .elimination: threshold = 0.34
        case .lockedIn:                threshold = 0.8
        case .standard:                threshold = 0.5
        }
        let verdict: GameVerdict = (ratio >= threshold || hadHardship) ? .win : .loss

        var oneLiner: String
        var feedback: String
        if verdict == .win {
            // Name the standout: the credited task with the most substantial proof.
            let creditedItems = checklist.filter { $0.isDone && Credibility.isCredible($0.note) }
            let standout = creditedItems.max { $0.note.count < $1.note.count }

            oneLiner = hadHardship
                ? "Life threw a curveball and you kept your integrity. The judge respects it - W."
                : "\(credited) of \(total) backed up with real proof. That's a W."

            var notes: String
            if let standout {
                notes = "“\(standout.title)” was the anchor of the day - the receipt on it held up, no hand-waving."
            } else {
                notes = "You handled what life threw at you without dropping your standards."
            }
            if creditedItems.count > 1 {
                notes += " Backing it with \(credited) of \(total) is what tipped this to a W."
            }
            if !fakeProof.isEmpty {
                let names = fakeProof.prefix(2).map { "“\($0.title)”" }.joined(separator: ", ")
                notes += " Where it got shaky: the proof on \(names) was thin - write it like you'd have to defend it."
            } else {
                notes += " Tomorrow, raise it: add a harder task and prove that one too."
            }
            feedback = notes
        } else {
            oneLiner = "\(credited) of \(total) held up. Not enough - L."
            feedback = "The plan was there; the credible follow-through wasn't. Pick the one task that mattered most and protect it tomorrow - win the small battle first, with proof you'd stand behind."
        }

        // Call out the game ball directly.
        if let gb = gameBall {
            feedback += gameBallNailed
                ? " Your game ball - “\(gb.title)” - came through. That's the one that anchored it."
                : " You called “\(gb.title)” your game ball and let it slip. That's the one you can't drop."
        }

        // Deliver in the chosen guide's voice.
        oneLiner = Self.styleLine(guide, win: verdict == .win, base: oneLiner)
        feedback = Self.styleFeedback(guide, win: verdict == .win, base: feedback)

        // Heuristic box score derived from completion + integrity of the proof.
        // Kept strict and decimal: a clean sweep tops out around ~9, not a flat 10.
        let checkedCount = checklist.filter { $0.isDone }.count
        func clamp(_ x: Double) -> Double { min(10, max(0, (x * 10).rounded() / 10)) }
        let base = ratio * 9.2
        let effort = clamp(Double(checkedCount) / Double(total) * 9.0 + (hasExtra ? 0.8 : 0))
        let discipline = clamp(base + (fakeProof.isEmpty ? 0.6 : -3.0))
        let productivity = clamp(Double(credited) / Double(total) * 9.0)
        let mood = clamp(verdict == .win ? (hadHardship ? 6.2 : 7.8) : 3.8)

        return JudgeResult(
            verdict: verdict, oneLiner: oneLiner, feedback: feedback,
            effort: effort, discipline: discipline, mood: mood, productivity: productivity
        )
    }

    // Persona delivery for the offline judge (the on-device AI handles its own
    // voice via the prompt). Keeps the analysis, changes only how it lands. Each
    // sign-off is picked at random from a pool so back-to-back days don't read
    // identically.
    private static func styleLine(_ g: Guide, win: Bool, base: String) -> String {
        let pool: [String]
        switch (g, win) {
        case (.ant, true):      pool = [" That's hooping, bro - on God. 🔥", " Too easy. We different.", " Certified bucket. Keep cooking.", " That's dawg work. On God."]
        case (.ant, false):     pool = [" Nah, that was soft. Lock in.", " We better than that, bro.", " That ain't it. Tighten up.", " I need more outta you."]
        case (.maestro, true):  pool = [" Good basketball, my friend.", " The little things added up.", " Simple, clean, effective.", " That's how you move the game."]
        case (.maestro, false): pool = [" It's okay, my friend. We fix it.", " No panic. Tomorrow we adjust.", " We lost the possession, not the game.", " Small mistakes, easy corrections."]
        case (.king, true):     pool = [" That's the standard, young king.", " Championship habits right there.", " Stack it and keep climbing.", " That's the blueprint."]
        case (.king, false):    pool = [" It's a long season. Run it back.", " Even the greats drop games.", " Learn it and flip the page.", " Adversity's part of the arc."]
        }
        return base + (pool.randomElement() ?? "")
    }

    private static func styleFeedback(_ g: Guide, win: Bool, base: String) -> String {
        let pool: [String]
        switch g {
        case .ant:     pool = win ? [" Don't get comfortable, bro.", " Now go do it again."] : [" I know you got more than that.", " Prove me wrong tomorrow."]
        case .maestro: pool = [" Take care of the small stuff first.", " Basketball is a team game.", " Patience, my friend - it compounds."]
        case .king:    pool = [" Longevity is the goal.", " One day at a time.", " The long game always wins."]
        }
        return base + (pool.randomElement() ?? "")
    }
}

// Heuristic gibberish / low-effort detector for the offline fallback judge.
enum Credibility {
    static func isCredible(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.count >= 8 else { return false }

        let words = text.split(whereSeparator: { !$0.isLetter }).filter { $0.count >= 2 }
        guard words.count >= 2 else { return false }   // needs at least a couple of real words

        // Reject "done done done done" - padding one word to fake a real sentence.
        let uniqueWords = Set(words)
        guard Double(uniqueWords.count) / Double(words.count) > 0.5 else { return false }

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
