import XCTest
@testable import LiveOdds

final class OddsTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_init_setsPropertiesCorrectly() {
        // Given
        let matchID = 1001
        let teamAOdds = 1.95
        let teamBOdds = 2.10

        // When
        let odds = Odds(
            matchID: matchID,
            teamAOdds: teamAOdds,
            teamBOdds: teamBOdds
        )

        // Then
        XCTAssertEqual(odds.matchID, matchID)
        XCTAssertEqual(odds.teamAOdds, teamAOdds)
        XCTAssertEqual(odds.teamBOdds, teamBOdds)
    }

    // MARK: - Format Tests

    func test_format_withValue_returns2DecimalPrecision() {
        // Given
        let value = 1.9567

        // When
        let result = Odds.format(value)

        // Then
        XCTAssertEqual(result, "1.96")
    }

    func test_format_withNil_returnsPlaceholder() {
        // Given
        let value: Double? = nil

        // When
        let result = Odds.format(value)

        // Then
        XCTAssertEqual(result, "--")
    }

    func test_format_withExactValue_returnsFormattedString() {
        // Given
        let value = 1.95

        // When
        let result = Odds.format(value)

        // Then
        XCTAssertEqual(result, "1.95")
    }

    func test_format_withMinimumBoundary_returnsCorrectFormat() {
        // Given
        let value = 1.01

        // When
        let result = Odds.format(value)

        // Then
        XCTAssertEqual(result, "1.01")
    }

    func test_format_withMaximumBoundary_returnsCorrectFormat() {
        // Given
        let value = 99.00

        // When
        let result = Odds.format(value)

        // Then
        XCTAssertEqual(result, "99.00")
    }

    func test_format_withWholeNumber_includesDecimals() {
        // Given
        let value = 2.0

        // When
        let result = Odds.format(value)

        // Then
        XCTAssertEqual(result, "2.00")
    }

    func test_placeholder_returnsDoubleDash() {
        // Then
        XCTAssertEqual(Odds.placeholder, "--")
    }

    // MARK: - isValid Tests

    func test_isValid_withinRange_returnsTrue() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)

        // Then
        XCTAssertTrue(odds.isValid)
    }

    func test_isValid_atMinimumBoundary_returnsTrue() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 1.01, teamBOdds: 1.01)

        // Then
        XCTAssertTrue(odds.isValid)
    }

    func test_isValid_atMaximumBoundary_returnsTrue() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 99.0, teamBOdds: 99.0)

        // Then
        XCTAssertTrue(odds.isValid)
    }

    func test_isValid_teamABelowMinimum_returnsFalse() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 0.99, teamBOdds: 2.10)

        // Then
        XCTAssertFalse(odds.isValid)
    }

    func test_isValid_teamBBelowMinimum_returnsFalse() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 1.00)

        // Then
        XCTAssertFalse(odds.isValid)
    }

    func test_isValid_teamAAboveMaximum_returnsFalse() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 100.0, teamBOdds: 2.10)

        // Then
        XCTAssertFalse(odds.isValid)
    }

    func test_isValid_teamBAboveMaximum_returnsFalse() {
        // Given
        let odds = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 99.01)

        // Then
        XCTAssertFalse(odds.isValid)
    }

    // MARK: - Codable Tests

    func test_encode_decode_roundTrip() throws {
        // Given
        let originalOdds = Odds(
            matchID: 1001,
            teamAOdds: 1.95,
            teamBOdds: 2.10
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // When
        let data = try encoder.encode(originalOdds)
        let decodedOdds = try decoder.decode(Odds.self, from: data)

        // Then
        XCTAssertEqual(decodedOdds, originalOdds)
    }

    func test_decode_fromJSON() throws {
        // Given
        let json = """
        {
            "matchID": 1001,
            "teamAOdds": 1.95,
            "teamBOdds": 2.10
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        // When
        let odds = try decoder.decode(Odds.self, from: json)

        // Then
        XCTAssertEqual(odds.matchID, 1001)
        XCTAssertEqual(odds.teamAOdds, 1.95)
        XCTAssertEqual(odds.teamBOdds, 2.10)
    }

    // MARK: - Equatable Tests

    func test_equality_whenPropertiesMatch_returnsTrue() {
        // Given
        let odds1 = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)
        let odds2 = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)

        // Then
        XCTAssertEqual(odds1, odds2)
    }

    func test_equality_whenMatchIDsDiffer_returnsFalse() {
        // Given
        let odds1 = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)
        let odds2 = Odds(matchID: 1002, teamAOdds: 1.95, teamBOdds: 2.10)

        // Then
        XCTAssertNotEqual(odds1, odds2)
    }

    func test_equality_whenTeamAOddsDiffer_returnsFalse() {
        // Given
        let odds1 = Odds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)
        let odds2 = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.10)

        // Then
        XCTAssertNotEqual(odds1, odds2)
    }

    // MARK: - Sendable Tests

    func test_canBeUsedAcrossActorBoundaries() async {
        // Given
        let odds = Odds(
            matchID: 1001,
            teamAOdds: 1.95,
            teamBOdds: 2.10
        )

        // When - passing odds across actor boundary
        let result = await Task.detached {
            // This would fail to compile if Odds wasn't Sendable
            return odds.matchID
        }.value

        // Then
        XCTAssertEqual(result, 1001)
    }
}
