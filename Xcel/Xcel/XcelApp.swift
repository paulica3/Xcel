import SwiftUI
import SwiftData

@main
struct XcelApp: App {
    @State private var settings = AppSettings()
    @State private var sync: any SyncService = SupabaseSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(settings.accent.color)
                .environment(settings)
                .environment(\.syncService, sync)
        }
        .modelContainer(for: Series.self)
    }
}
