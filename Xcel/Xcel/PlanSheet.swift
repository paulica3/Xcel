import SwiftUI

// The "Plan with AI" guided flow: the user types a one-line intention, the AI
// drafts a concrete checklist, they tweak/deselect, then add it to the morning
// plan. A separate path that lives alongside the manual builder.
struct PlanSheet: View {
    let accent: Color
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var intention = ""
    @State private var generating = false
    @State private var drafts: [Draft] = []
    @State private var didGenerate = false

    private struct Draft: Identifiable {
        let id = UUID()
        var title: String
        var include: Bool = true
    }

    private var selectedTitles: [String] {
        drafts.filter { $0.include }
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        prompt
                        if !drafts.isEmpty { draftList }
                        else if didGenerate && !generating { emptyResult }
                    }
                    .padding(24)
                }

                if !drafts.isEmpty { addButton }
            }
        }
        .dismissKeyboardOnScroll()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAN WITH AI")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Draft today's plan")
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
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What do you want today to be about? One line - the AI turns it into provable tasks.")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.5))
                .fixedSize(horizontal: false, vertical: true)

            TextField("e.g. reset my routine - train, eat clean, study", text: $intention, axis: .vertical)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .lineLimit(1...3)
                .padding(14)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: generate) {
                HStack(spacing: 8) {
                    if generating {
                        ProgressView().tint(.black).scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(generating ? "Drafting…" : (drafts.isEmpty ? "Generate plan" : "Regenerate"))
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canGenerate ? accent : Color(white: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canGenerate)
        }
    }

    private var draftList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR DRAFT · tap to keep or drop")
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color(white: 0.35))

            ForEach($drafts) { $draft in
                HStack(spacing: 12) {
                    Button {
                        draft.include.toggle()
                    } label: {
                        Image(systemName: draft.include ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(draft.include ? accent : Color(white: 0.3))
                    }
                    .buttonStyle(.plain)

                    TextField("Task", text: $draft.title)
                        .font(.system(size: 16))
                        .foregroundStyle(draft.include ? .white : Color(white: 0.4))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(white: 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var emptyResult: some View {
        Text("Couldn't draft from that - try a few more words about your day.")
            .font(.system(size: 13))
            .foregroundStyle(Color(white: 0.4))
            .padding(.top, 6)
    }

    private var addButton: some View {
        Button {
            onAdd(selectedTitles)
            dismiss()
        } label: {
            Text(selectedTitles.isEmpty ? "Keep at least one task" : "Add \(selectedTitles.count) to my plan")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(selectedTitles.isEmpty ? Color(white: 0.3) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(selectedTitles.isEmpty ? Color(white: 0.12) : accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedTitles.isEmpty)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var canGenerate: Bool {
        !generating && intention.trimmingCharacters(in: .whitespaces).count >= 3
    }

    private func generate() {
        generating = true
        let goal = intention
        Task {
            let tasks = await PlanService.generate(from: goal)
            await MainActor.run {
                drafts = tasks.map { Draft(title: $0) }
                didGenerate = true
                generating = false
            }
        }
    }
}
