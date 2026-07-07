import SwiftUI
import MusicKit

// Best-effort artwork lookup by Apple Music ID, also tappable to hear a
// preview. Game only persists title/artist/ID for a walkout song (not the
// Artwork/preview URL, which only exist on a live MusicKit Song) - stats
// views showing a song from history need to re-fetch it by ID, same as
// EntryView does for a previously-picked song. A failed/slow lookup just
// falls back to a plain, non-interactive music-note tile.
struct SongArtworkThumbnail: View {
    let appleMusicID: String
    var size: CGFloat = 44

    @State private var artwork: Artwork?
    @State private var previewURL: URL?

    private var isPreviewing: Bool { PreviewAudio.shared.playingID == appleMusicID }

    var body: some View {
        Button {
            guard let previewURL else { return }
            PreviewAudio.shared.toggle(id: appleMusicID, url: previewURL)
        } label: {
            ZStack {
                if let artwork {
                    ArtworkImage(artwork, width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.14))
                } else {
                    RoundedRectangle(cornerRadius: size * 0.14)
                        .fill(Color(white: 0.15))
                        .frame(width: size, height: size)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundStyle(Color(white: 0.4))
                        )
                }
                if previewURL != nil {
                    Color.black.opacity(isPreviewing ? 0.35 : 0)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.14))
                    Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(isPreviewing ? 1 : 0.85)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(previewURL == nil)
        .task(id: appleMusicID) {
            artwork = nil
            previewURL = nil
            guard !appleMusicID.isEmpty else { return }
            do {
                var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: [MusicItemID(appleMusicID)])
                request.limit = 1
                let response = try await request.response()
                artwork = response.items.first?.artwork
                previewURL = response.items.first?.previewAssets?.first?.url
            } catch {
                // No artwork/preview is a fine degraded state - title/artist text still shows.
            }
        }
    }
}
