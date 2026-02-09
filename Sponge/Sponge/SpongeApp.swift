import SwiftUI
import SwiftData

@main
struct SpongeApp: App {
    @StateObject private var classViewModel = ClassViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(classViewModel)
                .modelContainer(PersistenceService.shared.modelContainer)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
    }
}
