import UIKit
import AVFoundation
import AudioToolbox

// Haptics + sound for the verdict moment.
//
// Drop royalty-free audio into the app bundle named "win", "loss", and
// "comeback" (any of .caf/.wav/.mp3/.m4a/.aiff) and they play automatically.
// Until then, each falls back to a placeholder iOS system sound so the moment
// is never silent.
//
//   win      → arena crowd roar / cheer
//   loss     → game buzzer / horn
//   comeback → bigger, building crowd roar
enum FX {
    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        play("win", fallbackSystemSound: 1025)
    }

    static func loss() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        play("loss", fallbackSystemSound: 1053)
    }

    static func comeback() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        // A quick one-two for drama.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        play("comeback", fallbackSystemSound: 1025)
    }

    // MARK: - Playback

    private static let extensions = ["caf", "wav", "mp3", "m4a", "aiff"]
    private static var players: [String: AVAudioPlayer] = [:]
    private static var sessionReady = false

    private static func play(_ name: String, fallbackSystemSound: SystemSoundID) {
        guard let player = player(for: name) else {
            AudioServicesPlaySystemSound(fallbackSystemSound)
            return
        }
        configureSessionIfNeeded()
        player.currentTime = 0
        player.play()
    }

    private static func player(for name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let url = extensions
            .lazy
            .compactMap({ Bundle.main.url(forResource: name, withExtension: $0) })
            .first,
            let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }
        player.prepareToPlay()
        players[name] = player
        return player
    }

    // .ambient respects the silent switch and won't interrupt the user's music.
    private static func configureSessionIfNeeded() {
        guard !sessionReady else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionReady = true
    }
}
