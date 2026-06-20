import SwiftUI
import SwiftData

@main
struct XcelApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(Color.neonGreen)
        }
        .modelContainer(for: Series.self)
    }
}
