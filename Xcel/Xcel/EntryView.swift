import SwiftUI
import SwiftData

struct EntryView: View {
    let game: Game
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var goToSubmit = false

    var isMorning: Bool { game.morningIntention.isEmpty }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                navBar

                Text("GAME \(game.gameNumber) · \(isMorning ? "MORNING" : "EVENING")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(white: 0.32))
                    .kerning(2.5)
                    .padding(.horizontal, 24)

                Text(isMorning ? "What's your intention today?" : "How did Game \(game.gameNumber) go?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                if !isMorning && !game.morningIntention.isEmpty {
                    morningContext
                }

                TextEditor(text: $text)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)

                submitButton
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $goToSubmit) {
            SubmitView(game: game, entry: text, onComplete: onComplete)
        }
    }

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
        .padding(.bottom, 28)
    }

    private var morningContext: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This morning you said:")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.32))
            Text(game.morningIntention)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.48))
                .italic()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private var submitButton: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ready = !trimmed.isEmpty

        return Button {
            if isMorning {
                game.morningIntention = trimmed
                try? modelContext.save()
                onComplete()
            } else {
                goToSubmit = true
            }
        } label: {
            Text(isMorning ? "Lock in" : "Take it to the judge")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ready ? .black : Color(white: 0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(ready ? Color.neonGreen : Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!ready)
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
        .animation(.easeInOut(duration: 0.15), value: ready)
    }
}
