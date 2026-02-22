import XCTest
@testable import LiveOdds

final class MatchesStoreTests: XCTestCase {

    // MARK: - Initial State Tests

    func test_initialState_matchCountIsZero() async {
        // Given
        let store = MatchesStore()

        // When
        let count = await store.matchCount

        // Then
        XCTAssertEqual(count, 0)
    }

    func test_initialState_sortedMatchesIsEmpty() async {
        // Given
        let store = MatchesStore()

        // When
        let matches = await store.testSortedMatches

        // Then
        XCTAssertTrue(matches.isEmpty)
    }

    // MARK: - Bootstrap Tests

    func test_bootstrap_setsMatchCount() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 10)

        // When
        await store.bootstrap(matches: matches)

        // Then
        let count = await store.matchCount
        XCTAssertEqual(count, 10)
    }

    func test_bootstrap_sortsMatchesByStartTimeAscending() async {
        // Given
        let store = MatchesStore()
        let now = Date()

        let match1 = MockDataFactory.makeMatch(matchID: 1001, startTime: now.addingTimeInterval(3600)) // +1h
        let match2 = MockDataFactory.makeMatch(matchID: 1002, startTime: now.addingTimeInterval(7200)) // +2h
        let match3 = MockDataFactory.makeMatch(matchID: 1003, startTime: now.addingTimeInterval(1800)) // +30m (earliest)

        // When
        await store.bootstrap(matches: [match1, match2, match3])

        // Then
        let sortedMatches = await store.testSortedMatches
        XCTAssertEqual(sortedMatches[0].matchID, 1003) // earliest first
        XCTAssertEqual(sortedMatches[1].matchID, 1001)
        XCTAssertEqual(sortedMatches[2].matchID, 1002)
    }

    func test_bootstrap_withEmptyArray_resultsInZeroMatches() async {
        // Given
        let store = MatchesStore()

        // When
        await store.bootstrap(matches: [])

        // Then
        let count = await store.matchCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - Match At Index Tests

    func test_matchAtIndex_returnsCorrectMatch() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 5)
        await store.bootstrap(matches: matches)

        // When
        let match = await store.match(at: 0)

        // Then
        XCTAssertNotNil(match)
    }

    func test_matchAtIndex_whenOutOfBounds_returnsNil() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 5)
        await store.bootstrap(matches: matches)

        // When
        let match = await store.match(at: 100)

        // Then
        XCTAssertNil(match)
    }

    func test_matchAtIndex_whenNegativeIndex_returnsNil() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 5)
        await store.bootstrap(matches: matches)

        // When
        let match = await store.match(at: -1)

        // Then
        XCTAssertNil(match)
    }

    // MARK: - Index For MatchID Tests

    func test_indexForMatchID_returnsCorrectIndex() async {
        // Given
        let store = MatchesStore()
        let now = Date()
        let match = MockDataFactory.makeMatch(matchID: 1001, startTime: now)
        await store.bootstrap(matches: [match])

        // When
        let index = await store.index(for: 1001)

        // Then
        XCTAssertEqual(index, 0)
    }

    func test_indexForMatchID_whenNotFound_returnsNil() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 5)
        await store.bootstrap(matches: matches)

        // When
        let index = await store.index(for: 9999)

        // Then
        XCTAssertNil(index)
    }

    func test_indexForMatchID_reflectsSortOrder() async {
        // Given
        let store = MatchesStore()
        let now = Date()

        let match1 = MockDataFactory.makeMatch(matchID: 1001, startTime: now.addingTimeInterval(3600)) // later
        let match2 = MockDataFactory.makeMatch(matchID: 1002, startTime: now.addingTimeInterval(1800)) // earlier

        await store.bootstrap(matches: [match1, match2])

        // When/Then
        let indexForMatch1 = await store.index(for: 1001)
        let indexForMatch2 = await store.index(for: 1002)

        XCTAssertEqual(indexForMatch2, 0) // earlier match is at index 0
        XCTAssertEqual(indexForMatch1, 1) // later match is at index 1
    }

    // MARK: - Reset Tests

    func test_reset_clearsAllData() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 10)
        await store.bootstrap(matches: matches)

        // When
        await store.reset()

        // Then
        let count = await store.matchCount
        let sortedMatches = await store.testSortedMatches
        XCTAssertEqual(count, 0)
        XCTAssertTrue(sortedMatches.isEmpty)
    }

    func test_reset_clearsIndexMapping() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        await store.bootstrap(matches: [match])

        // When
        await store.reset()

        // Then
        let index = await store.index(for: 1001)
        XCTAssertNil(index)
    }

    // MARK: - Thread Safety Tests

    func test_concurrentAccess_maintainsDataIntegrity() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 100)
        await store.bootstrap(matches: matches)

        // When - perform many concurrent reads
        await withTaskGroup(of: Match?.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await store.match(at: i % 100)
                }
            }

            // Collect results
            var results: [Match?] = []
            for await result in group {
                results.append(result)
            }

            // Then
            XCTAssertEqual(results.count, 100)
            XCTAssertTrue(results.allSatisfy { $0 != nil })
        }
    }

    // MARK: - Odds Storage Tests

    func test_bootstrap_storesOdds() async {
        // Given
        let store = MatchesStore()
        let matches = [MockDataFactory.makeMatch(matchID: 1001)]
        let odds = [MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)]

        // When
        await store.bootstrap(matches: matches, oddsList: odds)

        // Then
        let storedOdds = await store.odds(for: 1001)
        XCTAssertEqual(storedOdds?.teamAOdds, 1.95)
        XCTAssertEqual(storedOdds?.teamBOdds, 2.10)
    }

    func test_odds_forMissingMatch_returnsNil() async {
        // Given
        let store = MatchesStore()
        let matches = [MockDataFactory.makeMatch(matchID: 1001)]
        let odds: [Odds] = []  // No odds

        await store.bootstrap(matches: matches, oddsList: odds)

        // When
        let storedOdds = await store.odds(for: 1001)

        // Then
        XCTAssertNil(storedOdds)
    }

    func test_odds_forUnknownMatchID_returnsNil() async {
        // Given
        let store = MatchesStore()
        let matches = [MockDataFactory.makeMatch(matchID: 1001)]
        let odds = [MockDataFactory.makeOdds(matchID: 1001)]

        await store.bootstrap(matches: matches, oddsList: odds)

        // When
        let storedOdds = await store.odds(for: 9999)

        // Then
        XCTAssertNil(storedOdds)
    }

    func test_matchWithOdds_returnsBothValues() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let odds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 1.95, teamBOdds: 2.10)

        await store.bootstrap(matches: [match], oddsList: [odds])

        // When
        let result = await store.matchWithOdds(at: 0)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.match.matchID, 1001)
        XCTAssertNotNil(result?.odds)
        XCTAssertEqual(result?.odds?.teamAOdds, 1.95)
    }

    func test_matchWithOdds_whenNoOdds_returnsMatchWithNilOdds() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)

        await store.bootstrap(matches: [match], oddsList: [])

        // When
        let result = await store.matchWithOdds(at: 0)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.match.matchID, 1001)
        XCTAssertNil(result?.odds)
    }

    func test_matchWithOdds_whenIndexOutOfBounds_returnsNil() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)

        await store.bootstrap(matches: [match], oddsList: [])

        // When
        let result = await store.matchWithOdds(at: 100)

        // Then
        XCTAssertNil(result)
    }

    func test_reset_clearsOddsDict() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let odds = MockDataFactory.makeOdds(matchID: 1001)

        await store.bootstrap(matches: [match], oddsList: [odds])

        // When
        await store.reset()

        // Then
        let storedOdds = await store.odds(for: 1001)
        XCTAssertNil(storedOdds)
    }

    func test_bootstrap_withMultipleOdds_storesAll() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 3)
        let odds = MockDataFactory.makeOddsList(for: matches)

        // When
        await store.bootstrap(matches: matches, oddsList: odds)

        // Then
        for match in matches {
            let storedOdds = await store.odds(for: match.matchID)
            XCTAssertNotNil(storedOdds, "Odds should exist for matchID \(match.matchID)")
        }
    }

    // MARK: - Update Odds Tests (FR-3)

    func test_updateOdds_returnsCorrectRowIndex() async {
        // Given
        let store = MatchesStore()
        let now = Date()
        let matches = [
            MockDataFactory.makeMatch(matchID: 1001, startTime: now.addingTimeInterval(3600)),
            MockDataFactory.makeMatch(matchID: 1002, startTime: now),  // Earlier, so index 0
            MockDataFactory.makeMatch(matchID: 1003, startTime: now.addingTimeInterval(7200))
        ]
        let odds = MockDataFactory.makeOddsList(for: matches)
        await store.bootstrap(matches: matches, oddsList: odds)

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.50, teamBOdds: 1.80)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertEqual(changeResult?.rowIndex, 1)  // 1001 is second after sorting
    }

    func test_updateOdds_forNonExistentMatch_returnsNil() async {
        // Given
        let store = MatchesStore()
        await store.bootstrap(matches: [MockDataFactory.makeMatch(matchID: 1001)], oddsList: [])

        // When
        let newOdds = Odds(matchID: 9999, teamAOdds: 2.00, teamBOdds: 2.00)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNil(changeResult)
    }

    func test_updateOdds_storesNewOdds() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let initialOdds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        await store.bootstrap(matches: [match], oddsList: [initialOdds])

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.50, teamBOdds: 1.80)
        _ = await store.updateOdds(newOdds)

        // Then
        let storedOdds = await store.odds(for: 1001)
        XCTAssertEqual(storedOdds?.teamAOdds, 2.50)
        XCTAssertEqual(storedOdds?.teamBOdds, 1.80)
    }

    func test_updateOdds_withNoInitialOdds_storesOdds() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        await store.bootstrap(matches: [match], oddsList: [])  // No initial odds

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNotNil(changeResult)
        XCTAssertEqual(changeResult?.rowIndex, 0)
        let storedOdds = await store.odds(for: 1001)
        XCTAssertEqual(storedOdds?.teamAOdds, 2.00)
        XCTAssertEqual(storedOdds?.teamBOdds, 2.00)
    }

    // MARK: - Update Odds Change Direction Tests (FR-5)

    func test_updateOdds_returnsCorrectChangeDirections_whenOddsIncrease() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let initialOdds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 1.90, teamBOdds: 2.00)
        await store.bootstrap(matches: [match], oddsList: [initialOdds])

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.10)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNotNil(changeResult)
        XCTAssertEqual(changeResult?.teamADirection, .up)
        XCTAssertEqual(changeResult?.teamBDirection, .up)
    }

    func test_updateOdds_returnsCorrectChangeDirections_whenOddsDecrease() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let initialOdds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.10)
        await store.bootstrap(matches: [match], oddsList: [initialOdds])

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 1.90, teamBOdds: 2.00)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNotNil(changeResult)
        XCTAssertEqual(changeResult?.teamADirection, .down)
        XCTAssertEqual(changeResult?.teamBDirection, .down)
    }

    func test_updateOdds_returnsCorrectChangeDirections_mixedDirections() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let initialOdds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 1.90, teamBOdds: 2.10)
        await store.bootstrap(matches: [match], oddsList: [initialOdds])

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)  // A up, B down
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNotNil(changeResult)
        XCTAssertEqual(changeResult?.teamADirection, .up)
        XCTAssertEqual(changeResult?.teamBDirection, .down)
    }

    func test_updateOdds_returnsNoneDirection_whenNoInitialOdds() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        await store.bootstrap(matches: [match], oddsList: [])  // No initial odds

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNotNil(changeResult)
        XCTAssertEqual(changeResult?.teamADirection, Odds.ChangeDirection.none)
        XCTAssertEqual(changeResult?.teamBDirection, Odds.ChangeDirection.none)
    }

    func test_updateOdds_returnsNoneDirection_whenOddsUnchanged() async {
        // Given
        let store = MatchesStore()
        let match = MockDataFactory.makeMatch(matchID: 1001)
        let initialOdds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        await store.bootstrap(matches: [match], oddsList: [initialOdds])

        // When
        let newOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        let changeResult = await store.updateOdds(newOdds)

        // Then
        XCTAssertNotNil(changeResult)
        XCTAssertEqual(changeResult?.teamADirection, Odds.ChangeDirection.none)
        XCTAssertEqual(changeResult?.teamBDirection, Odds.ChangeDirection.none)
    }

    // MARK: - Get All Odds Tests

    func test_getAllOdds_returnsOddsDictionary() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 3)
        let odds = MockDataFactory.makeOddsList(for: matches)
        await store.bootstrap(matches: matches, oddsList: odds)

        // When
        let allOdds = await store.getAllOdds()

        // Then
        XCTAssertEqual(allOdds.count, 3)
    }

    func test_getAllMatchIDs_returnsAllIDs() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 5)
        await store.bootstrap(matches: matches, oddsList: [])

        // When
        let matchIDs = await store.getAllMatchIDs()

        // Then
        XCTAssertEqual(matchIDs.count, 5)
        for match in matches {
            XCTAssertTrue(matchIDs.contains(match.matchID))
        }
    }
}
