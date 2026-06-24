import SwiftUI

// Manage the staple tasks that auto-load into every new day's game plan. Saved on
// AppSettings (UserDefaults), so they pre-fill the morning builder without
// re-typing. The user can still edit or remove them on any given day.
struct RecurringTasksView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var newTask = ""

    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                Text("These get added to every new day's plan automatically. You can still tweak or drop them on any given day.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                HStack(spacing: 10) {
                    TextField("Add a daily task…", text: $newTask)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color(white: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.done)
                        .onSubmit(addTask)
                    Button(action: addTask) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 50, height: 50)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(newTask.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 8) {
                        if settings.recurringTasks.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(settings.recurringTasks.enumerated()), id: \.offset) { index, task in
                                taskRow(task, index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ROUTINE")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Daily tasks")
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
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "repeat")
                .font(.system(size: 30))
                .foregroundStyle(Color(white: 0.3))
            Text("No daily tasks yet.")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))
            Text("Add a staple above - like \u{201C}20 pushups after waking up\u{201D} - and it'll be waiting in every new plan.")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.35))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal, 8)
    }

    private func taskRow(_ task: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15))
                .foregroundStyle(accent.opacity(0.8))
            Text(task)
                .font(.system(size: 16))
                .foregroundStyle(.white)
            Spacer()
            Button {
                guard settings.recurringTasks.indices.contains(index) else { return }
                settings.recurringTasks.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color(white: 0.3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func addTask() {
        let trimmed = newTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.recurringTasks.append(trimmed)
        newTask = ""
    }
}
