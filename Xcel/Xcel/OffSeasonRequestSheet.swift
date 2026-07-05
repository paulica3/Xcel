import SwiftUI

// Mirrors ChallengeSheet's chrome (header/input/submit/loading) - the app's
// established shape for "write your case, AI reviews it."
struct OffSeasonRequestSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var description = ""
    @State private var days = OffSeasonService.defaultDurationDays
    @State private var reviewing = false
    @State private var verdict: OffSeasonApproval?

    private var accent: Color { settings.accent.color }
    private var ready: Bool {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace }).count >= 6 && !reviewing
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Up to 2 trips a year. Approved time off pauses every game in the window - no auto-loss, no reminders, and it never touches your streak or record.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.5))
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHERE ARE YOU HEADED?")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(2)
                                .foregroundStyle(accent)
                            Text("Destination and the plan - specific enough to tell it's a real trip, not just a day off.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.45))
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(alignment: .bottom, spacing: 8) {
                                TextField("e.g. Flying to Lisbon for a week with family, back the 14th…", text: $description, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                                    .lineLimit(4...10)
                                    .padding(12)
                                    .background(Color(white: 0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                MicButton(text: $description, accent: accent)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("HOW LONG")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(2)
                                .foregroundStyle(accent)
                            Stepper(value: $days, in: 1...OffSeasonService.maxDurationDays) {
                                Text("\(days) day\(days == 1 ? "" : "s")\(days == 7 ? " (about a week)" : "")")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(12)
                            .background(Color(white: 0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("Stays on this device - never sent anywhere outside the app.")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color(white: 0.4))

                        if let verdict {
                            HStack(spacing: 10) {
                                Image(systemName: verdict.approved ? "airplane.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(verdict.approved ? accent : Color(white: 0.5))
                                Text(verdict.verdict)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(24)
                }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        if reviewing { ProgressView().tint(.black).scaleEffect(0.9) }
                        Text(reviewing ? "Reviewing your request…" : (verdict?.approved == true ? "Done" : "Submit request"))
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ready || verdict?.approved == true ? .black : Color(white: 0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(ready || verdict?.approved == true ? accent : Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!ready && verdict?.approved != true)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.15), value: ready)
            }
        }
        .dismissKeyboardOnScroll()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("OFF SEASON")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Request time off")
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
    }

    private func submit() {
        // Already-approved state: the button becomes "Done", just dismiss.
        if verdict?.approved == true {
            dismiss()
            return
        }
        reviewing = true
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosenDays = days
        Task {
            let approval = await OffSeasonService.review(description: text, days: chosenDays)
            await MainActor.run {
                verdict = approval
                reviewing = false
                if approval.approved {
                    settings.offSeasonPeriods.append(OffSeasonPeriod(
                        id: UUID(),
                        requestedAt: Date(),
                        startDate: Date(),
                        durationDays: chosenDays,
                        description: text,
                        aiVerdict: approval.verdict
                    ))
                }
            }
        }
    }
}
