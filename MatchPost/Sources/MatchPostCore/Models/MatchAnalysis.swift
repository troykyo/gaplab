import Foundation

struct MatchAnalysis: Codable {
    let homeTeam: String
    let awayTeam: String
    let stadium: String?
    let clockTime: String?
    let visibleScore: VisibleScore?
    let recognizedPlayers: [RecognizedPlayer]
    let confidence: Double

    struct VisibleScore: Codable, Equatable {
        let home: Int
        let away: Int
    }

    struct RecognizedPlayer: Codable, Identifiable {
        var id: String { name }
        let name: String
        let jerseyNumber: Int?
    }

    var isHighConfidence: Bool { confidence >= 0.7 }

    static let empty = MatchAnalysis(
        homeTeam: "", awayTeam: "", stadium: nil,
        clockTime: nil, visibleScore: nil,
        recognizedPlayers: [], confidence: 0
    )
}

struct KNVBMatch: Identifiable {
    let id: String
    let date: Date
    let homeTeam: String
    let awayTeam: String
    let homeGoals: Int?
    let awayGoals: Int?
    let venue: String?
    let venueCity: String?
    let competition: String?
}
