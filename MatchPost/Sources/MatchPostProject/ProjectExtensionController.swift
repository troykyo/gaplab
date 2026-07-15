import Photos
import PhotosUI
import CoreData
import AppKit
import MatchPostCore

/// Photos Project Extension principal class.
/// Registered in Info.plist under NSExtension → NSExtensionPrincipalClass.
///
/// Appears in Photos.app under: File → Create → MatchPost Career Post
/// The user selects any number of match photos in their library before invoking this.
@objc(ProjectExtensionController)
final class ProjectExtensionController: PHProjectExtensionController {

    private var currentProject: PHProject?
    private var hostingController: NSViewController?

    // MARK: - PHProjectExtensionController

    override func beginProject(
        with projectInfo: PHProjectInfo,
        using extensionContext: PHProjectExtensionContext
    ) {
        currentProject = extensionContext.project

        let assets = fetchAssets(from: projectInfo)
        let context = PersistenceController.shared.container.viewContext
        let player  = loadPlayer(context: context)

        let stagedItems = stage(assets: assets, player: player, context: context)

        DispatchQueue.main.async {
            let vc = StagingViewController(
                stagedPhotos: stagedItems,
                extensionContext: extensionContext,
                context: context
            )
            extensionContext.showViewController(vc)
            self.hostingController = vc
        }
    }

    override func resumeProject(
        _ project: PHProject,
        using extensionContext: PHProjectExtensionContext
    ) {
        beginProject(
            with: PHProjectInfo(),
            using: extensionContext
        )
    }

    // MARK: - Helpers

    private func fetchAssets(from projectInfo: PHProjectInfo) -> [PHAsset] {
        guard let section = projectInfo.sections.first else { return [] }
        let ids = section.assetLocalIdentifiers
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        // Sort by creation date ascending — oldest first
        return assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
    }

    private func loadPlayer(context: NSManagedObjectContext) -> Player? {
        let req = Player.fetchRequest()
        req.fetchLimit = 1
        return (try? context.fetch(req))?.first
    }

    private func stage(assets: [PHAsset], player: Player?, context: NSManagedObjectContext) -> [StagedPhoto] {
        var results: [StagedPhoto] = []
        let imageManager = PHImageManager.default()
        let thumbOptions = PHImageRequestOptions()
        thumbOptions.deliveryMode = .fastFormat
        thumbOptions.isSynchronous = true

        for (index, asset) in assets.enumerated() {
            // Skip if already staged
            let existing = StagedPhoto.fetchRequest()
            existing.predicate = NSPredicate(format: "phAssetLocalIdentifier == %@", asset.localIdentifier)
            if let found = try? context.fetch(existing), !found.isEmpty { continue }

            var thumbData: Data?
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: thumbOptions
            ) { image, _ in
                thumbData = image?.tiffRepresentation
                    .flatMap { NSBitmapImageRep(data: $0) }
                    .flatMap { $0.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) }
            }

            let staged = StagedPhoto.create(
                phAssetID:     asset.localIdentifier,
                exifDate:      asset.creationDate,
                thumbnailData: thumbData,
                player:        player ?? Player(context: context),
                context:       context
            )
            staged.queuePosition = Int32(index)
            results.append(staged)
        }

        try? context.save()
        return results
    }
}
