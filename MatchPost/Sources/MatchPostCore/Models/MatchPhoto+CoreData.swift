import CoreData
import Foundation
import AppKit

@objc(MatchPhoto)
public class MatchPhoto: NSManagedObject {}

extension MatchPhoto {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MatchPhoto> {
        NSFetchRequest<MatchPhoto>(entityName: "MatchPhoto")
    }

    @NSManaged public var imageData: Data
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var exifDate: Date?
    @NSManaged public var exifLatitude: Double
    @NSManaged public var exifLongitude: Double
    @NSManaged public var claudeAnalysisJSON: String?
    @NSManaged public var instagramPostID: String?
    @NSManaged public var captionText: String?
    @NSManaged public var matchRecord: MatchRecord?
    @NSManaged public var player: Player?
    @NSManaged public var stagedFrom: StagedPhoto?

    var nsImage: NSImage? { NSImage(data: imageData) }
    var thumbnail: NSImage? { thumbnailData.flatMap { NSImage(data: $0) } }
    var hasBeenPosted: Bool { instagramPostID != nil }
    var hasLocation: Bool { exifLatitude != 0 || exifLongitude != 0 }
}
