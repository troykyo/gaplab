import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PostingQueueView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = PostingQueueViewModel()
    @State private var expandedGroupID: NSManagedObjectID?

    var body: some View {
        VStack(spacing: 0) {
            queueHeader
            Divider()

            if vm.pendingGroups.isEmpty {
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
                let postWord = vm.pendingCount == 1 ? "post" : "posts"
                Text("\(vm.pendingCount) \(postWord) · \(vm.totalPhotoCount) photos · oldest first")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let next = vm.nextGroup {
                Button {
                    appState.pendingStagedGroup = next
                    appState.selectedTab = .addMatch
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

    // MARK: - Queue list

    private var queueList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(vm.pendingGroups.enumerated()), id: \.element.objectID) { index, group in
                    StagedGroupRow(
                        group: group,
                        position: index + 1,
                        isNext: index == 0,
                        isExpanded: expandedGroupID == group.objectID,
                        onToggleExpand: {
                            expandedGroupID = expandedGroupID == group.objectID ? nil : group.objectID
                        },
                        onMakeCover: { photo in vm.makeCover(photo, in: group) },
                        onMovePhoto: { photo, offset in vm.movePhoto(photo, by: offset, in: group) },
                        onSkip:     { vm.skip(group) },
                        onMoveEnd:  { vm.moveToEnd(group) },
                        onPostThis: {
                            appState.pendingStagedGroup = group
                            appState.selectedTab = .addMatch
                        }
                    )
                }
            }
            .padding()
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $vm.isDroppingFiles) { providers in
            vm.handleDrop(providers: providers)
        }
        .overlay(alignment: .bottom) {
            if vm.isDroppingFiles { dropOverlay }
        }
    }

    // MARK: - Empty state / drop zone

    private var emptyState: some View {
        ZStack {
            VStack(spacing: 16) {
                Image(systemName: vm.isDroppingFiles ? "tray.and.arrow.down.fill" : "tray")
                    .font(.system(size: 60))
                    .foregroundStyle(vm.isDroppingFiles ? Color.accentColor : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: vm.isDroppingFiles)
                Text(vm.isDroppingFiles ? "Drop to add to queue" : "Queue is empty")
                    .font(.title2.bold())
                Text("Drag match photos here — photos within 2 hours of each other become one carousel post.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onDrop(of: [.fileURL, .image], isTargeted: $vm.isDroppingFiles) { providers in
            vm.handleDrop(providers: providers)
        }
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .background(Color.accentColor.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 12)))
            .padding(8)
            .allowsHitTesting(false)
    }
}

// MARK: - Group Row

struct StagedGroupRow: View {
    let group: StagedPostGroup
    let position: Int
    let isNext: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onMakeCover: (StagedPhoto) -> Void
    let onMovePhoto: (StagedPhoto, Int) -> Void
    let onSkip: () -> Void
    let onMoveEnd: () -> Void
    let onPostThis: () -> Void

    private var sessionLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: group.sessionDate)
    }

    private var typeLabel: String {
        group.isCarousel
            ? "\(group.photoCount) photos · Carousel"
            : "1 photo"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                positionBadge

                // Thumbnail strip (up to 4 visible)
                thumbnailStrip

                // Text info
                VStack(alignment: .leading, spacing: 3) {
                    if isNext {
                        Text("NEXT TO POST")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    Text(sessionLabel)
                        .font(.subheadline)
                    HStack(spacing: 6) {
                        if group.isCarousel {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        Text(typeLabel)
                            .font(.caption)
                            .foregroundStyle(group.isCarousel ? .blue : .secondary)
                        homeAwayBadge
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
                    if group.isCarousel {
                        Button {
                            onToggleExpand()
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .buttonStyle(.borderless)
                        .help("Arrange photo order")
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

            // Expanded: arrange the carousel order (first photo = cover)
            if isExpanded {
                Divider().padding(.horizontal, 12)
                orderEditor
                    .padding(12)
            }
        }
        .background(isNext
            ? Color.accentColor.opacity(0.07)
            : Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isNext ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }

    // MARK: - Sub-views

    /// Home/away chip derived from photo GPS vs configured home grounds.
    @ViewBuilder
    private var homeAwayBadge: some View {
        switch group.isHomeMatch {
        case .some(true):
            chip("Home · \(group.homeVenue?.name ?? "")", color: .green,
                 icon: "house.fill")
        case .some(false):
            chip("Away", color: .orange, icon: "bus.fill")
        case .none:
            EmptyView()   // no GPS on any photo — user picks home/away in the form
        }
    }

    private func chip(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var positionBadge: some View {
        ZStack {
            Circle()
                .fill(isNext ? Color.accentColor : Color.secondary.opacity(0.2))
                .frame(width: 32, height: 32)
            Text("\(position)")
                .font(.caption.bold())
                .foregroundStyle(isNext ? .white : .primary)
        }
    }

    private var thumbnailStrip: some View {
        let photos = group.sortedPhotos
        let visible = Array(photos.prefix(4))
        let overflow = max(0, photos.count - 4)

        return HStack(spacing: 2) {
            ForEach(visible, id: \.objectID) { photo in
                thumbnail(for: photo, isCover: photo.phAssetLocalIdentifier == (group.coverAssetID ?? photos.first?.phAssetLocalIdentifier))
                    .frame(width: photos.count > 1 ? 44 : 64,
                           height: 64)
            }
            if overflow > 0 {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 32, height: 64)
                    Text("+\(overflow)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func thumbnail(for photo: StagedPhoto, isCover: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = photo.thumbnailData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
            }
            if isCover {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .padding(3)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
                    .padding(3)
            }
        }
    }

    private var orderEditor: some View {
        let ordered = group.sortedPhotos
        return VStack(alignment: .leading, spacing: 8) {
            Text("Arrange the post order — the first photo is the cover Instagram shows")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(ordered.enumerated()), id: \.element.objectID) { index, photo in
                        VStack(spacing: 6) {
                            ZStack(alignment: .topLeading) {
                                if let data = photo.thumbnailData, let img = NSImage(data: data) {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 84, height: 84)
                                        .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                                }
                                // Position number; #1 is the cover
                                Text(index == 0 ? "★ 1" : "\(index + 1)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(index == 0 ? Color.yellow.opacity(0.85) : Color.black.opacity(0.55))
                                    .clipShape(Capsule())
                                    .padding(4)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(index == 0 ? Color.accentColor : .clear, lineWidth: 2)
                            )

                            HStack(spacing: 6) {
                                Button { onMovePhoto(photo, -1) } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .disabled(index == 0)
                                .help("Move earlier")

                                Button { onMakeCover(photo) } label: {
                                    Image(systemName: "star")
                                }
                                .disabled(index == 0)
                                .help("Make cover (move to front)")

                                Button { onMovePhoto(photo, +1) } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(index == ordered.count - 1)
                                .help("Move later")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
