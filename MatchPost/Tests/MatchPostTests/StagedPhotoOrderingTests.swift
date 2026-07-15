import XCTest
import CoreData
@testable import MatchPost

final class StagedPhotoOrderingTests: XCTestCase {
    var ctx: NSManagedObjectContext!
    var player: Player!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        ctx    = controller.container.viewContext
        player = Player(context: ctx)
        player.name     = "Test Player"
        player.position = "Midfielder"
        try? ctx.save()
    }

    // MARK: - Oldest-first ordering

    func testOldestExifDateComesFirst() throws {
        let dates: [Date] = [
            date(2024, 5, 10),
            date(2023, 3, 1),   // ← oldest, should be first
            date(2024, 1, 20),
            date(2025, 8, 14),
        ]
        for d in dates {
            _ = StagedPhoto.create(phAssetID: UUID().uuidString,
                                   exifDate: d, thumbnailData: nil,
                                   player: player, context: ctx)
        }
        try ctx.save()

        let results = try ctx.fetch(StagedPhoto.pendingRequest(for: player))
        XCTAssertEqual(results.count, 4)
        XCTAssertEqual(results[0].exifDate, date(2023, 3, 1),
                       "Oldest EXIF date must be first")
        XCTAssertEqual(results[3].exifDate, date(2025, 8, 14),
                       "Newest EXIF date must be last")
    }

    func testPhotoWithNoExifDateSortsAfterDatedPhotos() throws {
        _ = StagedPhoto.create(phAssetID: "no-date", exifDate: nil,
                               thumbnailData: nil, player: player, context: ctx)
        _ = StagedPhoto.create(phAssetID: "has-date", exifDate: date(2024, 6, 1),
                               thumbnailData: nil, player: player, context: ctx)
        try ctx.save()

        let results = try ctx.fetch(StagedPhoto.pendingRequest(for: player))
        XCTAssertEqual(results.count, 2)
        // nil exifDate sorts after real dates (ascending nil goes last)
        XCTAssertNotNil(results[0].exifDate, "Dated photo must come first")
        XCTAssertNil(results[1].exifDate, "Undated photo must come last")
    }

    func testQueuePositionBreaksTieWhenExifDatesAreEqual() throws {
        let sameDate = date(2024, 9, 5)
        let first = StagedPhoto.create(phAssetID: "a", exifDate: sameDate,
                                       thumbnailData: nil, player: player, context: ctx)
        first.queuePosition = 0
        let second = StagedPhoto.create(phAssetID: "b", exifDate: sameDate,
                                        thumbnailData: nil, player: player, context: ctx)
        second.queuePosition = 1
        try ctx.save()

        let results = try ctx.fetch(StagedPhoto.pendingRequest(for: player))
        XCTAssertEqual(results[0].phAssetLocalIdentifier, "a")
        XCTAssertEqual(results[1].phAssetLocalIdentifier, "b")
    }

    func testSkippedPhotosAreExcludedFromQueue() throws {
        let pending = StagedPhoto.create(phAssetID: "pending", exifDate: date(2024, 1, 1),
                                         thumbnailData: nil, player: player, context: ctx)
        let skipped = StagedPhoto.create(phAssetID: "skipped", exifDate: date(2023, 1, 1),
                                          thumbnailData: nil, player: player, context: ctx)
        skipped.status = StagedPhotoStatus.skipped.rawValue
        try ctx.save()

        let results = try ctx.fetch(StagedPhoto.pendingRequest(for: player))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].phAssetLocalIdentifier, "pending")
        _ = pending
    }

    func testPostedPhotosAreExcludedFromQueue() throws {
        let posted = StagedPhoto.create(phAssetID: "posted", exifDate: date(2022, 5, 5),
                                         thumbnailData: nil, player: player, context: ctx)
        posted.status = StagedPhotoStatus.posted.rawValue
        _ = StagedPhoto.create(phAssetID: "pending", exifDate: date(2024, 5, 5),
                                thumbnailData: nil, player: player, context: ctx)
        try ctx.save()

        let results = try ctx.fetch(StagedPhoto.pendingRequest(for: player))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].phAssetLocalIdentifier, "pending")
    }

    func testNextToPostIsAlwaysOldest() throws {
        let dates = [date(2024,3,1), date(2021,6,15), date(2023,11,30), date(2022,1,1)]
        for d in dates {
            _ = StagedPhoto.create(phAssetID: UUID().uuidString, exifDate: d,
                                   thumbnailData: nil, player: player, context: ctx)
        }
        try ctx.save()

        let results = try ctx.fetch(StagedPhoto.pendingRequest(for: player))
        XCTAssertEqual(results.first?.exifDate, date(2021, 6, 15),
                       "Next-to-post must always be the photo with the oldest EXIF date")
    }

    // MARK: - Helpers

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }
}
