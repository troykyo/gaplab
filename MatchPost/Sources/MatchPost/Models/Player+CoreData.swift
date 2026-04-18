import CoreData
import Foundation

@objc(Player)
public class Player: NSManagedObject {}

extension Player {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        NSFetchRequest<Player>(entityName: "Player")
    }

    @NSManaged public var name: String
    @NSManaged public var position: String
    @NSManaged public var currentTeamName: String?
    @NSManaged public var currentJerseyNumber: Int16
    @NSManaged public var dateOfBirth: Date?
    @NSManaged public var instagramHandle: String?
    @NSManaged public var careerEntries: NSSet?
    @NSManaged public var matchPhotos: NSSet?

    var sortedCareerEntries: [CareerEntry] {
        let entries = careerEntries as? Set<CareerEntry> ?? []
        return entries.sorted { $0.seasonStart < $1.seasonStart }
    }

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: .now).year
    }

    var careerSummaryJSON: String {
        let entries = sortedCareerEntries.map { entry -> [String: String] in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            let start = formatter.string(from: entry.seasonStart)
            let end = entry.seasonEnd.map { formatter.string(from: $0) } ?? "present"
            return [
                "team": entry.teamName,
                "ageGroup": entry.ageGroup,
                "seasons": "\(start)–\(end)",
                "jerseyNumber": "#\(entry.jerseyNumber)"
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: entries),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}

extension Player {
    @objc(addCareerEntriesObject:)
    @NSManaged public func addToCareerEntries(_ value: CareerEntry)

    @objc(removeCareerEntriesObject:)
    @NSManaged public func removeFromCareerEntries(_ value: CareerEntry)

    @objc(addMatchPhotosObject:)
    @NSManaged public func addToMatchPhotos(_ value: MatchPhoto)

    @objc(removeMatchPhotosObject:)
    @NSManaged public func removeFromMatchPhotos(_ value: MatchPhoto)
}
