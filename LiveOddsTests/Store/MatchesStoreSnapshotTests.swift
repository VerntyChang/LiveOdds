import XCTest
@testable import LiveOdds

final class MatchesStoreSnapshotTests: XCTestCase {

    // MARK: - createSnapshot Tests

    func test_createSnapshot_capturesCurrentState() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 50)
        let odds = MockDataFactory.makeOddsList(for: matches)
        await store.bootstrap(matches: matches, oddsList: odds)

        // When
        let snapshot = await store.createSnapshot()

        // Then
        XCTAssertEqual(snapshot.sortedMatches.count, 50)
        XCTAssertEqual(snapshot.oddsDict.count, 50)
        XCTAssertEqual(snapshot.idToIndex.count, 50)
    }

    func test_createSnapshot_withEmptyStore_returnsEmptySnapshot() async {
        // Given
        let store = MatchesStore()

        // When
        let snapshot = await store.createSnapshot()

        // Then
        XCTAssertEqual(snapshot.matchCount, 0)
        XCTAssertTrue(snapshot.sortedMatches.isEmpty)
        XCTAssertTrue(snapshot.oddsDict.isEmpty)
        XCTAssertTrue(snapshot.idToIndex.isEmpty)
    }

    func test_createSnapshot_capturesLatestOdds() async {
        // Given
        let store = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 1)
        let initialOdds = MockDataFactory.makeOdds(matchID: 1001, teamAOdds: 1.50, teamBOdds: 2.00)
        await store.bootstrap(matches: matches, oddsList: [initialOdds])

        // Update odds
        let updatedOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.50)
        _ = await store.updateOdds(updatedOdds)

        // When
        let snapshot = await store.createSnapshot()

        // Then
        XCTAssertEqual(snapshot.oddsDict[1001]?.teamAOdds, 2.00)
        XCTAssertEqual(snapshot.oddsDict[1001]?.teamBOdds, 2.50)
    }

    func test_createSnapshot_setsTimestamp() async {
        // Given
        let store = MatchesStore()
        let before = Date()

        // When
        let snapshot = await store.createSnapshot()
        let after = Date()

        // Then
        XCTAssertGreaterThanOrEqual(snapshot.createdAt, before)
        XCTAssertLessThanOrEqual(snapshot.createdAt, after)
    }

    // MARK: - restore Tests

    func test_restore_populatesStoreFromSnapshot() async {
        // Given
        let store = MatchesStore()
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 100)

        // When
        await store.restore(from: snapshot)

        // Then
        let count = await store.matchCount
        XCTAssertEqual(count, 100)
    }

    func test_restore_maintainsSortOrder() async {
        // Given
        let store = MatchesStore()
        let now = Date()
        let matches = [
            Match(matchID: 1, teamA: "A", teamB: "B", startTime: now.addingTimeInterval(3600)),
            Match(matchID: 2, teamA: "C", teamB: "D", startTime: now),  // Earliest
            Match(matchID: 3, teamA: "E", teamB: "F", startTime: now.addingTimeInterval(7200))
        ]
        // Pre-sort for snapshot
        let sortedMatches = matches.sorted { $0.startTime < $1.startTime }
        let idToIndex = Dictionary(uniqueKeysWithValues: sortedMatches.enumerated().map { ($1.matchID, $0) })

        let snapshot = StoreSnapshot(
            sortedMatches: sortedMatches,
            oddsDict: [:],
            idToIndex: idToIndex,
            createdAt: Date()
        )

        // When
        await store.restore(from: snapshot)

        // Then
        let first = await store.match(at: 0)
        XCTAssertEqual(first?.matchID, 2) // Earliest should be first
    }

    func test_restore_restoresOdds() async {
        // Given
        let store = MatchesStore()
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 10)

        // When
        await store.restore(from: snapshot)

        // Then
        for match in snapshot.sortedMatches {
            let odds = await store.odds(for: match.matchID)
            XCTAssertNotNil(odds, "Odds for matchID \(match.matchID) should be restored")
        }
    }

    func test_restore_restoresIndexMapping() async {
        // Given
        let store = MatchesStore()
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 10)

        // When
        await store.restore(from: snapshot)

        // Then
        for (index, match) in snapshot.sortedMatches.enumerated() {
            let restoredIndex = await store.index(for: match.matchID)
            XCTAssertEqual(restoredIndex, index)
        }
    }

    func test_restore_performance() async {
        // Given
        let store = MatchesStore()
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 100)

        // When
        let start = CFAbsoluteTimeGetCurrent()
        await store.restore(from: snapshot)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        // Then
        XCTAssertLessThan(elapsed, 100, "Restore exceeded 100ms target: \(elapsed)ms")
    }

    // MARK: - Roundtrip Tests

    func test_createSnapshot_thenRestore_preservesData() async {
        // Given
        let originalStore = MatchesStore()
        let matches = MockDataFactory.makeMatches(count: 25)
        let odds = MockDataFactory.makeOddsList(for: matches)
        await originalStore.bootstrap(matches: matches, oddsList: odds)

        // When - create snapshot and restore to new store
        let snapshot = await originalStore.createSnapshot()
        let newStore = MatchesStore()
        await newStore.restore(from: snapshot)

        // Then - verify data matches
        let originalCount = await originalStore.matchCount
        let restoredCount = await newStore.matchCount
        XCTAssertEqual(restoredCount, originalCount)

        for index in 0..<originalCount {
            let originalMatch = await originalStore.match(at: index)
            let restoredMatch = await newStore.match(at: index)
            XCTAssertEqual(restoredMatch?.matchID, originalMatch?.matchID)
        }
    }
}
