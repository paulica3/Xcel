import SwiftUI
import SwiftData

struct EntryView: View {
    let game: Game
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var items: [ChecklistItem] = []
    @State private var newItem = ""
    @State private var eveningNewItem = ""
    @State private var extraNotes = ""
    @State private var goToSubmit = false
    @State private var editingPlan = false
    @State private var coachings: [TaskCoaching] = []
    @State private var coachLoading = false
    @State private var showCoaching = false
    @State private var showPlanAI = false

    private var accent: Color { settings.accent.color }
    private var isMorning: Bool { game.checklist.isEmpty }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                navBar
                heading
                if isMorning { morningBuilder } else { eveningReview }
                primaryButton
            }
        }
        .navigationBarHidden(true)
        .dismissKeyboardOnScroll()
        .navigationDestination(isPresented: $goToSubmit) {
            SubmitView(game: game, onComplete: onComplete)
        }
        .onAppear {
            if !isMorning {
                items = game.checklist
                extraNotes = game.extraNotes
            } else if items.isEmpty {
                // Fresh plan - pre-load the user's recurring daily tasks so they
                // don't re-type their staples. Fully editable from here.
                items = settings.recurringTasks
                    .map { ChecklistItem(title: $0) }
            }
        }
        .onDisappear { persistEveningDraft() }
    }

    // Save in-progress evening proof/notes so leaving the page (e.g. before the
    // 6 PM window opens) doesn't lose the work. Only for the evening review -
    // never the morning builder, since writing an empty/partial checklist there
    // would flip the day out of "set the plan" mode.
    private func persistEveningDraft() {
        guard !isMorning, !items.isEmpty else { return }
        game.checklist = items
        game.extraNotes = extraNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
    }

    // MARK: Chrome

    private var navBar: some View {
        HStack {
            Button(action: onComplete) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GAME \(game.gameNumber) · \(isMorning ? "GAME PLAN" : "POSTGAME")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(white: 0.32))
                .kerning(2.5)
            Text(isMorning ? "What's the plan today?" : "How'd it go?")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: Morning - build the checklist

    private var morningBuilder: some View {
        VStack(spacing: 10) {
            // The add field stays pinned at the top so it - and freshly added
            // tasks right below it - remain visible even with the keyboard up.
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Add a task…", text: $newItem, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1...5)
                    .padding(14)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Button(action: addItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 50, height: 50)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)

            // Separate guided path: draft the whole plan from a one-line intention.
            Button { showPlanAI = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(items.isEmpty ? "Plan with AI" : "Add more with AI")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.6))
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, 24)

            hintBar
                .padding(.horizontal, 24)

            // The list takes the remaining height and scrolls under the keyboard.
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($items) { $item in
                        taskRow($item)
                    }
                    if items.isEmpty {
                        Text("Your plan is empty. Add a few tasks above to get started.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showCoaching) {
            CoachingSheet(coachings: coachings, accent: accent) { suggestion in
                if items.indices.contains(suggestion.index) {
                    items[suggestion.index].title = suggestion.improved
                }
            }
        }
        .sheet(isPresented: $showPlanAI) {
            PlanSheet(accent: accent) { titles in
                mergeGeneratedTasks(titles)
            }
        }
    }

    // Append AI-drafted tasks to the plan, skipping ones already there.
    private func mergeGeneratedTasks(_ titles: [String]) {
        let existing = Set(items.map { $0.title.lowercased().trimmingCharacters(in: .whitespaces) })
        for title in titles {
            let key = title.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !existing.contains(key) else { continue }
            items.append(ChecklistItem(title: title))
        }
    }

    private func taskRow(_ item: Binding<ChecklistItem>) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleGameBall(item.wrappedValue.id)
            } label: {
                Image(systemName: item.wrappedValue.isGameBall ? "basketball.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(item.wrappedValue.isGameBall ? accent : accent.opacity(0.5))
            }
            .buttonStyle(.plain)
            TextField("Task", text: item.title, axis: .vertical)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .lineLimit(1...6)
            Button {
                items.removeAll { $0.id == item.wrappedValue.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color(white: 0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // One compact line: progress toward 3 tasks, the game-ball nudge, and the
    // coach shortcut - so the controls don't stack up and crowd the screen.
    private var hintBar: some View {
        HStack(spacing: 8) {
            if items.count < 3 {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.4))
                Text("Add at least 3 tasks · \(items.count)/3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
            } else if items.contains(where: { $0.isGameBall }) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(accent.opacity(0.8))
                Text("Game ball set - the judge leans hardest on it.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent.opacity(0.8))
            } else {
                Text("Tap ○ to call your game ball.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
            }
            Spacer(minLength: 8)
            if !items.isEmpty {
                Button(action: runCoach) {
                    HStack(spacing: 5) {
                        if coachLoading {
                            ProgressView().tint(accent).scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles").font(.system(size: 12))
                        }
                        Text(coachLoading ? "Reading…" : "Tighten")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(accent)
                }
                .disabled(coachLoading)
            }
        }
    }

    private func runCoach() {
        coachLoading = true
        let titles = items.map(\.title)
        Task {
            let result = await CoachService.refine(titles)
            await MainActor.run {
                coachLoading = false
                coachings = result
                showCoaching = true
            }
        }
    }

    // MARK: Evening - check off + prove / explain

    private var editPlanBar: some View {
        HStack {
            Text(editingPlan ? "EDIT THE PLAN" : "POSTGAME REVIEW")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color(white: 0.35))
            Spacer()
            if game.editsLocked {
                // Plan froze at noon - review only from here.
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                    Text("Locked at noon")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.4))
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { editingPlan.toggle() }
                } label: {
                    Text(editingPlan ? "Done" : "Edit plan")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                }
                .disabled(editingPlan && items.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.count < 3)
            }
        }
        .padding(.bottom, 2)
    }

    private var eveningReview: some View {
        ScrollView {
            VStack(spacing: 14) {
                editPlanBar

                if !game.isLoggingOpen {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(accent)
                        Text("Logging opens at 6:00 PM. Fill this in now - you'll submit once the window's open. It closes at 11:59 PM.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.6))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.3), lineWidth: 1))
                }

                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 10) {
                        if editingPlan {
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(accent.opacity(0.7))
                                TextField("Task", text: $item.title, axis: .vertical)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1...6)
                                Button {
                                    items.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Color(white: 0.3))
                                }
                            }
                        } else {
                            Button {
                                item.isDone.toggle()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(item.isDone ? accent : Color(white: 0.4))
                                    Text(item.title)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                        .strikethrough(item.isDone, color: Color(white: 0.4))
                                    if item.isGameBall {
                                        Image(systemName: "basketball.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(accent)
                                    }
                                    Spacer()
                                }
                            }

                            HStack(alignment: .bottom, spacing: 8) {
                                TextField(
                                    item.isDone ? "How'd you do it? (proof)" : "What happened? (reason)",
                                    text: $item.note,
                                    axis: .vertical
                                )
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.7))
                                .lineLimit(1...)
                                .padding(10)
                                .background(Color(white: 0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                MicButton(text: $item.note, accent: accent)
                            }

                            // Photo proof is offered for tasks marked done.
                            if item.isDone {
                                PhotoProofRow(item: $item, accent: accent)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if editingPlan {
                    HStack(alignment: .bottom, spacing: 10) {
                        TextField("Add a task…", text: $eveningNewItem, axis: .vertical)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .lineLimit(1...5)
                            .padding(14)
                            .background(Color(white: 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button(action: addEveningItem) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 50, height: 50)
                                .background(accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(eveningNewItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ANYTHING EXTRA?")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(accent)
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField(
                            "Did more than you planned? Tell the judge. (optional)",
                            text: $extraNotes,
                            axis: .vertical
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.7))
                        .lineLimit(1...)
                        .padding(10)
                        .background(Color(white: 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        MicButton(text: $extraNotes, accent: accent)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Primary action

    private var primaryButton: some View {
        let ready = isMorning ? items.count >= 3 : (eveningReady && game.isLoggingOpen)
        return Button {
            if isMorning {
                game.checklist = items
                try? modelContext.save()
                onComplete()
            } else {
                game.checklist = items
                game.extraNotes = extraNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                try? modelContext.save()
                goToSubmit = true
            }
        } label: {
            Text(primaryTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ready ? .black : Color(white: 0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(ready ? accent : Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!ready)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 40)
        .animation(.easeInOut(duration: 0.15), value: ready)
    }

    private var primaryTitle: String {
        if isMorning { return "Lock in the plan" }
        if !game.isLoggingOpen { return "Logging opens at 6:00 PM" }
        return "Take it to the judge"
    }

    // Every item needs either proof (done) or a reason (not done). Must finish
    // any plan edits first, keep at least 3 tasks, and be inside the 6PM window.
    private var eveningReady: Bool {
        !editingPlan
            && items.count >= 3
            && game.isLoggingOpen
            && items.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespaces).isEmpty
                    && !$0.note.trimmingCharacters(in: .whitespaces).isEmpty
            }
    }

    // Only one task can be the game ball - selecting one clears the rest.
    private func toggleGameBall(_ id: UUID) {
        for i in items.indices {
            items[i].isGameBall = (items[i].id == id) ? !items[i].isGameBall : false
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Newest on top, right under the input, so it's immediately visible.
        items.insert(ChecklistItem(title: trimmed), at: 0)
        newItem = ""
    }

    private func addEveningItem() {
        let trimmed = eveningNewItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(ChecklistItem(title: trimmed))
        eveningNewItem = ""
    }
}

// Coach suggestions for tightening vague tasks; accept to apply the rewrite.
private struct CoachingSheet: View {
    let coachings: [TaskCoaching]
    let accent: Color
    let onAccept: (TaskCoaching) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: [TaskCoaching] = []
    @State private var didLoad = false

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("THE COACH")
                                .font(.system(size: 11, weight: .bold))
                                .kerning(2.5)
                                .foregroundStyle(accent)
                            Text("Tighten your plan")
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
                    .padding(.top, 8)

                    if remaining.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(accent)
                            Text("Your plan is sharp.")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Nothing vague to tighten - lock it in.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else {
                        ForEach(remaining) { c in
                            card(c)
                        }
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            remaining = coachings
            didLoad = true
        }
    }

    private func card(_ c: TaskCoaching) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(c.original)
                .font(.system(size: 14))
                .strikethrough(color: Color(white: 0.4))
                .foregroundStyle(Color(white: 0.5))
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12))
                    .foregroundStyle(accent)
                Text(c.improved)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            if !c.reason.isEmpty {
                Text(c.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.45))
            }
            HStack(spacing: 10) {
                Button {
                    onAccept(c)
                    remaining.removeAll { $0.id == c.id }
                } label: {
                    Text("Use this")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    remaining.removeAll { $0.id == c.id }
                } label: {
                    Text("Keep mine")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
