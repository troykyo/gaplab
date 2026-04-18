import CoreData
import Combine

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var matchesByYear: [(year: Int, matches: [MatchRecord])] = []

    private var cancellables = Set<AnyCancellable>()

    func load(context: NSManagedObjectContext) {
        let request = MatchRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "matchDate", ascending: false)]
        let results = (try? context.fetch(request)) ?? []

        let cal = Calendar.current
        let grouped = Dictionary(grouping: results) { cal.component(.year, from: $0.matchDate) }
        matchesByYear = grouped.keys
            .sorted(by: >)
            .map { year in (year: year, matches: grouped[year]!.sorted { $0.matchDate > $1.matchDate }) }
    }

    var totalMatches: Int { matchesByYear.flatMap(\.matches).count }
    var totalWins: Int   { matchesByYear.flatMap(\.matches).filter { $0.result == .win }.count }
}
