import SwiftUI
import SwiftData

struct EntryView: View {
    let game: Game
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings
    @State private var items: [ChecklistItem] = []
    @State private var newItem = ""
    @State private var extraNotes = ""
    @State private var goToSubmit = false

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
        .navigationDestination(isPresented: $goToSubmit) {
            SubmitView(game: game, onComplete: onComplete)
        }
        .onAppear {
            if !isMorning {
                items = game.checklist
                extraNotes = game.extraNotes
            }
        }
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

    // MARK: Morning — build the checklist

    private var morningBuilder: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach($items) { $item in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundStyle(accent.opacity(0.7))
                            TextField("Task", text: $item.title)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                            Button {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color(white: 0.3))
                            }
                        }
                        .padding(14)
                        .background(Color(white: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
            }

            if items.count < 3 {
                Text("Add at least 3 tasks  ·  \(items.count)/3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                TextField("Add a task…", text: $newItem)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onSubmit(addItem)
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
            .padding(.top, 8)
        }
    }

    // MARK: Evening — check off + prove / explain

    private var eveningReview: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 10) {
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
                                Spacer()
                            }
                        }

                        TextField(
                            item.isDone ? "How'd you do it? (proof)" : "What happened? (reason)",
                            text: $item.note,
                            axis: .vertical
                        )
                        .font(.system(size: 14))
                        .foregroundStyle(Color(white: 0.7))
                        .lineLimit(1...3)
                        .padding(10)
                        .background(Color(white: 0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(14)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ANYTHING EXTRA?")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(accent)
                    TextField(
                        "Did more than you planned? Tell the judge. (optional)",
                        text: $extraNotes,
                        axis: .vertical
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.7))
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(white: 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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
        let ready = isMorning ? items.count >= 3 : eveningReady
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
            Text(isMorning ? "Lock in the plan" : "Take it to the judge")
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

    // Every item needs either proof (done) or a reason (not done).
    private var eveningReady: Bool {
        !items.isEmpty && items.allSatisfy { !$0.note.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(ChecklistItem(title: trimmed))
        newItem = ""
    }
}
