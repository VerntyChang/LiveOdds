import XCTest
import Combine
@testable import LiveOdds

@MainActor
final class ReconnectionIntegrationTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Connection Loss Tests

    func test_simulateConnectionLoss_triggersReconnection() async {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.1,
            reconnectionConfig: .testing
        )
        let service = MockWebSocketService(configuration: config)
        service.connect()
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(service.connectionState, .connected)

        // When
        var states: [ConnectionState] = []
        service.connectionStatePublisher
            .sink { states.append($0) }
            .store(in: &cancellables)

        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(300))

        // Then
        XCTAssertTrue(states.contains(where: { $0.isReconnecting }))
    }

    func test_userDisconnect_cancelsReconnection() async {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.1,
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 0.0 // Always fail reconnection
        )
        let service = MockWebSocketService(configuration: config)
        service.connect()
        try? await Task.sleep(for: .milliseconds(200))

        // Start reconnection and wait for it to begin
        var sawReconnecting = false
        service.connectionStatePublisher
            .sink { state in
                if state.isReconnecting {
                    sawReconnecting = true
                }
            }
            .store(in: &cancellables)

        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(200))

        // When - user disconnects
        service.disconnect()
        try? await Task.sleep(for: .milliseconds(100))

        // Then - should be disconnected, not reconnecting
        XCTAssertEqual(service.connectionState, .disconnected)
        XCTAssertTrue(sawReconnecting, "Should have seen reconnecting state before disconnect")
    }

    func test_successfulReconnection_resumesStreaming() async {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.1,
            updateProbability: 1.0,
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 1.0 // Always succeed
        )
        let service = MockWebSocketService(configuration: config)

        // Set up initial data
        let initialOdds: [Int: Odds] = [
            1: Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.5)
        ]
        service.setInitialOdds(initialOdds, matchIDs: [1])

        // Connect and verify streaming
        service.connect()
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(service.connectionState, .connected)

        // When - simulate connection loss and wait for reconnection
        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(500))

        // Then - should reconnect and resume
        XCTAssertEqual(service.connectionState, .connected)

        // Verify streaming resumed by checking for updates
        var receivedUpdates: [Odds] = []
        service.oddsPublisher
            .sink { receivedUpdates.append($0) }
            .store(in: &cancellables)

        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertFalse(receivedUpdates.isEmpty, "Should receive updates after reconnection")
    }

    func test_dataPreserved_duringReconnection() async {
        // Given - set up store with data
        let store = MatchesStore()
        let matches = [
            Match(matchID: 1, teamA: "Team A", teamB: "Team B", startTime: Date()),
            Match(matchID: 2, teamA: "Team C", teamB: "Team D", startTime: Date())
        ]
        let odds = [
            Odds(matchID: 1, teamAOdds: 1.5, teamBOdds: 2.5),
            Odds(matchID: 2, teamAOdds: 1.8, teamBOdds: 2.2)
        ]
        await store.bootstrap(matches: matches, oddsList: odds)

        let config = MockWebSocketService.Configuration(
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 0.0 // Keep reconnecting
        )
        let service = MockWebSocketService(configuration: config)
        service.connect()
        try? await Task.sleep(for: .milliseconds(200))

        // When - simulate connection loss
        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(100))

        // Then - data should still be accessible
        let matchCount = await store.matchCount
        XCTAssertEqual(matchCount, 2)

        let storedOdds = await store.odds(for: 1)
        XCTAssertNotNil(storedOdds)
        XCTAssertEqual(storedOdds?.teamAOdds, 1.5)

        service.disconnect()
    }

    // MARK: - State Transition Tests

    func test_stateTransitions_duringReconnection() async {
        // Given
        let config = MockWebSocketService.Configuration(
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 1.0
        )
        let service = MockWebSocketService(configuration: config)

        var states: [ConnectionState] = []
        service.connectionStatePublisher
            .sink { states.append($0) }
            .store(in: &cancellables)

        // When - full cycle
        service.connect()
        try? await Task.sleep(for: .milliseconds(200))
        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(500))

        // Then - verify state sequence
        XCTAssertTrue(states.contains(where: { $0 == .disconnected }))
        XCTAssertTrue(states.contains(where: { $0 == .connecting }))
        XCTAssertTrue(states.contains(where: { $0 == .connected }))
        XCTAssertTrue(states.contains(where: { $0.isReconnecting }))
    }

    func test_multipleConnectionLoss_handledCorrectly() async {
        // Given
        let config = MockWebSocketService.Configuration(
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 1.0
        )
        let service = MockWebSocketService(configuration: config)
        service.connect()
        try? await Task.sleep(for: .milliseconds(200))

        // When - rapid connection losses
        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(50))
        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(50))

        // Then - should still recover
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(service.connectionState, .connected)
    }

    // MARK: - ViewModel Integration Tests

    func test_viewModel_connectionState_updatesWithService() async {
        // Given
        let config = MockWebSocketService.Configuration(
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 1.0
        )
        let service = MockWebSocketService(configuration: config)
        let apiService = MockAPIService()
        let viewModel = MatchListViewModel(
            apiService: apiService,
            webSocketService: service
        )

        // When
        await viewModel.loadData()
        try? await Task.sleep(for: .milliseconds(200))

        // Then - viewModel should reflect connection state
        XCTAssertEqual(viewModel.connectionState, .connected)
    }

    func test_viewModel_reflectsReconnectingState() async {
        // Given
        let config = MockWebSocketService.Configuration(
            reconnectionConfig: .testing,
            simulatedReconnectionSuccessRate: 0.0
        )
        let service = MockWebSocketService(configuration: config)
        let apiService = MockAPIService()
        let viewModel = MatchListViewModel(
            apiService: apiService,
            webSocketService: service
        )

        await viewModel.loadData()
        try? await Task.sleep(for: .milliseconds(200))

        // Track states
        var sawReconnecting = false
        viewModel.$connectionState
            .sink { state in
                if state.isReconnecting {
                    sawReconnecting = true
                }
            }
            .store(in: &cancellables)

        // When
        service.simulateConnectionLoss()
        try? await Task.sleep(for: .milliseconds(300))

        // Then
        XCTAssertTrue(sawReconnecting, "ViewModel should have reflected reconnecting state")

        service.disconnect()
    }
}
