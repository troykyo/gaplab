import SwiftUI
import AppKit

struct PostingQueueView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = PostingQueueViewModel()

    var body: some View {
        VStack(spacing: 0) {
            queueHeader
            Divider()

            if vm.pendingPhotos.isEmpty {
                emptyState
            } else {
                queueList
            }
        }
        .navigationTitle("Posting Queue")
        .onAppear { vm.load(context: appState.viewContext, player: appState.activePlayer) }
    }

    // MARK: - Header

    private var queueHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Posting Queue")
                    .font(.title2.bold())
                Text("\(vm.pendingCount) photo\(vm.pendingCount == 1 ? "" : "s") waiting · oldest posted first")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let next = vm.nextPhoto {
                Button {
                    appState.selectedTab = .addMatch
                    // Signal AddMatchView to start from this staged photo
                    appState.pendingStagedPhoto = next
                } label: {
                    Label("Post Next", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isLoadingImage)
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Queue list (oldest first)

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(vm.pendingPhotos.enumerated()), id: \.element.objectID) { index, staged in
                    StagedPhotoRow(
                        staged: staged,
                        position: index + 1,
                        isNext: index == 0,
                        onSkip:     { vm.skip(staged) },
                        onMoveEnd:  { vm.moveToEnd(staged) },
                        onPostThis: {
                            appState.pendingStagedPhoto = staged
                            appState.selectedTab = .addMatch
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Queue is empty")
                .font(.title2.bold())
            Text("Stage photos from Apple Photos using the MatchPost extension (File → Create → MatchPost), or add them one at a time from the Add Match tab.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

struct StagedPhotoRow: View {
    let staged: StagedPhoto
    let position: Int
    let isNext: Bool
    let onSkip: () -> Void
    let onMoveEnd: () -> Void
    let onPostThis: () -> Void

    private var dateLabel: String {
        guard let d = staged.exifDate else { return "No date — sorted to end" }
        return d.formatted(date: .long, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Position badge
            ZStack {
                Circle()
                    .fill(isNext ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                Text("\(position)")
                    .font(.caption.bold())
                    .foregroundStyle(isNext ? .white : .primary)
            }

            // Thumbnail
            if let data = staged.thumbnailData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                if isNext {
                    Text("NEXT TO POST")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                }
                Text(dateLabel)
                    .font(.subheadline)
                if staged.exifDate == nil {
                    Text("Will post after all dated photos")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if isNext {
                    Button("Post Now", action: onPostThis)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Menu {
                    Button("Move to End of Queue", action: onMoveEnd)
                    Divider()
                    Button("Skip", role: .destructive, action: onSkip)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }
        }
        .padding(12)
        .background(isNext
            ? Color.accentColor.opacity(0.07)
            : Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isNext ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }
}
