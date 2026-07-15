import CoreData
import Foundation

@objc(StagedPostGroup)
public class StagedPostGroup: NSManagedObject {}

extension StagedPostGroup {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<StagedPostGroup> {
        NSFetchRequest<StagedPostGroup>(entityName: "StagedPostGroup")
    }

    /// Date of the earliest photo in the group — primary sort key for oldest-first posting.
    @NSManaged public var sessionDate: Date
    @NSManaged public var addedAt: Date
    @NSManaged public var groupID: UUID
    @NSManaged public var status: String
    /// phAssetLocalIdentifier of the chosen cover photo. Nil means use the oldest photo.
    @NSManaged public var coverAssetID: String?
    @NSManaged public var photos: NSSet?
    @NSManaged public var player: Player?
    @NSManaged public var postedAs: MatchPhoto?

    var isPending: Bool { status == StagedPhotoStatus.pending.rawValue }
    var isPosted:  Bool { status == StagedPhotoStatus.posted.rawValue }
    var isCarousel: Bool { (photos?.count ?? 0) > 1 }
    var photoCount: Int  { photos?.count ?? 0 }

    /// Photos in posting order. User-arranged order (queuePosition, written 1…n on
    /// reorder) wins; until then falls back to EXIF date, oldest first.
    var sortedPhotos: [StagedPhoto] {
        let set = photos as? Set<StagedPhoto> ?? []
        return set.sorted {
            if $0.queuePosition != $1.queuePosition {
                return $0.queuePosition < $1.queuePosition
            }
            switch ($0.exifDate, $1.exifDate) {
            case (.some(let a), .some(let b)): return a < b
            case (.some, .none):               return true
            case (.none, .some):               return false
            case (.none, .none):               return $0.addedAt < $1.addedAt
            }
        }
    }

    /// The cover is the first photo in posting order (Instagram shows it first).
    /// coverAssetID survives as an explicit override for pre-reorder groups.
    var coverPhoto: StagedPhoto? {
        if let id = coverAssetID {
            return sortedPhotos.first { $0.phAssetLocalIdentifier == id }
        }
        return sortedPhotos.first
    }

    /// Persist an explicit photo order (1…n) and sync the cover to the first photo.
    func applyOrder(_ ordered: [StagedPhoto]) {
        for (index, photo) in ordered.enumerated() {
            photo.queuePosition = Int32(index + 1)
        }
        coverAssetID = ordered.first?.phAssetLocalIdentifier
    }

    // MARK: - Location → home/away

    /// First photo in the group that carries GPS data.
    var locatedPhoto: StagedPhoto? {
        sortedPhotos.first { $0.exifLatitude != 0 || $0.exifLongitude != 0 }
    }

    /// The home ground this session was played at, if any photo's GPS falls
    /// within a configured home venue radius.
    var homeVenue: HomeVenue? {
        guard let photo = locatedPhoto else { return nil }
        return HomeVenueLocator.homeVenue(latitude: photo.exifLatitude,
                                          longitude: photo.exifLongitude)
    }

    /// true = home, false = away, nil = no GPS data on any photo.
    var isHomeMatch: Bool? {
        guard locatedPhoto != nil else { return nil }
        return homeVenue != nil
    }

    // MARK: - Fetch

    /// All pending groups for a player, sorted oldest session first.
    public static func pendingRequest(for player: Player) -> NSFetchRequest<StagedPostGroup> {
        let request = StagedPostGroup.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "player == %@", player),
            NSPredicate(format: "status == %@", StagedPhotoStatus.pending.rawValue),
        ])
        request.sortDescriptors = [
            NSSortDescriptor(key: "sessionDate", ascending: true),
            NSSortDescriptor(key: "addedAt",     ascending: true),
        ]
        return request
    }

    // MARK: - Factory

    public static func create(
        from candidates: [StagingCandidate],
        player: Player,
        context: NSManagedObjectContext
    ) -> StagedPostGroup {
        let group = StagedPostGroup(context: context)
        group.groupID     = UUID()
        group.addedAt     = Date()
        group.status      = StagedPhotoStatus.pending.rawValue
        group.sessionDate = candidates.compactMap(\.exifDate).min() ?? group.addedAt
        group.player      = player

        for c in candidates {
            let photo = StagedPhoto.create(
                phAssetID:     c.id,
                exifDate:      c.exifDate,
                thumbnailData: c.thumbnailData,
                player:        player,
                context:       context,
                latitude:      c.latitude,
                longitude:     c.longitude
            )
            photo.imageData = c.imageData
            photo.group     = group
        }
        return group
    }
}

extension StagedPostGroup {
    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: StagedPhoto)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: StagedPhoto)
}
