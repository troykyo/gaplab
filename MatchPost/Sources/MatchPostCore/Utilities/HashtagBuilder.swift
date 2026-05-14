import Foundation

enum HashtagBuilder {
    static let maxTags = 30

    static let teamAbbreviations: [String: String] = [
        "Ajax": "AFC",
        "Feyenoord": "FEY",
        "PSV": "PSVEindhoven",
        "AZ": "AZAlkmaar",
        "FC Utrecht": "FCU",
        "FC Groningen": "FCG",
    ]

    static func build(
        playerTeam: String?,
        opponent: String?,
        competition: String?,
        ageGroup: String?,
        homeGoals: Int,
        awayGoals: Int,
        wasHome: Bool
    ) -> [String] {
        var tags: [String] = []

        if let team = playerTeam {
            tags.append(camelCase(team))
            if let abbr = teamAbbreviations[team] { tags.append(abbr) }
        }
        if let opp = opponent {
            tags.append(camelCase(opp))
        }
        if let comp = competition {
            tags.append(camelCase(comp))
        }
        if let ag = ageGroup {
            tags.append(ag.replacingOccurrences(of: " ", with: ""))
            let digits = ag.filter { $0.isNumber }
            if !digits.isEmpty { tags.append("Onder\(digits)") }
        }

        let ours   = wasHome ? homeGoals : awayGoals
        let theirs = wasHome ? awayGoals : homeGoals
        tags.append("\(ours)x\(theirs)")

        tags += ["voetbal", "dutchfootball", "KNVB", "Netherlands",
                 "soccer", "football", "matchday", "kidswhokick", "soccerlife"]

        let unique = Array(NSOrderedSet(array: tags).compactMap { $0 as? String })
        return Array(unique.prefix(maxTags))
    }

    private static func camelCase(_ input: String) -> String {
        input
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }
}
