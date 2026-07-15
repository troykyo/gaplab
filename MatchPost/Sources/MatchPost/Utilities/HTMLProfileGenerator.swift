import Foundation
import AppKit

enum HTMLProfileGenerator {
    static func generate(player: Player, outputDir: URL) throws -> URL {
        let slug = player.name
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: "-")

        let outputURL = outputDir.appendingPathComponent("\(slug).html")
        let html = buildHTML(player: player)
        try html.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private static func buildHTML(player: Player) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: "nl_NL")

        let careerRows = player.sortedCareerEntries.map { entry in
            """
            <tr>
              <td>\(entry.teamName)</td>
              <td>\(entry.ageGroup)</td>
              <td>#\(entry.jerseyNumber)</td>
              <td>\(entry.displaySeason)</td>
            </tr>
            """
        }.joined()

        let photos = (player.matchPhotos as? Set<MatchPhoto> ?? [])
            .sorted { ($0.exifDate ?? .distantPast) < ($1.exifDate ?? .distantPast) }

        let photoItems = photos.compactMap { photo -> String? in
            guard let thumb = photo.thumbnailData else { return nil }
            let b64 = thumb.base64EncodedString()
            let date = photo.exifDate.map { df.string(from: $0) } ?? ""
            let score = photo.matchRecord.map { "\($0.opponentName) \($0.scoreDisplay)" } ?? ""
            return """
            <div class="photo-item">
              <img src="data:image/jpeg;base64,\(b64)" alt="\(score)" loading="lazy">
              <p>\(date) — \(score)</p>
            </div>
            """
        }.joined()

        let ageStr = player.age.map { "\($0) jaar" } ?? ""

        return """
        <!DOCTYPE html>
        <html lang="nl">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>\(player.name) — GAP Lab Player Profile</title>
          <link rel="stylesheet" href="../assets/css/main.css">
          <style>
            body { font-family: 'Source Sans Pro', sans-serif; max-width: 900px; margin: 0 auto; padding: 2rem; }
            .player-header { display: flex; align-items: center; gap: 2rem; margin-bottom: 2rem; }
            .player-header h1 { margin: 0; font-size: 2.5rem; }
            .career-table { width: 100%; border-collapse: collapse; margin-bottom: 2rem; }
            .career-table th, .career-table td { padding: .6rem 1rem; text-align: left; border-bottom: 1px solid #e0e0e0; }
            .career-table th { font-weight: 700; background: #f8f8f8; }
            .photo-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 1rem; }
            .photo-item img { width: 100%; border-radius: 8px; object-fit: cover; aspect-ratio: 1; }
            .photo-item p { font-size: .85rem; color: #666; margin: .4rem 0 0; }
          </style>
        </head>
        <body>
          <a href="../index.html">← GAP Lab</a>
          <div class="player-header">
            <div>
              <h1>\(player.name)</h1>
              <p>\(player.position) · \(ageStr) · \(player.currentTeamName ?? "")</p>
            </div>
          </div>

          <h2>Carrière</h2>
          <table class="career-table">
            <thead><tr><th>Club</th><th>Leeftijdscategorie</th><th>Rugnummer</th><th>Seizoen</th></tr></thead>
            <tbody>\(careerRows)</tbody>
          </table>

          <h2>Foto's</h2>
          <div class="photo-grid">\(photoItems)</div>

          <footer style="margin-top:3rem;font-size:.8rem;color:#aaa;">
            GAP Lab · Amsterdam University of Applied Sciences · thegaplab.net
          </footer>
        </body>
        </html>
        """
    }
}
