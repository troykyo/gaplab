import Foundation

final class GapLabProfileExporter {
    private let repoRoot: URL

    init() {
        // Walk up from the app bundle to find the gaplab repo root
        let fm = FileManager.default
        var candidate = Bundle.main.bundleURL
        for _ in 0..<8 {
            candidate = candidate.deletingLastPathComponent()
            if fm.fileExists(atPath: candidate.appendingPathComponent("index.html").path) {
                break
            }
        }
        repoRoot = candidate
    }

    func export(player: Player) throws -> URL {
        let playersDir = repoRoot.appendingPathComponent("players")
        try FileManager.default.createDirectory(at: playersDir, withIntermediateDirectories: true)
        return try HTMLProfileGenerator.generate(player: player, outputDir: playersDir)
    }

    var playersDirectory: URL {
        repoRoot.appendingPathComponent("players")
    }
}
