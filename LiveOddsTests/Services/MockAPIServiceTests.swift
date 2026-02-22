import XCTest
@testable import LiveOdds

final class MockAPIServiceTests: XCTestCase {

    // MARK: - Match Count Tests

    func test_fetchMatches_returnsCorrectMatchCount() async throws {
        // Given
        let expectedCount = 50
        let config = MockAPIService.Configuration(
            matchCount: expectedCount,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()

        // Then
        XCTAssertEqual(matches.count, expectedCount)
    }

    func test_fetchMatches_withDefaultConfig_returns100Matches() async throws {
        // Given
        let config = MockAPIService.Configuration(simulatedDelay: 0)
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()

        // Then
        XCTAssertEqual(matches.count, 100)
    }

    // MARK: - Match ID Tests

    func test_fetchMatches_generatesUniqueMatchIDs() async throws {
        // Given
        let config = MockAPIService.Configuration(matchCount: 100, simulatedDelay: 0)
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()
        let matchIDs = Set(matches.map(\.matchID))

        // Then
        XCTAssertEqual(matchIDs.count, matches.count, "All match IDs should be unique")
    }

    func test_fetchMatches_matchIDsStartAt1001() async throws {
        // Given
        let config = MockAPIService.Configuration(matchCount: 10, simulatedDelay: 0)
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()
        let sortedIDs = matches.map(\.matchID).sorted()

        // Then
        XCTAssertEqual(sortedIDs.first, 1001)
        XCTAssertEqual(sortedIDs.last, 1010)
    }

    // MARK: - Team Name Tests

    func test_fetchMatches_teamAAndTeamBAreDifferent() async throws {
        // Given
        let config = MockAPIService.Configuration(matchCount: 100, simulatedDelay: 0)
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()

        // Then
        for match in matches {
            XCTAssertNotEqual(
                match.teamA,
                match.teamB,
                "Team A and Team B should be different for match \(match.matchID)"
            )
        }
    }

    // MARK: - Start Time Tests

    func test_fetchMatches_startTimesAreWithinNext7Days() async throws {
        // Given
        let config = MockAPIService.Configuration(matchCount: 50, simulatedDelay: 0)
        let service = MockAPIService(configuration: config)
        let now = Date()
        let sevenDaysFromNow = now.addingTimeInterval(7 * 24 * 60 * 60)

        // When
        let matches = try await service.fetchMatches()

        // Then
        for match in matches {
            XCTAssertGreaterThanOrEqual(
                match.startTime,
                now.addingTimeInterval(-1), // Allow 1 second tolerance
                "Start time should be >= now for match \(match.matchID)"
            )
            XCTAssertLessThanOrEqual(
                match.startTime,
                sevenDaysFromNow.addingTimeInterval(1), // Allow 1 second tolerance
                "Start time should be <= 7 days from now for match \(match.matchID)"
            )
        }
    }

    // MARK: - Failure Mode Tests

    func test_fetchMatches_whenShouldFailIsTrue_throwsConfiguredError() async {
        // Given
        let expectedError = APIError.timeout
        let config = MockAPIService.Configuration(
            simulatedDelay: 0,
            shouldFail: true,
            failureError: expectedError
        )
        let service = MockAPIService(configuration: config)

        // When/Then
        do {
            _ = try await service.fetchMatches()
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_fetchMatches_whenShouldFailIsFalse_doesNotThrow() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 10,
            simulatedDelay: 0,
            shouldFail: false
        )
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()

        // Then
        XCTAssertEqual(matches.count, 10)
    }

    // MARK: - Simulated Delay Tests

    func test_fetchMatches_respectsSimulatedDelay() async throws {
        // Given
        let delayInSeconds: TimeInterval = 0.1
        let config = MockAPIService.Configuration(
            matchCount: 1,
            simulatedDelay: delayInSeconds
        )
        let service = MockAPIService(configuration: config)

        // When
        let startTime = Date()
        _ = try await service.fetchMatches()
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, delayInSeconds * 0.9) // Allow 10% tolerance
    }

    // MARK: - Zero Match Tests

    func test_fetchMatches_withZeroCount_returnsEmptyArray() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 0,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let matches = try await service.fetchMatches()

        // Then
        XCTAssertTrue(matches.isEmpty)
    }

    // MARK: - FetchOdds Tests

    func test_fetchOdds_returnsCorrectCount() async throws {
        // Given
        let expectedCount = 50
        let config = MockAPIService.Configuration(
            matchCount: expectedCount,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let odds = try await service.fetchOdds()

        // Then
        XCTAssertEqual(odds.count, expectedCount)
    }

    func test_fetchOdds_oddsAreWithinValidRange() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 100,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let odds = try await service.fetchOdds()

        // Then
        for odd in odds {
            XCTAssertGreaterThanOrEqual(odd.teamAOdds, 1.01, "Team A odds should be >= 1.01")
            XCTAssertLessThanOrEqual(odd.teamAOdds, 99.0, "Team A odds should be <= 99.0")
            XCTAssertGreaterThanOrEqual(odd.teamBOdds, 1.01, "Team B odds should be >= 1.01")
            XCTAssertLessThanOrEqual(odd.teamBOdds, 99.0, "Team B odds should be <= 99.0")
        }
    }

    func test_fetchOdds_whenShouldFailOddsIsTrue_throwsError() async {
        // Given
        let expectedError = APIError.timeout
        let config = MockAPIService.Configuration(
            simulatedDelay: 0,
            shouldFailOdds: true,
            failureError: expectedError
        )
        let service = MockAPIService(configuration: config)

        // When/Then
        do {
            _ = try await service.fetchOdds()
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            XCTAssertEqual(error.errorDescription, expectedError.errorDescription)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_fetchOdds_matchesWithMissingOdds_excludesConfiguredMatches() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 10,
            simulatedDelay: 0,
            matchesWithMissingOdds: [1001, 1005]
        )
        let service = MockAPIService(configuration: config)

        // When
        let odds = try await service.fetchOdds()

        // Then
        XCTAssertEqual(odds.count, 8) // 10 - 2 missing
        let matchIDs = Set(odds.map { $0.matchID })
        XCTAssertFalse(matchIDs.contains(1001))
        XCTAssertFalse(matchIDs.contains(1005))
    }

    func test_fetchOdds_respectsSimulatedDelay() async throws {
        // Given
        let delayInSeconds: TimeInterval = 0.1
        let config = MockAPIService.Configuration(
            matchCount: 1,
            simulatedDelayOdds: delayInSeconds
        )
        let service = MockAPIService(configuration: config)

        // When
        let startTime = Date()
        _ = try await service.fetchOdds()
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertGreaterThanOrEqual(elapsed, delayInSeconds * 0.9) // Allow 10% tolerance
    }

    func test_fetchOdds_generatesUniqueMatchIDs() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 50,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let odds = try await service.fetchOdds()
        let matchIDs = Set(odds.map { $0.matchID })

        // Then
        XCTAssertEqual(matchIDs.count, odds.count, "All match IDs should be unique")
    }

    func test_fetchOdds_matchIDsStartAt1001() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 5,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let odds = try await service.fetchOdds()
        let sortedIDs = odds.map { $0.matchID }.sorted()

        // Then
        XCTAssertEqual(sortedIDs.first, 1001)
        XCTAssertEqual(sortedIDs.last, 1005)
    }

    func test_fetchOdds_withZeroCount_returnsEmptyArray() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 0,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)

        // When
        let odds = try await service.fetchOdds()

        // Then
        XCTAssertTrue(odds.isEmpty)
    }

    // MARK: - Independent Failure Mode Tests

    func test_fetchMatches_fails_butFetchOdds_succeeds() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 10,
            simulatedDelay: 0,
            shouldFailMatches: true,
            shouldFailOdds: false
        )
        let service = MockAPIService(configuration: config)

        // Then - matches should fail
        do {
            _ = try await service.fetchMatches()
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }

        // And - odds should succeed
        let odds = try await service.fetchOdds()
        XCTAssertEqual(odds.count, 10)
    }

    func test_fetchOdds_fails_butFetchMatches_succeeds() async throws {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 10,
            simulatedDelay: 0,
            shouldFailMatches: false,
            shouldFailOdds: true
        )
        let service = MockAPIService(configuration: config)

        // Then - matches should succeed
        let matches = try await service.fetchMatches()
        XCTAssertEqual(matches.count, 10)

        // And - odds should fail
        do {
            _ = try await service.fetchOdds()
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
        }
    }
}
