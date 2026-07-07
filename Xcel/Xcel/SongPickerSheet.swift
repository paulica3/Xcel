import SwiftUI
import MusicKit
import OSLog

struct SongSelection {
    let title: String
    let artist: String
    let appleMusicID: String
    // Handed over so the entry screen can show artwork/offer a preview
    // without a second catalog lookup right after picking.
    let artwork: Artwork?
    let previewURL: URL?
}

struct SongPickerSheet: View {
    let accent: Color
    let onPick: (SongSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Song] = []
    @State private var initialTracks: [Song] = []
    @State private var initialLabel = "TRENDING NOW"
    @State private var authStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    @State private var searching = false
    @State private var loadingInitial = false
    @State private var errorMessage: String?

    private static let log = Logger(subsystem: "com.paulefrim.Xcel", category: "SongPicker")

    // What the list shows: live search results once the user has typed
    // something, otherwise a curated starting point so the sheet is never
    // empty on open.
    private var displayedTracks: [Song] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? initialTracks : results
    }
    private var sectionLabel: String {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? initialLabel : "RESULTS"
    }

    var body: some View {
        ZStack {
            Color.arenaBlack.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                switch authStatus {
                case .authorized: searchBody
                case .notDetermined: requestPrompt
                default: deniedPrompt
                }
            }
        }
        .task {
            if authStatus == .notDetermined {
                authStatus = await MusicAuthorization.request()
            }
            if authStatus == .authorized {
                await loadInitialContent()
            }
        }
        .onDisappear { PreviewAudio.shared.stop() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("WALKOUT SONG")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Text("Pick today's track")
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

    private var searchBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search Apple Music…", text: $query)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(Color(white: 0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onSubmit { Task { await search() } }
                Button {
                    Task { await search() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 50, height: 50)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || searching)
            }
            .padding(.horizontal, 24)

            Text("No Apple Music subscription needed")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.4))
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            if !displayedTracks.isEmpty || searching || loadingInitial {
                Text(sectionLabel)
                    .font(.system(size: 10, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Color(white: 0.4))
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
            }

            if searching || loadingInitial {
                HStack {
                    Spacer()
                    ProgressView().tint(accent)
                    Spacer()
                }
                .padding(.top, 20)
            } else if displayedTracks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(displayedTracks, id: \.id) { song in
                            songRow(song)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 28))
                .foregroundStyle(Color(white: 0.3))
            Text(query.trimmingCharacters(in: .whitespaces).isEmpty ? "Couldn't load Apple Music right now." : "No matches for \"\(query)\".")
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.45))
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 2)
            }
            Button("Skip for today") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.top, 10)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 30)
    }

    private func songRow(_ song: Song) -> some View {
        let isPreviewing = PreviewAudio.shared.playingID == song.id.rawValue
        let hasPreview = song.previewAssets?.first?.url != nil

        return HStack(spacing: 12) {
            Button {
                if hasPreview { togglePreview(song) }
            } label: {
                ZStack {
                    if let artwork = song.artwork {
                        ArtworkImage(artwork, width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.15))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "music.note").foregroundStyle(Color(white: 0.4)))
                    }
                    if hasPreview {
                        Color.black.opacity(isPreviewing ? 0.35 : 0)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Image(systemName: isPreviewing ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(isPreviewing ? 1 : 0.85)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasPreview)

            Button {
                onPick(SongSelection(title: song.title, artist: song.artistName, appleMusicID: song.id.rawValue,
                                      artwork: song.artwork, previewURL: song.previewAssets?.first?.url))
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        Text(song.artistName).font(.system(size: 13)).foregroundStyle(Color(white: 0.5)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.35))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(white: 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func togglePreview(_ song: Song) {
        guard let url = song.previewAssets?.first?.url else { return }
        PreviewAudio.shared.toggle(id: song.id.rawValue, url: url)
    }

    private var requestPrompt: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 32))
                .foregroundStyle(accent)
            Text("Requesting Apple Music access…")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var deniedPrompt: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundStyle(Color(white: 0.4))
            Text("Apple Music access is off. Enable it in Settings to pick a walkout song, or just skip this - it's optional.")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            Button("Skip for today") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // Always show *something* on open: try the user's own recently played
    // tracks first (needs an active Apple Music subscription + history),
    // fall back to the public catalog's top charts (works for anyone with
    // catalog access, no subscription required) so the sheet is never blank.
    private func loadInitialContent() async {
        loadingInitial = true
        defer { loadingInitial = false }

        do {
            var recent = MusicRecentlyPlayedRequest<Song>()
            recent.limit = 20
            let response = try await recent.response()
            if !response.items.isEmpty {
                initialTracks = await Self.refreshedFromCatalog(Array(response.items))
                initialLabel = "RECENTLY PLAYED"
                errorMessage = nil
                return
            }
        } catch {
            Self.log.error("Recently played fetch failed: \(String(describing: error))")
        }

        do {
            var charts = MusicCatalogChartsRequest(genre: nil, kinds: [.mostPlayed], types: [Song.self])
            charts.limit = 20
            let response = try await charts.response()
            if let chart = response.songCharts.first {
                initialTracks = Array(chart.items)
                initialLabel = "TRENDING NOW"
                errorMessage = nil
            }
        } catch {
            Self.log.error("Catalog charts fetch failed: \(String(describing: error))")
            errorMessage = Self.describeFailure(error)
        }
    }

    // MusicRecentlyPlayedRequest returns items from the listening-history
    // endpoint, which doesn't reliably populate previewAssets the way a
    // catalog search/charts response does - that's why "recently played"
    // rows looked unclickable. Unconditionally re-fetch every one of them
    // straight from the catalog by ID (same lookup SongArtworkThumbnail
    // already does) and swap in those fuller objects, in original order -
    // a partial/conditional backfill still left some rows with whatever
    // sparse object the history endpoint handed back.
    private static func refreshedFromCatalog(_ songs: [Song]) async -> [Song] {
        guard !songs.isEmpty else { return songs }
        do {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: songs.map(\.id))
            let response = try await request.response()
            let byID = Dictionary(uniqueKeysWithValues: response.items.map { ($0.id, $0) })
            Self.log.info("Recently played catalog refresh: \(songs.count) requested, \(byID.count) resolved")
            return songs.map { byID[$0.id] ?? $0 }
        } catch {
            Self.log.error("Recently played catalog refresh failed: \(String(describing: error))")
            return songs
        }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        searching = true
        defer { searching = false }
        do {
            var request = MusicCatalogSearchRequest(term: trimmed, types: [Song.self])
            request.limit = 15
            let response = try await request.response()
            results = Array(response.songs)
            errorMessage = nil
        } catch {
            Self.log.error("Catalog search failed for '\(trimmed)': \(String(describing: error))")
            results = []
            errorMessage = Self.describeFailure(error)
        }
    }

    // Surface *something* readable instead of a raw Swift error dump - this
    // is what you'll see in the sheet itself if Apple Music access is being
    // rejected server-side (e.g. entitlement/region issues), without needing
    // to be tethered to Xcode's console to diagnose it.
    private static func describeFailure(_ error: Error) -> String {
        let text = String(describing: error)
        if text.contains("developerToken") { return "Apple Music access isn't available on this build yet." }
        if text.contains("permissionDenied") || text.contains("privacyAcknowledgementRequired") { return "Apple Music access needs to be re-granted in Settings." }
        return "Apple Music couldn't be reached. Check your connection and try again."
    }
}
