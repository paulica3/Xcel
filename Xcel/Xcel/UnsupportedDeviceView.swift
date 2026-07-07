import SwiftUI

// Hard gate for hardware that will never run Apple Intelligence (pre-A17 Pro
// devices). Distinct from JudgeService.practiceJudgeNote's "not enabled" /
// "still downloading" cases, which are recoverable and don't block entry -
// this only fires for SystemLanguageModel.Availability.UnavailableReason
// .deviceNotEligible, which no Settings toggle or wait can fix.
struct UnsupportedDeviceView: View {
    @Environment(AppSettings.self) private var settings
    private var accent: Color { settings.accent.color }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "iphone.slash")
                    .font(.system(size: 64))
                    .foregroundStyle(accent)
                VStack(spacing: 12) {
                    Text("DEVICE NOT SUPPORTED")
                        .font(.system(size: 12, weight: .bold))
                        .kerning(2.5)
                        .foregroundStyle(accent)
                    Text("Xcel needs Apple Intelligence")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("The Judge runs entirely on-device with Apple Intelligence, which needs an iPhone 15 Pro, iPhone 16 series, or newer. This device can't run it, so Xcel isn't available here.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(white: 0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                Spacer()
            }
        }
    }
}
