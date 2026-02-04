import SwiftUI

@main
struct SpongeApp: App {
    @StateObject private var classViewModel = ClassViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(classViewModel)
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 600)
        #endif
    }
}
