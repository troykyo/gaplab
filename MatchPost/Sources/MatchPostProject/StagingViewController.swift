import AppKit
import Photos
import SwiftUI
import MatchPostCore

/// The view controller shown inside Photos.app when the extension activates.
/// Displays the staged photos in chronological order and lets the user confirm.
final class StagingViewController: NSViewController {
    private let stagedPhotos: [StagedPhoto]
    private let extensionContext: PHProjectExtensionContext
    private let context: NSManagedObjectContext

    init(stagedPhotos: [StagedPhoto],
         extensionContext: PHProjectExtensionContext,
         context: NSManagedObjectContext) {
        self.stagedPhotos    = stagedPhotos
        self.extensionContext = extensionContext
        self.context          = context
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let swiftUIView = StagingView(
            stagedPhotos: stagedPhotos,
            onConfirm:    { [weak self] in self?.confirmAndOpen() },
            onCancel:     { [weak self] in self?.cancel() }
        )
        let hosting = NSHostingView(rootView: swiftUIView)
        hosting.frame = CGRect(x: 0, y: 0, width: 600, height: 500)
        view = hosting
    }

    private func confirmAndOpen() {
        // Open MatchPost app — it will read the newly staged photos from shared CoreData
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.troykyo.matchpost") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
        }
        extensionContext.completeProjectEditing(updatedProjectInfo: PHProjectInfo())
    }

    private func cancel() {
        // Remove staged photos that were just created
        stagedPhotos.forEach { context.delete($0) }
        try? context.save()
        extensionContext.cancelProjectEditing()
    }
}

// MARK: - SwiftUI staging view

struct StagingView: View {
    let stagedPhotos: [StagedPhoto]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Stage Photos for MatchPost")
                        .font(.title2.bold())
                    Text("\(stagedPhotos.count) photo\(stagedPhotos.count == 1 ? "" : "s") · sorted oldest first · will post in this order")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            // Photo list — oldest first
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(stagedPhotos.enumerated()), id: \.element.objectID) { index, staged in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 24)
                                .foregroundStyle(.secondary)

                            if let data = staged.thumbnailData, let img = NSImage(data: data) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 56, height: 56)
                            }

                            VStack(alignment: .leading) {
                                if let date = staged.exifDate {
                                    Text(date.formatted(date: .long, time: .shortened))
                                        .font(.subheadline)
                                } else {
                                    Text("No date — will post last")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                Spacer()
                Text("Oldest photo posts first in MatchPost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Stage \(stagedPhotos.count) Photo\(stagedPhotos.count == 1 ? "" : "s") →", action: onConfirm)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)
        }
        .frame(width: 600, height: 500)
    }
}
