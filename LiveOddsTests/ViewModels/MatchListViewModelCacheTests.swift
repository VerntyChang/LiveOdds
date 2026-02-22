import XCTest
@testable import LiveOdds

@MainActor
final class MatchListViewModelCacheTests: XCTestCase {

    var cacheManager: StateCacheManager!

    override func setUp() async throws {
        try await super.setUp()
        cacheManager = StateCacheManager.shared
        await cacheManager.invalidate() // Clean state before each test
    }

    override func tearDown() async throws {
        await cacheManager.invalidate()
        cacheManager = nil
        try await super.tearDown()
    }

    // MARK: - loadData with Cache Tests

    func test_loadData_withCache_restoresFromSnapshot() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 50)
        await cacheManager.cache(snapshot)

        let mockAPI = MockAPIService()
        let sut = MatchListViewModel(
            apiService: mockAPI,
            cacheManager: cacheManager
        )

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.viewState, .loaded)
        let count = await sut.numberOfMatches()
        XCTAssertEqual(count, 50)
    }

    func test_loadData_withCache_skipsAPICall() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 30)
        await cacheManager.cache(snapshot)

        let mockAPI = MockAPIService()
        let sut = MatchListViewModel(
            apiService: mockAPI,
            cacheManager: cacheManager
        )

        // When
        await sut.loadData()

        // Then - API should not have been called (verify via state)
        XCTAssertEqual(sut.viewState, .loaded)
        // Match count should match cached snapshot, not API default
        let count = await sut.numberOfMatches()
        XCTAssertEqual(count, 30)
    }

    func test_loadData_withoutCache_fetchesFromAPI() async {
        // Given
        await cacheManager.invalidate()

        let mockAPI = MockAPIService()
        let sut = MatchListViewModel(
            apiService: mockAPI,
            cacheManager: cacheManager
        )

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.viewState, .loaded)
        let count = await sut.numberOfMatches()
        XCTAssertEqual(count, 100) // MockAPIService default
    }

    func test_loadData_withoutCache_cachesDataAfterLoad() async {
        // Given
        await cacheManager.invalidate()
        var hasCache = await cacheManager.hasCache
        XCTAssertFalse(hasCache)

        let mockAPI = MockAPIService()
        let sut = MatchListViewModel(
            apiService: mockAPI,
            cacheManager: cacheManager
        )

        // When
        await sut.loadData()

        // Then
        hasCache = await cacheManager.hasCache
        XCTAssertTrue(hasCache)
    }

    // MARK: - cacheCurrentState Tests

    func test_cacheCurrentState_storesSnapshot() async {
        // Given
        await cacheManager.invalidate()

        let mockAPI = MockAPIService()
        let sut = MatchListViewModel(
            apiService: mockAPI,
            cacheManager: cacheManager
        )

        // Load data first
        await sut.loadData()

        // Invalidate to test cacheCurrentState separately
        await cacheManager.invalidate()
        var hasCache = await cacheManager.hasCache
        XCTAssertFalse(hasCache)

        // When
        await sut.cacheCurrentState()

        // Then
        hasCache = await cacheManager.hasCache
        XCTAssertTrue(hasCache)
        let retrieved = await cacheManager.retrieve()
        XCTAssertEqual(retrieved?.matchCount, 100)
    }

    // MARK: - Empty State Tests

    func test_loadData_withEmptyCache_setsEmptyState() async {
        // Given
        let emptySnapshot = MockDataFactory.makeSnapshot(matchCount: 0)
        await cacheManager.cache(emptySnapshot)

        let mockAPI = MockAPIService()
        let sut = MatchListViewModel(
            apiService: mockAPI,
            cacheManager: cacheManager
        )

        // When
        await sut.loadData()

        // Then
        XCTAssertEqual(sut.viewState, .empty)
    }
}
