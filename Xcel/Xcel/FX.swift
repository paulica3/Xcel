import UIKit
import AudioToolbox

// Haptics + sound for the verdict moment.
// TODO: swap the system-sound IDs for bundled crowd-noise / buzzer assets.
enum FX {
    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1025)   // placeholder "up" chime → crowd noise later
    }

    static func loss() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        AudioServicesPlaySystemSound(1053)   // placeholder buzz → buzzer later
    }

    static func comeback() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        // A quick one-two for drama.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        AudioServicesPlaySystemSound(1025)
    }
}
