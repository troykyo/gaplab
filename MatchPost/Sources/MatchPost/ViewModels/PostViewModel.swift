import Foundation

@MainActor
final class PostViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var exportedURL: URL?
    @Published var exportError: String?

    private let exporter = GapLabProfileExporter()

    func exportProfile(player: Player) {
        isExporting = true
        exportError = nil
        Task {
            do {
                let url = try exporter.export(player: player)
                exportedURL = url
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }
}
