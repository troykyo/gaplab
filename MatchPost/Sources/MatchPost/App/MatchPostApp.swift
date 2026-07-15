import SwiftUI
import AppKit

@main
struct MatchPostApp: App {
    @StateObject private var appState = AppState()

    init() {
        // When run as a bare SwiftPM executable (no .app bundle), macOS treats the
        // process as a background app: the window shows but never gets keyboard
        // focus. Promote it to a regular, activated app so text fields work.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
