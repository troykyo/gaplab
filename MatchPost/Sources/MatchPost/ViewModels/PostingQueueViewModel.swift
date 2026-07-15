import SwiftUI
import CoreData
import Photos
import UniformTypeIdentifiers

@MainActor
final class PostingQueueViewModel: ObservableObject {
    @Published var pendingGroups: [StagedPostGroup] = []
    @Published var isLoadingImage = false
    @Published var isDroppingFiles = false
    @Published var error: AppError?

    private var context: NSManagedObjectContext?
    var player: Player?

    func load(context: NSManagedObjectContext, player: Player?) {
        self.context = context
        self.player  = player
        refresh()
    }

    func refresh() {
        guard let ctx = context, let player else { pendingGroups = []; return }
        let request = StagedPostGroup.pendingRequest(for: player)
        pendingGroups = (try? ctx.fetch(request)) ?? []
    }

    var nextGroup: StagedPostGroup? { pendingGroups.first }
    var pendingCount: Int { pendingGroups.count }
    var totalPhotoCount: Int { pendingGroups.reduce(0) { $0 + $1.photoCount } }

    // MARK: - Photo ordering within a match post

    /// Move a photo one step left (-1) or right (+1) in the carousel order.
    func movePhoto(_ photo: StagedPhoto, by offset: Int, in group: StagedPostGroup) {
        var ordered = group.sortedPhotos
        guard let index = ordered.firstIndex(of: photo) else { return }
        let target = index + offset
        guard ordered.indices.contains(target) else { return }
        ordered.swapAt(index, target)
        group.applyOrder(ordered)
        try? context?.save()
        objectWillChange.send()
    }

    /// Move a photo to the front — it becomes the cover (first image in the post).
    func makeCover(_ photo: StagedPhoto, in group: StagedPostGroup) {
        var ordered = group.sortedPhotos
        guard let index = ordered.firstIndex(of: photo) else { return }
        ordered.remove(at: index)
        ordered.insert(photo, at: 0)
        group.applyOrder(ordered)
        try? context?.save()
        objectWillChange.send()
    }

    // MARK: - Queue management

    func skip(_ group: StagedPostGroup) {
        group.status = StagedPhotoStatus.skipped.rawValue
        for photo in group.sortedPhotos { photo.status = StagedPhotoStatus.skipped.rawValue }
        try? context?.save()
        refresh()
    }

    func moveToEnd(_ group: StagedPostGroup) {
        guard let last = pendingGroups.last else { return }
        // Push the session date past the last group so it sorts last
        group.sessionDate = (last.sessionDate + 1)
        try? context?.save()
        refresh()
    }

    // MARK: - Full-res image loading

    func loadFullResImage(for staged: StagedPhoto) async throws -> Data {
        isLoadingImage = true
        defer { isLoadingImage = false }

        // File-imported photos already carry their data
        if let stored = staged.imageData { return stored }

        let id = staged.phAssetLocalIdentifier
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            throw AppError.noImageSelected
        }
        return try await withCheckedThrowingContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.version = .current
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.isSynchronous = false
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                if let data { cont.resume(returning: data) }
                else        { cont.resume(throwing: AppError.noImageSelected) }
            }
        }
    }

    // MARK: - Mark posted

    func markPosted(_ group: StagedPostGroup, as matchPhoto: MatchPhoto) {
        group.status   = StagedPhotoStatus.posted.rawValue
        group.postedAs = matchPhoto
        matchPhoto.stagedGroup = group
        for photo in group.sortedPhotos {
            photo.status = StagedPhotoStatus.posted.rawValue
        }
        try? context?.save()
        refresh()
    }

    // MARK: - Drag-and-drop import

    /// Accept dropped image files from Finder, group them by 2-hour window, and stage them.
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let ctx = context, let player else { return false }
        Task {
            var candidates: [StagingCandidate] = []
            for provider in providers {
                if let c = await loadCandidate(from: provider) { candidates.append(c) }
            }
            guard !candidates.isEmpty else { return }

            let groups = PhotoGrouper.group(candidates)
            for photoGroup in groups {
                _ = StagedPostGroup.create(from: photoGroup, player: player, context: ctx)
            }
            try? ctx.save()
            refresh()
        }
        return true
    }

    private func loadCandidate(from provider: NSItemProvider) async -> StagingCandidate? {
        // Try file URL first (drag from Finder)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return await withCheckedContinuation { cont in
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = item as? URL, let data = try? Data(contentsOf: url) else {
                        cont.resume(returning: nil); return
                    }
                    let exif      = EXIFReader.extract(from: data)
                    let thumbnail = NSImage(data: data).flatMap { ImageResizer.makeThumbnail($0) }
                    cont.resume(returning: StagingCandidate(
                        id:            UUID().uuidString,
                        exifDate:      exif.date,
                        thumbnailData: thumbnail,
                        imageData:     data,
                        latitude:      exif.coordinate?.latitude  ?? 0,
                        longitude:     exif.coordinate?.longitude ?? 0
                    ))
                }
            }
        }
        // Fall back to raw image data (drag from Photos or browser)
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await withCheckedContinuation { cont in
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    guard let data else { cont.resume(returning: nil); return }
                    let exif      = EXIFReader.extract(from: data)
                    let thumbnail = NSImage(data: data).flatMap { ImageResizer.makeThumbnail($0) }
                    cont.resume(returning: StagingCandidate(
                        id:            UUID().uuidString,
                        exifDate:      exif.date,
                        thumbnailData: thumbnail,
                        imageData:     data,
                        latitude:      exif.coordinate?.latitude  ?? 0,
                        longitude:     exif.coordinate?.longitude ?? 0
                    ))
                }
            }
        }
        return nil
    }
}
