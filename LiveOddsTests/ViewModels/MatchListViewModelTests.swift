import XCTest
import Combine
@testable import LiveOdds

final class MatchListViewModelTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    @MainActor
    func test_initialState_isIdle() {
        // Given
        let service = MockAPIService(configuration: .init(simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)

        // Then
        XCTAssertEqual(viewModel.viewState, .idle)
    }

    // MARK: - Loading State Tests

    @MainActor
    func test_loadData_setsLoadingState() async {
        // Given
        let service = MockAPIService(configuration: .init(matchCount: 10, simulatedDelay: 0.1))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        let expectation = XCTestExpectation(description: "Loading state observed")

        viewModel.$viewState
            .dropFirst() // Skip initial idle state
            .sink { state in
                if state == .loading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        Task {
            await viewModel.loadData()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Loaded State Tests

    @MainActor
    func test_loadData_onSuccess_setsLoadedState() async {
        // Given
        let service = MockAPIService(configuration: .init(matchCount: 10, simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        XCTAssertEqual(viewModel.viewState, .loaded)
    }

    @MainActor
    func test_loadData_onSuccess_populatesStore() async {
        // Given
        let expectedCount = 10
        let service = MockAPIService(configuration: .init(matchCount: expectedCount, simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        let count = await viewModel.numberOfMatches()
        XCTAssertEqual(count, expectedCount)
    }

    // MARK: - Empty State Tests

    @MainActor
    func test_loadData_withZeroMatches_setsEmptyState() async {
        // Given
        let service = MockAPIService(configuration: .init(matchCount: 0, simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        XCTAssertEqual(viewModel.viewState, .empty)
    }

    // MARK: - Error State Tests

    @MainActor
    func test_loadData_onFailure_setsErrorState() async {
        // Given
        let expectedError = APIError.timeout
        let service = MockAPIService(configuration: .init(
            simulatedDelay: 0,
            shouldFail: true,
            failureError: expectedError
        ))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        if case .error(let message) = viewModel.viewState {
            XCTAssertEqual(message, expectedError.localizedDescription)
        } else {
            XCTFail("Expected error state, got \(viewModel.viewState)")
        }
    }

    @MainActor
    func test_loadData_onNetworkError_providesUserFriendlyMessage() async {
        // Given
        let service = MockAPIService(configuration: .init(
            simulatedDelay: 0,
            shouldFail: true,
            failureError: .networkError(underlying: URLError(.notConnectedToInternet))
        ))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        if case .error(let message) = viewModel.viewState {
            XCTAssertEqual(message, "Unable to connect. Please check your connection.")
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Retry Tests

    @MainActor
    func test_retry_triggersNewLoad() async {
        // Given
        let service = MockAPIService(configuration: .init(matchCount: 5, simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.retry()

        // Then
        XCTAssertEqual(viewModel.viewState, .loaded)
        let count = await viewModel.numberOfMatches()
        XCTAssertEqual(count, 5)
    }

    // MARK: - Data Access Tests

    @MainActor
    func test_matchAtIndex_returnsCorrectMatch() async {
        // Given
        let service = MockAPIService(configuration: .init(matchCount: 5, simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)
        await viewModel.loadData()

        // When
        let match = await viewModel.match(at: 0)

        // Then
        XCTAssertNotNil(match)
    }

    @MainActor
    func test_matchAtIndex_withInvalidIndex_returnsNil() async {
        // Given
        let service = MockAPIService(configuration: .init(matchCount: 5, simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)
        await viewModel.loadData()

        // When
        let match = await viewModel.match(at: 100)

        // Then
        XCTAssertNil(match)
    }

    // MARK: - ViewState Equatable Tests

    func test_viewState_equatable() {
        // Then
        XCTAssertEqual(MatchListViewModel.ViewState.idle, .idle)
        XCTAssertEqual(MatchListViewModel.ViewState.loading, .loading)
        XCTAssertEqual(MatchListViewModel.ViewState.loaded, .loaded)
        XCTAssertEqual(MatchListViewModel.ViewState.empty, .empty)
        XCTAssertEqual(MatchListViewModel.ViewState.error("test"), .error("test"))
        XCTAssertNotEqual(MatchListViewModel.ViewState.error("a"), .error("b"))
        XCTAssertNotEqual(MatchListViewModel.ViewState.idle, .loading)
    }

    // MARK: - Parallel Loading Tests

    @MainActor
    func test_loadData_fetchesMatchesAndOddsInParallel() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 10,
            simulatedDelayMatches: 0.15,
            simulatedDelayOdds: 0.15
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)

        // When
        let startTime = Date()
        await viewModel.loadData()
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        // Parallel execution: elapsed should be ~0.15s, not ~0.30s (sequential)
        XCTAssertLessThan(elapsed, 0.25, "Parallel fetch should take ~0.15s, not ~0.30s")
        XCTAssertEqual(viewModel.viewState, .loaded)
    }

    @MainActor
    func test_loadData_oddsFails_matchesStillLoad() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 10,
            simulatedDelay: 0,
            shouldFailOdds: true
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then - matches should still load with graceful degradation
        XCTAssertEqual(viewModel.viewState, .loaded)
        let matchCount = await viewModel.numberOfMatches()
        XCTAssertEqual(matchCount, 10)
    }

    @MainActor
    func test_loadData_matchesFails_showsError() async {
        // Given
        let config = MockAPIService.Configuration(
            simulatedDelay: 0,
            shouldFailMatches: true
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        if case .error = viewModel.viewState {
            // Success - error state is expected
        } else {
            XCTFail("Expected error state, got \(viewModel.viewState)")
        }
    }

    @MainActor
    func test_loadData_bothSucceed_storesOdds() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 5,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)

        // When
        await viewModel.loadData()

        // Then
        XCTAssertEqual(viewModel.viewState, .loaded)

        // Verify odds are stored
        let odds = await viewModel.odds(for: 1001)
        XCTAssertNotNil(odds, "Odds should be stored for matchID 1001")
    }

    @MainActor
    func test_matchWithOdds_returnsCorrectData() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 5,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)
        await viewModel.loadData()

        // When
        let result = await viewModel.matchWithOdds(at: 0)

        // Then
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.match)
        XCTAssertNotNil(result?.odds)
    }

    @MainActor
    func test_matchWithOdds_whenOddsFailed_returnsMatchWithNilOdds() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 5,
            simulatedDelay: 0,
            shouldFailOdds: true
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)
        await viewModel.loadData()

        // When
        let result = await viewModel.matchWithOdds(at: 0)

        // Then
        XCTAssertNotNil(result)
        XCTAssertNotNil(result?.match)
        XCTAssertNil(result?.odds) // Odds should be nil due to failed fetch
    }

    @MainActor
    func test_odds_forMatchID_returnsCorrectOdds() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 3,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)
        await viewModel.loadData()

        // When
        let odds = await viewModel.odds(for: 1002)

        // Then
        XCTAssertNotNil(odds)
        XCTAssertEqual(odds?.matchID, 1002)
    }

    @MainActor
    func test_odds_forUnknownMatchID_returnsNil() async {
        // Given
        let config = MockAPIService.Configuration(
            matchCount: 3,
            simulatedDelay: 0
        )
        let service = MockAPIService(configuration: config)
        let viewModel = MatchListViewModel(apiService: service)
        await viewModel.loadData()

        // When
        let odds = await viewModel.odds(for: 9999)

        // Then
        XCTAssertNil(odds)
    }

    // MARK: - WebSocket Integration Tests

    @MainActor
    func test_initialConnectionState_isDisconnected() {
        // Given
        let service = MockAPIService(configuration: .init(simulatedDelay: 0))
        let viewModel = MatchListViewModel(apiService: service)

        // Then
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }

    @MainActor
    func test_startStreaming_connectsWebSocket() async {
        // Given
        let apiService = MockAPIService(configuration: .init(matchCount: 5, simulatedDelay: 0))
        let wsService = MockWebSocketService()
        let viewModel = MatchListViewModel(apiService: apiService, webSocketService: wsService)

        await viewModel.loadData()

        let expectation = XCTestExpectation(description: "Connected")
        viewModel.$connectionState
            .sink { state in
                if state == .connected { expectation.fulfill() }
            }
            .store(in: &cancellables)

        // When
        viewModel.startStreaming()

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(viewModel.connectionState, .connected)
    }

    @MainActor
    func test_stopStreaming_disconnectsWebSocket() async {
        // Given
        let apiService = MockAPIService(configuration: .init(matchCount: 5, simulatedDelay: 0))
        let wsService = MockWebSocketService()
        let viewModel = MatchListViewModel(apiService: apiService, webSocketService: wsService)

        await viewModel.loadData()

        // Wait for connection
        let connectedExpectation = XCTestExpectation(description: "Connected")
        viewModel.$connectionState
            .sink { state in
                if state == .connected { connectedExpectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.startStreaming()
        await fulfillment(of: [connectedExpectation], timeout: 1.0)

        // When
        viewModel.stopStreaming()

        // Then - wait briefly for state propagation
        let disconnectedExpectation = XCTestExpectation(description: "Disconnected")
        viewModel.$connectionState
            .sink { state in
                if state == .disconnected { disconnectedExpectation.fulfill() }
            }
            .store(in: &cancellables)

        await fulfillment(of: [disconnectedExpectation], timeout: 0.5)
        XCTAssertEqual(viewModel.connectionState, .disconnected)
    }

    @MainActor
    func test_rowsToUpdate_publishesChangeResults() async {
        // Given
        let apiService = MockAPIService(configuration: .init(matchCount: 5, simulatedDelay: 0))
        let wsConfig = MockWebSocketService.Configuration(
            updateInterval: 0.05,
            updateProbability: 1.0
        )
        let wsService = MockWebSocketService(configuration: wsConfig)
        let viewModel = MatchListViewModel(
            apiService: apiService,
            webSocketService: wsService,
            batchingWindowMs: 100
        )

        await viewModel.loadData()

        var receivedResults: [[OddsChangeResult]] = []
        let expectation = XCTestExpectation(description: "Received row updates")

        viewModel.rowsToUpdate
            .prefix(2)
            .sink { changeResults in
                receivedResults.append(changeResults)
                if receivedResults.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        viewModel.startStreaming()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(receivedResults.count, 2)
        viewModel.stopStreaming()
    }

    @MainActor
    func test_batchedUpdates_deduplicatesSameMatchID() async {
        // Given
        let apiService = MockAPIService(configuration: .init(matchCount: 1, simulatedDelay: 0))
        let wsConfig = MockWebSocketService.Configuration(
            updateInterval: 0.02,  // Very fast to generate multiple updates
            updateProbability: 1.0
        )
        let wsService = MockWebSocketService(configuration: wsConfig)
        let viewModel = MatchListViewModel(
            apiService: apiService,
            webSocketService: wsService,
            batchingWindowMs: 200  // 200ms window to collect multiple updates
        )

        await viewModel.loadData()

        var batchChangeResults: [OddsChangeResult] = []
        let expectation = XCTestExpectation(description: "Received batched updates")

        viewModel.rowsToUpdate
            .prefix(1)
            .sink { changeResults in
                batchChangeResults = changeResults
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        viewModel.startStreaming()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)

        // With 1 match, even with multiple updates in the batch window,
        // we should only see 1 change result (deduplicated)
        XCTAssertEqual(batchChangeResults.count, 1)
        viewModel.stopStreaming()
    }
}
