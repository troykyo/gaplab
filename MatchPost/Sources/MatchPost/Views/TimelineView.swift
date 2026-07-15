import SwiftUI
import CoreData

struct TimelineView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = TimelineViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let player = appState.activePlayer {
                playerHeader(player)
            }

            if vm.matchesByYear.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                        ForEach(vm.matchesByYear, id: \.year) { group in
                            Section {
                                ForEach(group.matches, id: \.objectID) { match in
                                    MatchRowView(match: match)
                                }
                            } header: {
                                Text("\(group.year)")
                                    .font(.title2.bold())
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Career Timeline")
        .onAppear { vm.load(context: appState.viewContext) }
    }

    private func playerHeader(_ player: Player) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text(player.name).font(.title.bold())
                Text("\(player.position) · \(player.currentTeamName ?? "") · \(vm.totalMatches) matches · \(vm.totalWins) wins")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No matches yet")
                .font(.title2.bold())
            Text("Tap Add Match to record your first game.")
                .foregroundStyle(.secondary)
            Button("Add First Match") {
                appState.selectedTab = .addMatch
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MatchRowView: View {
    let match: MatchRecord

    private var resultColor: Color {
        switch match.result {
        case .win:  return .green
        case .draw: return .orange
        case .loss: return .red
        }
    }

    private var resultLabel: String {
        switch match.result {
        case .win:  return "W"
        case .draw: return "D"
        case .loss: return "L"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Result badge
            Text(resultLabel)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(resultColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // Photo thumbnail
            if let photo = match.sortedPhotos.first, let thumb = photo.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("vs \(match.opponentName)").font(.headline)
                Text(match.scoreDisplay).font(.subheadline.bold()).foregroundStyle(resultColor)
                if let comp = match.competition {
                    Text(comp).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(match.matchDate, style: .date).font(.caption).foregroundStyle(.secondary)
                if match.sortedPhotos.first?.hasBeenPosted == true {
                    Label("Posted", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(12)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
