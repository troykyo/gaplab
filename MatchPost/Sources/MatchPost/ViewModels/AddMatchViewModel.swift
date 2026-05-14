import SwiftUI
import CoreData
import CoreLocation
import PhotosUI

@MainActor
final class AddMatchViewModel: ObservableObject {
    enum Step { case photoSelection, analyzing, reviewMatch, editCaption, confirmPost, posting, done, failed }

    @Published var step: Step = .photoSelection
    @Published var selectedImage: NSImage?
    @Published var selectedImageData: Data?
    @Published var exifData: EXIFData?
    @Published var analysis: MatchAnalysis?
    @Published var knvbMatches: [KNVBMatch] = []
    @Published var selectedMatch: KNVBMatch?
    @Published var manualMatch: ManualMatchInput = .empty
    @Published var post: InstagramPost?
    @Published var hostedURL: URL?
    @Published var error: AppError?

    private let claude = ClaudeService()
    private let knvb   = KNVBService()
    private let scraper = VoetbalScraper()
    private let hosting = ImageHostingService()
    private let instagram = InstagramService()

    var viewContext: NSManagedObjectContext?
    var player: Player?

    /// Set when launched from the posting queue so we can mark it posted on success.
    var sourceStagedPhoto: StagedPhoto?
    private let queueVM = PostingQueueViewModel()

    // MARK: - Step 1: Photo selected

    func photoSelected(_ image: NSImage, data: Data) {
        selectedImage = image
        selectedImageData = data
        exifData = EXIFReader.extract(from: data)
    }

    /// Load a StagedPhoto from the queue, fetching full-res data via PHImageManager.
    func loadFromQueue(_ staged: StagedPhoto) {
        sourceStagedPhoto = staged
        step = .analyzing
        Task {
            do {
                queueVM.load(context: viewContext!, player: player)
                let data = try await queueVM.loadFullResImage(for: staged)
                guard let image = NSImage(data: data) else { throw AppError.imageResizeFailed }
                photoSelected(image, data: data)
                // Immediately kick off analysis
                analyze()
            } catch let e as AppError {
                error = e; step = .failed
            } catch {
                self.error = .noImageSelected; step = .failed
            }
        }
    }

    // MARK: - Step 2: Analyze

    func analyze() {
        guard let data = selectedImageData else { step = .failed; error = .noImageSelected; return }
        guard let player else { step = .failed; error = .noPlayerConfigured; return }
        step = .analyzing

        Task {
            do {
                guard let jpeg = ImageResizer.resize(NSImage(data: data)!) else {
                    throw AppError.imageResizeFailed
                }
                let result = try await claude.analyzeImage(jpeg)
                analysis = result

                let searchTeam = player.currentTeamName ?? result.homeTeam
                let date = exifData?.date ?? Date()
                let opponent = result.awayTeam.isEmpty ? nil : result.awayTeam

                do {
                    var matches = try await knvb.findMatches(teamName: searchTeam, near: date, opponentHint: opponent)
                    if matches.isEmpty {
                        matches = try await scraper.findMatches(clubName: searchTeam, near: date)
                    }
                    knvbMatches = matches
                } catch {
                    knvbMatches = []
                }
                step = .reviewMatch
            } catch let e as AppError {
                self.error = e
                step = .failed
            } catch {
                self.error = .claudeVisionFailed(error.localizedDescription)
                step = .failed
            }
        }
    }

    // MARK: - Step 3: Match confirmed

    func confirmMatch(_ match: KNVBMatch) {
        selectedMatch = match
        generateCaption()
    }

    func confirmManual() {
        selectedMatch = nil
        generateCaption()
    }

    private func generateCaption() {
        guard let player else { step = .failed; error = .noPlayerConfigured; return }
        step = .analyzing

        Task {
            do {
                let record = buildMatchRecord()
                post = try await claude.generateCareerCaption(player: player, match: record)
                step = .editCaption
            } catch let e as AppError {
                error = e; step = .failed
            } catch {
                self.error = .claudeCaptionFailed(error.localizedDescription); step = .failed
            }
        }
    }

    // MARK: - Step 4: Upload + Post

    func uploadAndConfirm() {
        guard let imageData = selectedImageData,
              let image = NSImage(data: imageData) else { return }
        step = .posting

        Task {
            do {
                guard let jpeg = ImageResizer.resize(image) else { throw AppError.imageResizeFailed }
                let url = try await hosting.upload(jpeg)
                hostedURL = url
                step = .confirmPost
            } catch let e as AppError {
                error = e; step = .failed
            } catch {
                self.error = .imageUploadFailed(error.localizedDescription); step = .failed
            }
        }
    }

    func publishToInstagram() {
        guard let url = hostedURL, var post = post else { return }
        step = .posting

        Task {
            do {
                let postID = try await instagram.publish(imageURL: url, caption: post.fullCaption)
                post.publishedPostID = postID
                self.post = post
                saveMatchPhoto(instagramPostID: postID)
                step = .done
            } catch let e as AppError {
                error = e; step = .failed
            } catch {
                self.error = .instagramContainerFailed(error.localizedDescription); step = .failed
            }
        }
    }

    // MARK: - CoreData

    private func buildMatchRecord() -> MatchRecord {
        let ctx = viewContext!
        let record = MatchRecord(context: ctx)
        if let m = selectedMatch {
            record.knvbMatchID  = m.id
            record.matchDate    = m.date
            record.opponentName = resolveOpponent(m)
            record.homeGoals    = Int16(m.homeGoals ?? 0)
            record.awayGoals    = Int16(m.awayGoals ?? 0)
            record.wasHome      = player?.currentTeamName.map { m.homeTeam.lowercased().contains($0.lowercased()) } ?? true
            record.venueName    = m.venue
            record.venueCity    = m.venueCity
            record.competition  = m.competition
        } else {
            record.matchDate    = exifData?.date ?? Date()
            record.opponentName = manualMatch.opponent
            record.homeGoals    = Int16(manualMatch.homeGoals)
            record.awayGoals    = Int16(manualMatch.awayGoals)
            record.wasHome      = manualMatch.wasHome
            record.competition  = manualMatch.competition
        }
        return record
    }

    private func resolveOpponent(_ m: KNVBMatch) -> String {
        guard let teamName = player?.currentTeamName else { return m.awayTeam }
        return m.homeTeam.lowercased().contains(teamName.lowercased()) ? m.awayTeam : m.homeTeam
    }

    private func saveMatchPhoto(instagramPostID: String?) {
        guard let ctx = viewContext,
              let imageData = selectedImageData,
              let image = NSImage(data: imageData) else { return }
        let photo = MatchPhoto(context: ctx)
        photo.imageData = imageData
        photo.thumbnailData = ImageResizer.makeThumbnail(image)
        photo.exifDate = exifData?.date
        photo.exifLatitude  = exifData?.coordinate?.latitude  ?? 0
        photo.exifLongitude = exifData?.coordinate?.longitude ?? 0
        photo.claudeAnalysisJSON = (try? JSONEncoder().encode(analysis)).flatMap { String(data: $0, encoding: .utf8) }
        photo.instagramPostID = instagramPostID
        photo.captionText = post?.fullCaption
        photo.player = player
        photo.matchRecord = buildMatchRecord()
        try? ctx.save()
    }

    func reset() {
        step = .photoSelection
        selectedImage = nil; selectedImageData = nil; exifData = nil
        analysis = nil; knvbMatches = []; selectedMatch = nil
        manualMatch = .empty; post = nil; hostedURL = nil; error = nil
    }
}

struct ManualMatchInput {
    var opponent: String = ""
    var homeGoals: Int = 0
    var awayGoals: Int = 0
    var wasHome: Bool = true
    var competition: String = ""
    var date: Date = Date()

    static let empty = ManualMatchInput()
}
