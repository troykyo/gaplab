import Photos
import PhotosUI
import AppKit
import SwiftUI
import MatchPostCore

/// Photos Editing Extension principal class.
/// Appears in Photos.app: open a photo → Edit mode → ··· → MatchPost
///
/// Shows an Instagram card preview and lets the user add the photo to the posting queue.
@objc(EditingExtensionController)
final class EditingExtensionController: NSViewController, PHContentEditingController {

    private var input: PHContentEditingInput?
    private var player: Player? {
        let ctx = PersistenceController.shared.container.viewContext
        let req = Player.fetchRequest(); req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    // MARK: - PHContentEditingController

    var shouldShowCancelConfirmation: Bool { false }

    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool { false }

    func startContentEditing(
        with contentEditingInput: PHContentEditingInput,
        placeholderImage: NSImage
    ) {
        input = contentEditingInput

        let exifDate: Date? = contentEditingInput.fullSizeImageURL
            .flatMap { try? Data(contentsOf: $0) }
            .map    { EXIFReader.extract(from: $0).date }
            ?? contentEditingInput.creationDate

        let preview = EditingPreviewView(
            placeholderImage: placeholderImage,
            exifDate:         exifDate,
            player:           player,
            onAddToQueue:     { [weak self] in self?.addToQueue(exifDate: exifDate) },
            onCancel:         { [weak self] in self?.cancelContentEditing() }
        )

        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 480, height: 560)
        view = hosting
    }

    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        // We don't modify the photo — return nil to signal no changes
        completionHandler(nil)
    }

    func cancelContentEditing() {
        // SwiftUI button triggers this via the hosting view
    }

    // MARK: - Queue

    private func addToQueue(exifDate: Date?) {
        guard let input,
              let assetID = input.localIdentifier else { return }

        let ctx = PersistenceController.shared.container.viewContext
        guard let player else { return }

        // Build thumbnail from placeholder
        let thumbData = input.displaySizeImage?
            .tiffRepresentation
            .flatMap { NSBitmapImageRep(data: $0) }
            .flatMap { $0.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) }

        _ = StagedPhoto.create(
            phAssetID:     assetID,
            exifDate:      exifDate,
            thumbnailData: thumbData,
            player:        player,
            context:       ctx
        )
        try? ctx.save()

        // Open MatchPost app pointing at the queue tab
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.troykyo.matchpost") {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, _ in }
        }
    }
}
