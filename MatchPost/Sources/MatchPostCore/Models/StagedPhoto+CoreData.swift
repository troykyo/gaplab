import CoreData
import Foundation

@objc(StagedPhoto)
public class StagedPhoto: NSManagedObject {}

extension StagedPhoto {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<StagedPhoto> {
        NSFetchRequest<StagedPhoto>(entityName: "StagedPhoto")
    }

    @NSManaged public var phAssetLocalIdentifier: String
    @NSManaged public var imageData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var exifDate: Date?
    @NSManaged public var addedAt: Date
    @NSManaged public var queuePosition: Int32
    @NSManaged public var status: String
    @NSManaged public var player: Player?
    @NSManaged public var postedAs: MatchPhoto?

    var isPending:  Bool { status == StagedPhotoStatus.pending.rawValue }
    var isPosted:   Bool { status == StagedPhotoStatus.posted.rawValue }
    var isSkipped:  Bool { status == StagedPhotoStatus.skipped.rawValue }

    // Effective date for oldest-first ordering: EXIF date preferred, addedAt as fallback
    var effectiveSortDate: Date { exifDate ?? addedAt }
}

enum StagedPhotoStatus: String {
    case pending   = "pending"
    case analyzing = "analyzing"
    case captioned = "captioned"
    case posted    = "posted"
    case skipped   = "skipped"
}

// MARK: - Fetch helpers

extension StagedPhoto {
    /// All pending photos for a player, sorted oldest-first (primary: exifDate, fallback: addedAt).
    static func pendingRequest(for player: Player) -> NSFetchRequest<StagedPhoto> {
        let request = StagedPhoto.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "player == %@", player),
            NSPredicate(format: "status == %@", StagedPhotoStatus.pending.rawValue),
        ])
        request.sortDescriptors = [
            // Oldest photo first (nil exifDate sorts to end via secondary key)
            NSSortDescriptor(key: "exifDate",      ascending: true),
            NSSortDescriptor(key: "queuePosition", ascending: true),
            NSSortDescriptor(key: "addedAt",       ascending: true),
        ]
        return request
    }

    static func create(
        phAssetID: String,
        exifDate: Date?,
        thumbnailData: Data?,
        player: Player,
        context: NSManagedObjectContext
    ) -> StagedPhoto {
        let staged = StagedPhoto(context: context)
        staged.phAssetLocalIdentifier = phAssetID
        staged.exifDate       = exifDate
        staged.thumbnailData  = thumbnailData
        staged.addedAt        = Date()
        staged.status         = StagedPhotoStatus.pending.rawValue
        staged.queuePosition  = 0
        staged.player         = player
        return staged
    }
}
