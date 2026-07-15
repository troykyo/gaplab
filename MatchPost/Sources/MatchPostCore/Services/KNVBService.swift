import Foundation

final class KNVBService {
    private let base = URL(string: "http://api.knvbdataservice.nl/v2")!

    private var apiKey: String? {
        try? KeychainManager.load(.knvbAPIKey)
    }

    func findMatches(teamName: String, near date: Date, opponentHint: String? = nil) async throws -> [KNVBMatch] {
        let clubID = try await resolveClubID(name: teamName)
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -3, to: date)!
        let to   = cal.date(byAdding: .day, value: +3, to: date)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var comps = URLComponents(url: base.appendingPathComponent("wedstrijden"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "clubId", value: clubID),
            URLQueryItem(name: "van",   value: formatter.string(from: from)),
            URLQueryItem(name: "tot",   value: formatter.string(from: to)),
        ]
        if let key = apiKey {
            comps.queryItems?.append(URLQueryItem(name: "apikey", value: key))
        }

        guard let url = comps.url else { throw AppError.knvbRequestFailed("Invalid URL") }
        let data = try await fetch(url)
        var matches = try parseMatches(data)

        if let hint = opponentHint?.lowercased() {
            matches = matches.filter {
                $0.homeTeam.lowercased().contains(hint) ||
                $0.awayTeam.lowercased().contains(hint)
            }
        }
        return matches
    }

    private func resolveClubID(name: String) async throws -> String {
        var comps = URLComponents(url: base.appendingPathComponent("clubs"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "naam", value: name)]
        if let key = apiKey { comps.queryItems?.append(URLQueryItem(name: "apikey", value: key)) }
        guard let url = comps.url else { throw AppError.knvbRequestFailed("Invalid URL") }
        let data = try await fetch(url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first,
              let id = first["id"] as? String ?? (first["id"] as? Int).map(String.init) else {
            throw AppError.matchNotFound
        }
        return id
    }

    private func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.knvbRequestFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        return data
    }

    private func parseMatches(_ data: Data) throws -> [KNVBMatch] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw AppError.knvbRequestFailed("Invalid JSON")
        }
        let formatter = ISO8601DateFormatter()
        return json.compactMap { item -> KNVBMatch? in
            guard let id   = item["id"] as? String ?? (item["id"] as? Int).map(String.init),
                  let dateStr = item["datumTijd"] as? String ?? item["datum"] as? String,
                  let date = formatter.date(from: dateStr) ?? parseDate(dateStr),
                  let home = item["thuisClub"] as? String ?? (item["thuisClub"] as? [String: Any])?["naam"] as? String,
                  let away = item["uitClub"]   as? String ?? (item["uitClub"]   as? [String: Any])?["naam"] as? String
            else { return nil }
            return KNVBMatch(
                id: id, date: date,
                homeTeam: home, awayTeam: away,
                homeGoals: item["thuisDoelpunten"] as? Int,
                awayGoals: item["uitDoelpunten"]   as? Int,
                venue:     (item["accommodatie"] as? [String: Any])?["naam"] as? String,
                venueCity: (item["accommodatie"] as? [String: Any])?["plaats"] as? String,
                competition: item["competitie"] as? String
                          ?? (item["competitie"] as? [String: Any])?["naam"] as? String
            )
        }
    }

    private func parseDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: str) { return d }
        }
        return nil
    }
}
