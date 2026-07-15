import CoreData
import Foundation

@objc(MatchRecord)
public class MatchRecord: NSManagedObject {}

extension MatchRecord {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MatchRecord> {
        NSFetchRequest<MatchRecord>(entityName: "MatchRecord")
    }

    @NSManaged public var knvbMatchID: String?
    @NSManaged public var matchDate: Date
    @NSManaged public var opponentName: String
    @NSManaged public var homeGoals: Int16
    @NSManaged public var awayGoals: Int16
    @NSManaged public var wasHome: Bool
    @NSManaged public var venueName: String?
    @NSManaged public var venueCity: String?
    @NSManaged public var competition: String?
    @NSManaged public var notes: String?
    @NSManaged public var photos: NSSet?

    var scoreDisplay: String {
        wasHome
            ? "\(homeGoals) – \(awayGoals)"
            : "\(awayGoals) – \(homeGoals)"
    }

    var result: MatchResult {
        let ours  = wasHome ? homeGoals : awayGoals
        let theirs = wasHome ? awayGoals : homeGoals
        if ours > theirs  { return .win }
        if ours < theirs  { return .loss }
        return .draw
    }

    var sortedPhotos: [MatchPhoto] {
        let set = photos as? Set<MatchPhoto> ?? []
        return set.sorted { ($0.exifDate ?? .distantPast) < ($1.exifDate ?? .distantPast) }
    }
}

enum MatchResult { case win, draw, loss }

extension MatchRecord {
    @objc(addPhotosObject:)
    @NSManaged public func addToPhotos(_ value: MatchPhoto)

    @objc(removePhotosObject:)
    @NSManaged public func removeFromPhotos(_ value: MatchPhoto)
}
