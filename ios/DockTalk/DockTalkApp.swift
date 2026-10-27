import SwiftUI
import SwiftData

@main
struct DockTalkApp: App {
    var body: some Scene {
        WindowGroup {
            BoardView()
                .tint(Palette.signal)
        }
        .modelContainer(for: Visit.self)
    }
}
