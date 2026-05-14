import SwiftUI
import CoreData
import Photos

@MainActor
final class PostingQueueViewModel: ObservableObject {
    @Published var pendingPhotos: [StagedPhoto] = []
    @Published var isLoadingImage = false
    @Published var error: AppError?

    private var context: NSManagedObjectContext?
    var player: Player?

    func load(context: NSManagedObjectContext, player: Player?) {
        self.context = context
        self.player  = player
        refresh()
    }

    func refresh() {
        guard let ctx = context, let player else { pendingPhotos = []; return }
        let request = StagedPhoto.pendingRequest(for: player)
        pendingPhotos = (try? ctx.fetch(request)) ?? []
    }

    var nextPhoto: StagedPhoto? { pendingPhotos.first }

    var pendingCount: Int { pendingPhotos.count }

    // MARK: - Queue management

    func skip(_ staged: StagedPhoto) {
        staged.status = StagedPhotoStatus.skipped.rawValue
        try? context?.save()
        refresh()
    }

    func moveToEnd(_ staged: StagedPhoto) {
        guard let last = pendingPhotos.last else { return }
        staged.queuePosition = last.queuePosition + 1
        try? context?.save()
        refresh()
    }

    /// Load full-resolution image data for the given staged photo via PHImageManager.
    func loadFullResImage(for staged: StagedPhoto) async throws -> Data {
        isLoadingImage = true
        defer { isLoadingImage = false }

        let id = staged.phAssetLocalIdentifier
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            throw AppError.noImageSelected
        }

        return try await withCheckedThrowingContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.version        = .current
            opts.deliveryMode   = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.isSynchronous  = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset, options: opts
            ) { data, _, _, info in
                if let data { cont.resume(returning: data) }
                else {
                    let msg = (info?[PHImageErrorKey] as? Error)?.localizedDescription ?? "Could not load image"
                    cont.resume(throwing: AppError.noImageSelected)
                    _ = msg
                }
            }
        }
    }

    /// Mark a staged photo as posted and link it to the resulting MatchPhoto.
    func markPosted(_ staged: StagedPhoto, as matchPhoto: MatchPhoto) {
        staged.status   = StagedPhotoStatus.posted.rawValue
        staged.postedAs = matchPhoto
        matchPhoto.stagedFrom = staged
        try? context?.save()
        refresh()
    }
}
