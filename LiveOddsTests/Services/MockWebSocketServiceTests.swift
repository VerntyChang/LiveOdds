import XCTest
import Combine
@testable import LiveOdds

final class MockWebSocketServiceTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Connection State Tests

    func test_initialState_isDisconnected() {
        // Given
        let sut = MockWebSocketService()

        // Then
        XCTAssertEqual(sut.connectionState, .disconnected)
    }

    func test_connect_changesStateToConnecting() {
        // Given
        let sut = MockWebSocketService()
        let expectation = expectation(description: "Connecting state")

        var states: [ConnectionState] = []
        sut.connectionStatePublisher
            .sink { state in
                states.append(state)
                if state == .connecting {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Then
        waitForExpectations(timeout: 0.5)
        XCTAssertTrue(states.contains(.connecting))
    }

    func test_connect_changesStateToConnected() {
        // Given
        let sut = MockWebSocketService()
        let expectation = expectation(description: "Connected state")

        sut.connectionStatePublisher
            .sink { state in
                if state == .connected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(sut.connectionState, .connected)
    }

    func test_connect_stateTransitionOrder() {
        // Given
        let sut = MockWebSocketService()
        let expectation = expectation(description: "State transitions")

        var states: [ConnectionState] = []
        sut.connectionStatePublisher
            .sink { state in
                states.append(state)
                if state == .connected {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Then
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(states, [.disconnected, .connecting, .connected])
    }

    func test_disconnect_changesStateToDisconnected() {
        // Given
        let sut = MockWebSocketService()
        let connectedExpectation = expectation(description: "Connected")

        sut.connectionStatePublisher
            .sink { state in
                if state == .connected {
                    connectedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sut.connect()
        waitForExpectations(timeout: 1.0)

        // When
        sut.disconnect()

        // Then
        XCTAssertEqual(sut.connectionState, .disconnected)
    }

    func test_connect_whenAlreadyConnected_doesNothing() {
        // Given
        let sut = MockWebSocketService()
        let connectedExpectation = expectation(description: "Connected")

        sut.connectionStatePublisher
            .sink { state in
                if state == .connected {
                    connectedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sut.connect()
        waitForExpectations(timeout: 1.0)

        var stateChanges = 0
        sut.connectionStatePublisher
            .dropFirst() // Skip current state
            .sink { _ in stateChanges += 1 }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Then - state should not change
        XCTAssertEqual(stateChanges, 0)
        XCTAssertEqual(sut.connectionState, .connected)
    }

    // MARK: - Update Generation Tests

    func test_disconnect_stopsPublishingUpdates() {
        // Given
        let config = MockWebSocketService.Configuration(updateProbability: 1.0)
        let sut = MockWebSocketService(configuration: config)

        let initialOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        sut.setInitialOdds([1001: initialOdds], matchIDs: [1001])

        let connectedExpectation = expectation(description: "Connected")

        sut.connectionStatePublisher
            .sink { state in
                if state == .connected {
                    connectedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sut.connect()
        waitForExpectations(timeout: 1.0)

        // Wait for some updates
        let waitExpectation = expectation(description: "Wait")
        waitExpectation.isInverted = true
        wait(for: [waitExpectation], timeout: 0.3)

        // When
        sut.disconnect()

        // Then - count updates after disconnect
        var updatesAfterDisconnect = 0
        sut.oddsPublisher
            .sink { _ in updatesAfterDisconnect += 1 }
            .store(in: &cancellables)

        let postDisconnectWait = expectation(description: "Post disconnect wait")
        postDisconnectWait.isInverted = true
        wait(for: [postDisconnectWait], timeout: 0.3)

        XCTAssertEqual(updatesAfterDisconnect, 0)
    }

    func test_updates_publishedWhenConnected() async throws {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.05,
            updateProbability: 1.0
        )
        let sut = MockWebSocketService(configuration: config)

        let initialOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        sut.setInitialOdds([1001: initialOdds], matchIDs: [1001])

        var receivedUpdates: [Odds] = []
        let expectation = expectation(description: "Receive updates")

        sut.oddsPublisher
            .prefix(3)
            .sink { update in
                receivedUpdates.append(update)
                if receivedUpdates.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedUpdates.count, 3)
        XCTAssertTrue(receivedUpdates.allSatisfy { $0.matchID == 1001 })
    }

    func test_updates_areWithinValidRange() async throws {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.05,
            updateProbability: 1.0
        )
        let sut = MockWebSocketService(configuration: config)

        let initialOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        sut.setInitialOdds([1001: initialOdds], matchIDs: [1001])

        var receivedUpdates: [Odds] = []
        let expectation = expectation(description: "Receive updates")

        sut.oddsPublisher
            .prefix(10)
            .collect()
            .sink { updates in
                receivedUpdates = updates
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)

        for update in receivedUpdates {
            XCTAssertGreaterThanOrEqual(update.teamAOdds, 1.01)
            XCTAssertLessThanOrEqual(update.teamAOdds, 99.0)
            XCTAssertGreaterThanOrEqual(update.teamBOdds, 1.01)
            XCTAssertLessThanOrEqual(update.teamBOdds, 99.0)
        }
    }

    func test_updates_respectProbability() async throws {
        // Given - 0% probability should generate no updates
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.05,
            updateProbability: 0.0
        )
        let sut = MockWebSocketService(configuration: config)

        let initialOdds = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        sut.setInitialOdds([1001: initialOdds], matchIDs: [1001])

        var updateCount = 0
        sut.oddsPublisher
            .sink { _ in updateCount += 1 }
            .store(in: &cancellables)

        // When
        sut.connect()

        // Wait briefly
        try await Task.sleep(for: .milliseconds(300))

        // Then
        XCTAssertEqual(updateCount, 0)
        sut.disconnect()
    }

    func test_setInitialOdds_storesSnapshot() async throws {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.05,
            updateProbability: 1.0
        )
        let sut = MockWebSocketService(configuration: config)

        let odds1 = Odds(matchID: 1001, teamAOdds: 2.00, teamBOdds: 2.00)
        let odds2 = Odds(matchID: 1002, teamAOdds: 1.50, teamBOdds: 3.00)

        // When
        sut.setInitialOdds([1001: odds1, 1002: odds2], matchIDs: [1001, 1002])

        var receivedMatchIDs: Set<Int> = []
        let expectation = expectation(description: "Receive updates for both matches")

        sut.oddsPublisher
            .prefix(10)
            .sink { update in
                receivedMatchIDs.insert(update.matchID)
                if receivedMatchIDs.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sut.connect()

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(receivedMatchIDs.contains(1001))
        XCTAssertTrue(receivedMatchIDs.contains(1002))
        sut.disconnect()
    }

    // MARK: - Configuration Tests

    func test_configuration_defaultValues() {
        // Given
        let config = MockWebSocketService.Configuration()

        // Then
        XCTAssertEqual(config.updateInterval, 0.1)
        XCTAssertEqual(config.updateProbability, 0.5)
        XCTAssertEqual(config.oddsVariationRange, -0.10...0.10)
    }

    func test_configuration_customValues() {
        // Given
        let config = MockWebSocketService.Configuration(
            updateInterval: 0.5,
            oddsVariationRange: -0.05...0.05,
            updateProbability: 0.5
        )

        // Then
        XCTAssertEqual(config.updateInterval, 0.5)
        XCTAssertEqual(config.updateProbability, 0.5)
        XCTAssertEqual(config.oddsVariationRange, -0.05...0.05)
    }

    // MARK: - Race Condition Regression Tests

    func test_disconnect_duringConnecting_doesNotTransitionToConnected() async throws {
        // Given
        let sut = MockWebSocketService()

        // When - connect then immediately disconnect
        sut.connect()
        XCTAssertEqual(sut.connectionState, .connecting)

        sut.disconnect()
        XCTAssertEqual(sut.connectionState, .disconnected)

        // Wait longer than the connect delay (0.1s)
        try await Task.sleep(for: .milliseconds(200))

        // Then - should still be disconnected, not connected
        XCTAssertEqual(sut.connectionState, .disconnected)
    }
}
