import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TimelineView()
                .tabItem { Label(AppTab.timeline.rawValue, systemImage: AppTab.timeline.systemImage) }
                .tag(AppTab.timeline)

            PostingQueueView()
                .tabItem { Label(AppTab.queue.rawValue, systemImage: AppTab.queue.systemImage) }
                .tag(AppTab.queue)

            AddMatchView()
                .tabItem { Label(AppTab.addMatch.rawValue, systemImage: AppTab.addMatch.systemImage) }
                .tag(AppTab.addMatch)

            PlayerProfileView()
                .tabItem { Label(AppTab.profile.rawValue, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)

            GapLabExportView()
                .tabItem { Label(AppTab.gaplab.rawValue, systemImage: AppTab.gaplab.systemImage) }
                .tag(AppTab.gaplab)

            SettingsView()
                .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
        }
        .alert("Error", isPresented: Binding(
            get: { appState.error != nil },
            set: { if !$0 { appState.clearError() } }
        )) {
            Button("OK") { appState.clearError() }
        } message: {
            Text(appState.error?.errorDescription ?? "")
        }
    }
}
