import CoreData
import Foundation

@objc(CareerEntry)
public class CareerEntry: NSManagedObject {}

extension CareerEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CareerEntry> {
        NSFetchRequest<CareerEntry>(entityName: "CareerEntry")
    }

    @NSManaged public var teamName: String
    @NSManaged public var ageGroup: String
    @NSManaged public var jerseyNumber: Int16
    @NSManaged public var seasonStart: Date
    @NSManaged public var seasonEnd: Date?
    @NSManaged public var notes: String?
    @NSManaged public var player: Player?

    var displaySeason: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        let start = f.string(from: seasonStart)
        let end = seasonEnd.map { f.string(from: $0) } ?? "present"
        return "\(start)–\(end)"
    }

    var isCurrent: Bool { seasonEnd == nil }
}
