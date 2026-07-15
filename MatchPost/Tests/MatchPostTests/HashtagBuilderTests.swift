import XCTest
@testable import MatchPost

final class HashtagBuilderTests: XCTestCase {
    func testBasicTagGeneration() {
        let tags = HashtagBuilder.build(
            playerTeam: "Ajax",
            opponent: "Feyenoord",
            competition: "KNVB Beker",
            ageGroup: "U14",
            homeGoals: 2, awayGoals: 1,
            wasHome: true
        )
        XCTAssertTrue(tags.contains("Ajax"))
        XCTAssertTrue(tags.contains("AFC"))
        XCTAssertTrue(tags.contains("Feyenoord"))
        XCTAssertTrue(tags.contains("KNVBBeker"))
        XCTAssertTrue(tags.contains("U14"))
        XCTAssertTrue(tags.contains("Onder14"))
        XCTAssertTrue(tags.contains("2x1"))
        XCTAssertTrue(tags.contains("voetbal"))
    }

    func testMaxThirtyTags() {
        let tags = HashtagBuilder.build(
            playerTeam: "Some Very Long Club Name FC Amsterdam",
            opponent: "Another Club Name SC Rotterdam",
            competition: "Regional Youth Championship Northern Netherlands",
            ageGroup: "Under 14",
            homeGoals: 3, awayGoals: 0,
            wasHome: false
        )
        XCTAssertLessThanOrEqual(tags.count, 30)
    }

    func testNoDuplicates() {
        let tags = HashtagBuilder.build(
            playerTeam: "Ajax", opponent: "Ajax",
            competition: nil, ageGroup: nil,
            homeGoals: 1, awayGoals: 1, wasHome: true
        )
        let unique = Set(tags)
        XCTAssertEqual(tags.count, unique.count)
    }

    func testNoHashSymbolInTags() {
        let tags = HashtagBuilder.build(
            playerTeam: "PSV", opponent: "AZ",
            competition: "Eredivisie Beloften",
            ageGroup: "U17",
            homeGoals: 0, awayGoals: 2, wasHome: false
        )
        XCTAssertFalse(tags.contains(where: { $0.hasPrefix("#") }))
    }

    func testCamelCaseConversion() {
        let tags = HashtagBuilder.build(
            playerTeam: "FC Utrecht", opponent: nil,
            competition: "Premier League Youth",
            ageGroup: nil, homeGoals: 1, awayGoals: 0, wasHome: true
        )
        XCTAssertTrue(tags.contains("FCUtrecht"))
        XCTAssertTrue(tags.contains("PremierLeagueYouth"))
    }
}
