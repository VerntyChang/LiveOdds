import XCTest
@testable import LiveOdds

final class StoreSnapshotTests: XCTestCase {

    // MARK: - matchCount Tests

    func test_matchCount_returnsCorrectValue() {
        // Given
        let matches = MockDataFactory.makeMatches(count: 50)
        let snapshot = StoreSnapshot(
            sortedMatches: matches,
            oddsDict: [:],
            idToIndex: [:],
            createdAt: Date()
        )

        // Then
        XCTAssertEqual(snapshot.matchCount, 50)
    }

    func test_matchCount_withEmptySnapshot_returnsZero() {
        // Given
        let snapshot = StoreSnapshot(
            sortedMatches: [],
            oddsDict: [:],
            idToIndex: [:],
            createdAt: Date()
        )

        // Then
        XCTAssertEqual(snapshot.matchCount, 0)
    }

    // MARK: - age Tests

    func test_age_increasesOverTime() async {
        // Given
        let snapshot = StoreSnapshot(
            sortedMatches: [],
            oddsDict: [:],
            idToIndex: [:],
            createdAt: Date()
        )

        // When
        try? await Task.sleep(for: .milliseconds(100))

        // Then
        XCTAssertGreaterThan(snapshot.age, 0.05)
    }

    func test_age_withOldDate_returnsCorrectAge() {
        // Given
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let snapshot = StoreSnapshot(
            sortedMatches: [],
            oddsDict: [:],
            idToIndex: [:],
            createdAt: oneHourAgo
        )

        // Then
        XCTAssertGreaterThan(snapshot.age, 3599)
        XCTAssertLessThan(snapshot.age, 3601)
    }

    // MARK: - Data Integrity Tests

    func test_snapshot_containsAllData() {
        // Given
        let matches = MockDataFactory.makeMatches(count: 10)
        let sortedMatches = matches.sorted { $0.startTime < $1.startTime }
        let odds = MockDataFactory.makeOddsList(for: matches)
        let oddsDict = Dictionary(uniqueKeysWithValues: odds.map { ($0.matchID, $0) })
        let idToIndex = Dictionary(uniqueKeysWithValues: sortedMatches.enumerated().map { ($1.matchID, $0) })
        let now = Date()

        // When
        let snapshot = StoreSnapshot(
            sortedMatches: sortedMatches,
            oddsDict: oddsDict,
            idToIndex: idToIndex,
            createdAt: now
        )

        // Then
        XCTAssertEqual(snapshot.sortedMatches.count, 10)
        XCTAssertEqual(snapshot.oddsDict.count, 10)
        XCTAssertEqual(snapshot.idToIndex.count, 10)
        XCTAssertEqual(snapshot.createdAt, now)
    }
}
