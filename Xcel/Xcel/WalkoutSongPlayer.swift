import MusicKit
import AVFoundation
import OSLog

// Plays a short snippet of the game's walkout song at the verdict reveal /
// series clinch moment, standing in for the stock crowd-roar/buzzer FX audio
// when the user picked a song for the day - a personalized payoff instead of
// a generic one. Falls back to the given SFX closure when no song was picked,
// or a preview couldn't be fetched (offline, region restriction, etc).
enum WalkoutSongPlayer {
    private static var player: AVPlayer?
    private static var previewCache: [String: URL] = [:]
    private static let snippetSeconds: TimeInterval = 8
    private static let log = Logger(subsystem: "com.paulefrim.Xcel", category: "WalkoutSongPlayer")

    // Kick off the catalog lookup as soon as the day starts judging, so the
    // preview URL is already cached by the time the verdict climax fires -
    // hides the network round-trip from the reveal moment.
    static func prefetch(appleMusicID: String) {
        guard !appleMusicID.isEmpty, previewCache[appleMusicID] == nil else { return }
        Task { _ = await previewURL(for: appleMusicID) }
    }

    static func play(appleMusicID: String, fallback: @escaping () -> Void) {
        guard !appleMusicID.isEmpty else { fallback(); return }
        Task {
            guard let url = await previewURL(for: appleMusicID) else {
                await MainActor.run { fallback() }
                return
            }
            await MainActor.run { playSnippet(url: url) }
        }
    }

    static func stop() {
        player?.pause()
        player = nil

        // Mirrors PreviewAudio's fix: an active audio session (even .ambient,
        // even paused) is what keeps iOS treating "audio" as in progress and
        // suppresses the auto-lock timer - deactivate once playback ends so
        // the screen goes back to sleeping normally.
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Walkout song audio session deactivation failed: \(String(describing: error))")
        }
    }

    private static func previewURL(for id: String) async -> URL? {
        if let cached = previewCache[id] { return cached }
        do {
            var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: [MusicItemID(id)])
            request.limit = 1
            let response = try await request.response()
            guard let url = response.items.first?.previewAssets?.first?.url else { return nil }
            previewCache[id] = url
            return url
        } catch {
            log.error("Walkout song preview lookup failed: \(String(describing: error))")
            return nil
        }
    }

    private static func playSnippet(url: URL) {
        stop()
        // .ambient matches FX's fallback SFX: respects the silent switch and
        // won't interrupt whatever else the user is playing.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            log.error("Walkout song audio session setup failed: \(String(describing: error))")
        }

        let newPlayer = AVPlayer(url: url)
        newPlayer.volume = 1.0
        player = newPlayer
        newPlayer.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + snippetSeconds) {
            if player === newPlayer { stop() }
        }
    }
}
