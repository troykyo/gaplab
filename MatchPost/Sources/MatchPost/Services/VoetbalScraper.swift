import Foundation

/// HTML fallback: fetches a voetbal.nl club page and uses Claude to extract match data.
final class VoetbalScraper {
    private let claude = ClaudeService()

    func findMatches(clubName: String, near date: Date) async throws -> [KNVBMatch] {
        let slug = clubName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: .letters.inverted.union(.init(charactersIn: "-"))).joined()
        guard let url = URL(string: "https://www.voetbal.nl/club/\(slug)/programma") else {
            throw AppError.knvbRequestFailed("Could not build voetbal.nl URL for \(clubName)")
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.matchNotFound
        }
        let html = String(data: data, encoding: .utf8) ?? ""

        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        let dateStr = formatter.string(from: date)

        let prompt = """
        Below is HTML from a Dutch football club's schedule page on voetbal.nl.
        Extract all matches visible in the HTML. Return a JSON array only, each element:
        {"id": "unique_string", "date": "ISO8601", "homeTeam": "...", "awayTeam": "...",
         "homeGoals": int_or_null, "awayGoals": int_or_null, "venue": "..._or_null",
         "venueCity": "..._or_null", "competition": "..._or_null"}
        Focus on matches near \(dateStr). HTML follows:
        \(String(html.prefix(8000)))
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 2048,
            "system": "You are an HTML parser. Return valid JSON arrays only.",
            "messages": [["role": "user", "content": prompt]]
        ]

        let key = try KeychainManager.load(.anthropicAPIKey)
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (respData, _) = try await URLSession.shared.data(for: req)
        guard let root = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
              let content = (root["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String,
              let jsonData = text.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw AppError.matchNotFound
        }

        let iso = ISO8601DateFormatter()
        return items.compactMap { item -> KNVBMatch? in
            guard let id   = item["id"] as? String,
                  let ds   = item["date"] as? String,
                  let d    = iso.date(from: ds),
                  let home = item["homeTeam"] as? String,
                  let away = item["awayTeam"] as? String else { return nil }
            return KNVBMatch(
                id: id, date: d,
                homeTeam: home, awayTeam: away,
                homeGoals: item["homeGoals"] as? Int,
                awayGoals: item["awayGoals"] as? Int,
                venue:      item["venue"] as? String,
                venueCity:  item["venueCity"] as? String,
                competition: item["competition"] as? String
            )
        }
    }
}
