import CoreData
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var position: String = "Central Midfielder"
    @Published var currentTeam: String = ""
    @Published var jerseyNumber: String = ""
    @Published var instagramHandle: String = ""
    @Published var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -14, to: Date())!
    @Published var careerEntries: [CareerEntryDraft] = []
    @Published var isSaved = false

    let positions = [
        "Goalkeeper",
        "Right Back", "Centre Back", "Left Back", "Wing Back",
        "Defensive Midfielder", "Central Midfielder", "Attacking Midfielder",
        "Right Winger", "Left Winger",
        "Second Striker", "Striker",
    ]

    func load(from player: Player) {
        name            = player.name
        // Map legacy generic positions to the specific list so the picker keeps a valid selection
        let legacy = ["Midfielder": "Central Midfielder", "Defender": "Centre Back", "Forward": "Striker"]
        position        = positions.contains(player.position)
                        ? player.position
                        : (legacy[player.position] ?? "Central Midfielder")
        currentTeam     = player.currentTeamName ?? ""
        jerseyNumber    = "\(player.currentJerseyNumber)"
        instagramHandle = player.instagramHandle ?? ""
        dateOfBirth     = player.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -14, to: Date())!
        careerEntries   = player.sortedCareerEntries.map(CareerEntryDraft.init)
    }

    func save(to player: Player, context: NSManagedObjectContext) {
        player.name               = name
        player.position           = position
        player.currentTeamName    = currentTeam.isEmpty ? nil : currentTeam
        player.currentJerseyNumber = Int16(jerseyNumber) ?? 0
        player.instagramHandle    = instagramHandle.isEmpty ? nil : instagramHandle
        player.dateOfBirth        = dateOfBirth

        let existing = player.careerEntries as? Set<CareerEntry> ?? []
        existing.forEach { context.delete($0) }

        for draft in careerEntries {
            let entry = CareerEntry(context: context)
            entry.teamName     = draft.teamName
            entry.ageGroup     = draft.ageGroup
            entry.jerseyNumber = Int16(draft.jerseyNumber) ?? 0
            entry.seasonStart  = draft.seasonStart
            entry.seasonEnd    = draft.isCurrent ? nil : draft.seasonEnd
            entry.player       = player
        }
        try? context.save()
        isSaved = true
    }

    func createPlayer(context: NSManagedObjectContext) -> Player {
        let player = Player(context: context)
        save(to: player, context: context)
        return player
    }

    func addCareerEntry() {
        careerEntries.append(CareerEntryDraft(
            teamName: currentTeam,
            ageGroup: "U14",
            jerseyNumber: jerseyNumber,
            seasonStart: dateOfBirth,
            seasonEnd: nil,
            isCurrent: true
        ))
    }
}

struct CareerEntryDraft: Identifiable {
    let id = UUID()
    var teamName: String
    var ageGroup: String
    var jerseyNumber: String
    var seasonStart: Date
    var seasonEnd: Date?
    var isCurrent: Bool

    init(from entry: CareerEntry) {
        teamName     = entry.teamName
        ageGroup     = entry.ageGroup
        jerseyNumber = "\(entry.jerseyNumber)"
        seasonStart  = entry.seasonStart
        seasonEnd    = entry.seasonEnd
        isCurrent    = entry.seasonEnd == nil
    }

    init(teamName: String, ageGroup: String, jerseyNumber: String,
         seasonStart: Date, seasonEnd: Date?, isCurrent: Bool) {
        self.teamName     = teamName
        self.ageGroup     = ageGroup
        self.jerseyNumber = jerseyNumber
        self.seasonStart  = seasonStart
        self.seasonEnd    = seasonEnd
        self.isCurrent    = isCurrent
    }
}
