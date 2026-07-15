import XCTest
@testable import MatchPost

final class PhotoGrouperTests: XCTestCase {

    private func candidate(_ id: String, minutesAfterNoon: Int?) -> StagingCandidate {
        let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 9, hour: 12))!
        let date = minutesAfterNoon.map { noon.addingTimeInterval(Double($0) * 60) }
        return StagingCandidate(id: id, exifDate: date, thumbnailData: nil)
    }

    func testPhotosWithinTwoHoursFormOneGroup() {
        let groups = PhotoGrouper.group([
            candidate("a", minutesAfterNoon: 0),
            candidate("b", minutesAfterNoon: 45),
            candidate("c", minutesAfterNoon: 90),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].map(\.id), ["a", "b", "c"])
    }

    func testGapOverTwoHoursSplitsGroups() {
        let groups = PhotoGrouper.group([
            candidate("morning", minutesAfterNoon: 0),
            candidate("evening", minutesAfterNoon: 300),   // 5h later
        ])
        XCTAssertEqual(groups.count, 2)
    }

    func testSlidingWindowChainsAcrossLongSession() {
        // First-to-last is 3h, but consecutive gaps are all < 2h → one group
        let groups = PhotoGrouper.group([
            candidate("kickoff",  minutesAfterNoon: 0),
            candidate("halftime", minutesAfterNoon: 100),
            candidate("fulltime", minutesAfterNoon: 180),
        ])
        XCTAssertEqual(groups.count, 1)
    }

    func testUnsortedInputIsSortedByDate() {
        let groups = PhotoGrouper.group([
            candidate("late",  minutesAfterNoon: 60),
            candidate("early", minutesAfterNoon: 0),
        ])
        XCTAssertEqual(groups[0].map(\.id), ["early", "late"])
    }

    func testUndatedPhotosBecomeSoloGroups() {
        let groups = PhotoGrouper.group([
            candidate("dated",    minutesAfterNoon: 0),
            candidate("nodate-1", minutesAfterNoon: nil),
            candidate("nodate-2", minutesAfterNoon: nil),
        ])
        XCTAssertEqual(groups.count, 3)
    }
}

final class HomeVenueLocatorTests: XCTestCase {

    override func tearDown() {
        HomeVenueLocator.reset()
        super.tearDown()
    }

    func testPhotoInsideRadiusIsHome() {
        HomeVenueLocator.venues = [HomeVenue(name: "TestClub", latitude: 51.4483, longitude: 5.4416)]
        // ~300 m north of the venue
        let venue = HomeVenueLocator.homeVenue(latitude: 51.4510, longitude: 5.4416)
        XCTAssertEqual(venue?.name, "TestClub")
    }

    func testPhotoOutsideRadiusIsAway() {
        HomeVenueLocator.venues = [HomeVenue(name: "TestClub", latitude: 51.4483, longitude: 5.4416)]
        // ~5 km away
        XCTAssertNil(HomeVenueLocator.homeVenue(latitude: 51.4933, longitude: 5.4416))
    }

    func testZeroCoordinateIsUnknownNotAway() {
        XCTAssertNil(HomeVenueLocator.homeVenue(latitude: 0, longitude: 0))
    }
}
