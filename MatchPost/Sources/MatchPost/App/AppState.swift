import SwiftUI
import CoreData

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab = .timeline
    @Published var activePlayer: Player?
    @Published var error: AppError?
    /// Set by PostingQueueView to pre-load a staged photo into AddMatchView
    @Published var pendingStagedPhoto: StagedPhoto?

    let persistenceController = PersistenceController.shared

    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    init() {
        loadActivePlayer()
    }

    private func loadActivePlayer() {
        let request = Player.fetchRequest()
        request.fetchLimit = 1
        let players = (try? viewContext.fetch(request)) ?? []
        activePlayer = players.first
    }

    func clearError() { error = nil }
}

enum AppTab: String, CaseIterable {
    case timeline = "Timeline"
    case queue    = "Queue"
    case addMatch = "Add Match"
    case profile  = "Profile"
    case gaplab   = "GAP Lab"
    case settings = "Settings"

    var systemImage: String {
        switch self {
        case .timeline:  return "clock.fill"
        case .queue:     return "tray.full.fill"
        case .addMatch:  return "plus.circle.fill"
        case .profile:   return "person.fill"
        case .gaplab:    return "globe"
        case .settings:  return "gearshape.fill"
        }
    }
}

final class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    let container: NSPersistentContainer

    static let appGroupID = "group.com.troykyo.matchpost"

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MatchPost")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use App Group container so extensions share the same store
            if let groupURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
                let storeURL = groupURL.appendingPathComponent("MatchPost.sqlite")
                container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
            }
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("CoreData load failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        try? ctx.save()
    }
}
