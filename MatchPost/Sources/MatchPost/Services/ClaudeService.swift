import Foundation

final class ClaudeService {
    private let model = "claude-sonnet-4-6"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private var apiKey: String {
        get throws { try KeychainManager.load(.anthropicAPIKey) }
    }

    // MARK: - Vision Analysis

    func analyzeImage(_ jpegData: Data) async throws -> MatchAnalysis {
        let base64 = jpegData.base64EncodedString()
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "You are a football match analyst. Always respond with valid JSON only, no markdown.",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                    ["type": "text",
                     "text": """
                     Analyze this football match photo. Return a JSON object with these exact keys:
                     - homeTeam: string (team name on the left/home side)
                     - awayTeam: string (team name on the right/away side)
                     - stadium: string or null
                     - clockTime: string or null (e.g. "87'" or "HT")
                     - visibleScore: {"home": int, "away": int} or null
                     - recognizedPlayers: array of {"name": string, "jerseyNumber": int or null}
                     - confidence: float 0.0-1.0

                     Check in order: (1) names/badges on shirts, (2) stadium signage/boards,
                     (3) scoreboard text, (4) kit colors as last resort.
                     """]
                ]
            ]]
        ]

        let data = try await post(body: body)
        return try parseVisionResponse(data)
    }

    // MARK: - Caption Generation

    func generateCareerCaption(player: Player, match: MatchRecord) async throws -> InstagramPost {
        let ageDisplay = player.age.map { "\($0) years old" } ?? "youth player"
        let scoreStr = "\(match.homeGoals)–\(match.awayGoals)"
        let venue = [match.venueName, match.venueCity].compactMap { $0 }.joined(separator: ", ")

        let prompt = """
        Player: \(player.name), \(ageDisplay), position: \(player.position).
        Career history: \(player.careerSummaryJSON)
        Today's match: \(player.currentTeamName ?? "his team") vs \(match.opponentName) — score \(scoreStr), \
        \(match.wasHome ? "home" : "away") match\(venue.isEmpty ? "" : " at \(venue)").
        Competition: \(match.competition ?? "youth football").

        Write an emotional 3–4 sentence Instagram caption in a mix of Dutch and English.
        Reference the player's journey from his earliest career entry to today.
        Include the score prominently. Use exclamations like "Wat een wedstrijd!" or "Trots!".
        End with a blank line then return only the hashtag strings as a JSON array
        (no # symbol, just the words). All hashtags must be in English — the caption
        may mix Dutch and English, but hashtags are English only.
        Format your full response as JSON:
        {"caption": "...", "hashtags": ["tag1", "tag2", ...]}
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "You are a passionate Dutch football chronicler. Always respond with valid JSON only.",
            "messages": [["role": "user", "content": prompt]]
        ]

        let data = try await post(body: body)
        return try parseCaptionResponse(data, match: match, player: player)
    }

    // MARK: - Helpers

    private func post(body: [String: Any]) async throws -> Data {
        let key = try apiKey
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw AppError.claudeVisionFailed(msg)
        }
        return data
    }

    private func parseVisionResponse(_ data: Data) throws -> MatchAnalysis {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (root["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw AppError.claudeVisionFailed("Could not parse response")
        }
        do {
            return try JSONDecoder().decode(MatchAnalysis.self, from: jsonData)
        } catch {
            throw AppError.claudeVisionFailed(error.localizedDescription)
        }
    }

    private func parseCaptionResponse(_ data: Data, match: MatchRecord, player: Player) throws -> InstagramPost {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (root["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String,
              let jsonData = text.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let caption = parsed["caption"] as? String else {
            throw AppError.claudeCaptionFailed("Could not parse caption response")
        }

        let claudeTags = (parsed["hashtags"] as? [String]) ?? []
        let builtTags = HashtagBuilder.build(
            playerTeam: player.currentTeamName,
            opponent: match.opponentName,
            competition: match.competition,
            ageGroup: player.sortedCareerEntries.last?.ageGroup,
            homeGoals: Int(match.homeGoals),
            awayGoals: Int(match.awayGoals),
            wasHome: match.wasHome
        )
        let mergedTags = Array(NSOrderedSet(array: claudeTags + builtTags)
            .compactMap { $0 as? String }
            .prefix(30))

        let scoreStr = match.wasHome
            ? "\(match.homeGoals)–\(match.awayGoals)"
            : "\(match.awayGoals)–\(match.homeGoals)"

        return InstagramPost(caption: caption, hashtags: mergedTags, score: scoreStr)
    }
}
