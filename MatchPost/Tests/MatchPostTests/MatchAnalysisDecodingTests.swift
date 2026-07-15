import XCTest
@testable import MatchPost

final class MatchAnalysisDecodingTests: XCTestCase {
    func testFullDecoding() throws {
        let json = """
        {
          "homeTeam": "Ajax",
          "awayTeam": "Feyenoord",
          "stadium": "Johan Cruyff Arena",
          "clockTime": "67'",
          "visibleScore": {"home": 1, "away": 0},
          "recognizedPlayers": [{"name": "Brian Brobbey", "jerseyNumber": 9}],
          "confidence": 0.92
        }
        """.data(using: .utf8)!
        let analysis = try JSONDecoder().decode(MatchAnalysis.self, from: json)
        XCTAssertEqual(analysis.homeTeam, "Ajax")
        XCTAssertEqual(analysis.awayTeam, "Feyenoord")
        XCTAssertEqual(analysis.stadium, "Johan Cruyff Arena")
        XCTAssertEqual(analysis.clockTime, "67'")
        XCTAssertEqual(analysis.visibleScore?.home, 1)
        XCTAssertEqual(analysis.visibleScore?.away, 0)
        XCTAssertEqual(analysis.recognizedPlayers.first?.name, "Brian Brobbey")
        XCTAssertEqual(analysis.recognizedPlayers.first?.jerseyNumber, 9)
        XCTAssertTrue(analysis.isHighConfidence)
    }

    func testNullableFieldsDecoding() throws {
        let json = """
        {"homeTeam":"FC Utrecht","awayTeam":"SC Cambuur","stadium":null,
         "clockTime":null,"visibleScore":null,"recognizedPlayers":[],"confidence":0.55}
        """.data(using: .utf8)!
        let analysis = try JSONDecoder().decode(MatchAnalysis.self, from: json)
        XCTAssertNil(analysis.stadium)
        XCTAssertNil(analysis.clockTime)
        XCTAssertNil(analysis.visibleScore)
        XCTAssertTrue(analysis.recognizedPlayers.isEmpty)
        XCTAssertFalse(analysis.isHighConfidence)
    }

    func testInstagramPostCharacterLimit() {
        let post = InstagramPost(
            caption: String(repeating: "A", count: 2100),
            hashtags: Array(repeating: "tag", count: 30),
            score: "2–1"
        )
        XCTAssertTrue(post.isOverLimit)
    }

    func testInstagramPostUnderLimit() {
        let post = InstagramPost(
            caption: "Wat een wedstrijd! Great game today.",
            hashtags: ["Ajax", "voetbal", "U14"],
            score: "3–1"
        )
        XCTAssertFalse(post.isOverLimit)
        XCTAssertTrue(post.fullCaption.contains("#Ajax"))
    }
}
