import SwiftUI
import SwiftData

@main
struct XcelApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(settings.accent.color)
                .environment(settings)
        }
        .modelContainer(for: Series.self)
    }
}
