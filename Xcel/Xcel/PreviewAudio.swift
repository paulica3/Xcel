import Foundation
import AVFoundation
import OSLog

// A single, app-wide preview player. Song previews show up in three separate
// places (SongPickerSheet's list, EntryView's walkout-song row, and
// SongArtworkThumbnail used in SeriesView/InsightsView) - without a shared
// mutex, starting a preview in one place didn't stop a preview already
// playing in another, so two 30-second clips could overlap. Routing every
// preview tap through this one instance guarantees only one ever plays.
@Observable
final class PreviewAudio {
    static let shared = PreviewAudio()

    private(set) var playingID: String?
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?

    private static let log = Logger(subsystem: "com.paulefrim.Xcel", category: "PreviewAudio")

    private init() {}

    func toggle(id: String, url: URL) {
        if playingID == id {
            stop()
        } else {
            play(id: id, url: url)
        }
    }

    func play(id: String, url: URL) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            Self.log.error("Preview audio session setup failed: \(String(describing: error))")
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.volume = 1.0
        player = newPlayer
        playingID = id

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self, self.playingID == id else { return }
            self.stop()
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { note in
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Self.log.error("Preview playback failed: \(String(describing: error))")
        }
        newPlayer.play()
    }

    func stop() {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }
        endObserver = nil
        failObserver = nil
        player?.pause()
        player = nil
        playingID = nil

        // An active .playback session is what tells iOS "audio is playing" and
        // suppresses the auto-lock timer - leaving it active after pausing is
        // why the screen stopped sleeping any time a preview had been played.
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.log.error("Preview audio session deactivation failed: \(String(describing: error))")
        }
    }
}
