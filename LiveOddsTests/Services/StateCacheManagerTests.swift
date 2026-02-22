import XCTest
@testable import LiveOdds

final class StateCacheManagerTests: XCTestCase {

    var sut: StateCacheManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = StateCacheManager.shared
        await sut.invalidate() // Clean state before each test
    }

    override func tearDown() async throws {
        await sut.invalidate()
        sut = nil
        try await super.tearDown()
    }

    // MARK: - cache Tests

    func test_cache_storesSnapshot() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 10)

        // When
        await sut.cache(snapshot)

        // Then
        let hasCache = await sut.hasCache
        XCTAssertTrue(hasCache)
    }

    // MARK: - retrieve Tests

    func test_retrieve_returnsStoredSnapshot() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 10)
        await sut.cache(snapshot)

        // When
        let retrieved = await sut.retrieve()

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.matchCount, 10)
    }

    func test_retrieve_withNoCache_returnsNil() async {
        // Given
        await sut.invalidate()

        // When
        let retrieved = await sut.retrieve()

        // Then
        XCTAssertNil(retrieved)
    }

    // MARK: - invalidate Tests

    func test_invalidate_clearsCache() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 10)
        await sut.cache(snapshot)

        // When
        await sut.invalidate()

        // Then
        let hasCache = await sut.hasCache
        XCTAssertFalse(hasCache)
        let retrieved = await sut.retrieve()
        XCTAssertNil(retrieved)
    }

    // MARK: - Overwrite Tests

    func test_cache_overwritesPreviousSnapshot() async {
        // Given
        let snapshot1 = MockDataFactory.makeSnapshot(matchCount: 10)
        let snapshot2 = MockDataFactory.makeSnapshot(matchCount: 20)
        await sut.cache(snapshot1)

        // When
        await sut.cache(snapshot2)

        // Then
        let retrieved = await sut.retrieve()
        XCTAssertEqual(retrieved?.matchCount, 20)
    }

    // MARK: - hasCache Tests

    func test_hasCache_returnsTrue_afterCache() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 5)

        // When
        await sut.cache(snapshot)

        // Then
        let hasCache = await sut.hasCache
        XCTAssertTrue(hasCache)
    }

    func test_hasCache_returnsFalse_afterInvalidate() async {
        // Given
        let snapshot = MockDataFactory.makeSnapshot(matchCount: 5)
        await sut.cache(snapshot)

        // When
        await sut.invalidate()

        // Then
        let hasCache = await sut.hasCache
        XCTAssertFalse(hasCache)
    }

    func test_hasCache_returnsFalse_initially() async {
        // Given
        await sut.invalidate()

        // Then
        let hasCache = await sut.hasCache
        XCTAssertFalse(hasCache)
    }

    // MARK: - Empty Snapshot Tests

    func test_cache_withEmptySnapshot_works() async {
        // Given
        let emptySnapshot = MockDataFactory.makeSnapshot(matchCount: 0)

        // When
        await sut.cache(emptySnapshot)

        // Then
        let hasCache = await sut.hasCache
        XCTAssertTrue(hasCache)
        let retrieved = await sut.retrieve()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.matchCount, 0)
    }
}
