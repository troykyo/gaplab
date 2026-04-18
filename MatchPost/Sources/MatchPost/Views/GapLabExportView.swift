import SwiftUI

struct GapLabExportView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = PostViewModel()
    @State private var showPreview = false
    @State private var previewHTML = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe").font(.system(size: 50)).foregroundStyle(.blue)
            Text("GAP Lab Profile").font(.title.bold())
            Text("Export this player's career timeline as a web page for thegaplab.net")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let player = appState.activePlayer {
                playerSummary(player)

                if vm.isExporting {
                    ProgressView("Generating profile…")
                } else if let url = vm.exportedURL {
                    VStack(spacing: 10) {
                        Label("Exported to \(url.lastPathComponent)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(url.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                .buttonStyle(.bordered)
                            Button("Preview in Browser") { NSWorkspace.shared.open(url) }
                                .buttonStyle(.bordered)
                        }
                        Divider()
                        Text("Commit and push the players/ directory to publish to thegaplab.net.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Button("Generate & Export Profile") {
                        vm.exportProfile(player: player)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let err = vm.exportError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            } else {
                Text("Set up a player profile first.").foregroundStyle(.secondary)
                Button("Go to Profile") { appState.selectedTab = .profile }
                    .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playerSummary(_ player: Player) -> some View {
        VStack(spacing: 6) {
            Text(player.name).font(.headline)
            Text("\(player.position) · \(player.currentTeamName ?? "") · \(player.sortedCareerEntries.count) clubs")
                .font(.subheadline).foregroundStyle(.secondary)
            let photos = (player.matchPhotos as? Set<MatchPhoto>)?.count ?? 0
            Text("\(photos) photos")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
