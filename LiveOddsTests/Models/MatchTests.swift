import XCTest
@testable import LiveOdds

final class MatchTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_init_setsPropertiesCorrectly() {
        // Given
        let matchID = 1001
        let teamA = "Eagles"
        let teamB = "Tigers"
        let startTime = Date()

        // When
        let match = Match(
            matchID: matchID,
            teamA: teamA,
            teamB: teamB,
            startTime: startTime
        )

        // Then
        XCTAssertEqual(match.matchID, matchID)
        XCTAssertEqual(match.teamA, teamA)
        XCTAssertEqual(match.teamB, teamB)
        XCTAssertEqual(match.startTime, startTime)
    }

    func test_id_returnsMatchID() {
        // Given
        let match = Match(
            matchID: 1001,
            teamA: "Eagles",
            teamB: "Tigers",
            startTime: Date()
        )

        // Then
        XCTAssertEqual(match.id, match.matchID)
    }

    // MARK: - Codable Tests

    func test_encode_decode_roundTrip() throws {
        // Given
        let originalMatch = Match(
            matchID: 1001,
            teamA: "Eagles",
            teamB: "Tigers",
            startTime: Date(timeIntervalSince1970: 1700000000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let data = try encoder.encode(originalMatch)
        let decodedMatch = try decoder.decode(Match.self, from: data)

        // Then
        XCTAssertEqual(decodedMatch, originalMatch)
    }

    func test_decode_fromJSONWithISO8601Date() throws {
        // Given
        let json = """
        {
            "matchID": 1001,
            "teamA": "Eagles",
            "teamB": "Tigers",
            "startTime": "2026-02-20T13:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let match = try decoder.decode(Match.self, from: json)

        // Then
        XCTAssertEqual(match.matchID, 1001)
        XCTAssertEqual(match.teamA, "Eagles")
        XCTAssertEqual(match.teamB, "Tigers")
        XCTAssertNotNil(match.startTime)
    }

    // MARK: - Equatable Tests

    func test_equality_whenPropertiesMatch_returnsTrue() {
        // Given
        let date = Date()
        let match1 = Match(matchID: 1001, teamA: "Eagles", teamB: "Tigers", startTime: date)
        let match2 = Match(matchID: 1001, teamA: "Eagles", teamB: "Tigers", startTime: date)

        // Then
        XCTAssertEqual(match1, match2)
    }

    func test_equality_whenPropertiesDiffer_returnsFalse() {
        // Given
        let date = Date()
        let match1 = Match(matchID: 1001, teamA: "Eagles", teamB: "Tigers", startTime: date)
        let match2 = Match(matchID: 1002, teamA: "Eagles", teamB: "Tigers", startTime: date)

        // Then
        XCTAssertNotEqual(match1, match2)
    }

    // MARK: - Sendable Tests

    func test_canBeUsedAcrossActorBoundaries() async {
        // Given
        let match = Match(
            matchID: 1001,
            teamA: "Eagles",
            teamB: "Tigers",
            startTime: Date()
        )

        // When - passing match across actor boundary
        let result = await Task.detached {
            // This would fail to compile if Match wasn't Sendable
            return match.matchID
        }.value

        // Then
        XCTAssertEqual(result, 1001)
    }
}
