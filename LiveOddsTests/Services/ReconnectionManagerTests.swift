import XCTest
@testable import LiveOdds

final class ReconnectionManagerTests: XCTestCase {

    // MARK: - Calculate Delay Tests

    func test_calculateDelay_attempt0_returns1Second() async {
        // Given
        let manager = ReconnectionManager(
            configuration: .default,
            onAttemptReconnect: { true },
            onStateChange: { _ in }
        )

        // When
        let delay = await manager.calculateDelay(attempt: 0)

        // Then
        XCTAssertEqual(delay, 1.0)
    }

    func test_calculateDelay_attempt1_returns2Seconds() async {
        // Given
        let manager = ReconnectionManager(
            configuration: .default,
            onAttemptReconnect: { true },
            onStateChange: { _ in }
        )

        // When
        let delay = await manager.calculateDelay(attempt: 1)

        // Then
        XCTAssertEqual(delay, 2.0)
    }

    func test_calculateDelay_attempt5_returnsCappedAt30() async {
        // Given
        let manager = ReconnectionManager(
            configuration: .default,
            onAttemptReconnect: { true },
            onStateChange: { _ in }
        )

        // When
        let delay = await manager.calculateDelay(attempt: 5)

        // Then
        XCTAssertEqual(delay, 30.0)
    }

    func test_calculateDelay_attempt10_remainsCappedAt30() async {
        // Given
        let manager = ReconnectionManager(
            configuration: .default,
            onAttemptReconnect: { true },
            onStateChange: { _ in }
        )

        // When
        let delay = await manager.calculateDelay(attempt: 10)

        // Then
        XCTAssertEqual(delay, 30.0)
    }

    func test_calculateDelay_progression() async {
        // Given
        let manager = ReconnectionManager(
            configuration: .default,
            onAttemptReconnect: { true },
            onStateChange: { _ in }
        )

        // When/Then - verify exponential progression
        let delay0 = await manager.calculateDelay(attempt: 0)
        XCTAssertEqual(delay0, 1.0)

        let delay1 = await manager.calculateDelay(attempt: 1)
        XCTAssertEqual(delay1, 2.0)

        let delay2 = await manager.calculateDelay(attempt: 2)
        XCTAssertEqual(delay2, 4.0)

        let delay3 = await manager.calculateDelay(attempt: 3)
        XCTAssertEqual(delay3, 8.0)

        let delay4 = await manager.calculateDelay(attempt: 4)
        XCTAssertEqual(delay4, 16.0)

        let delay5 = await manager.calculateDelay(attempt: 5)
        XCTAssertEqual(delay5, 30.0) // capped

        let delay6 = await manager.calculateDelay(attempt: 6)
        XCTAssertEqual(delay6, 30.0) // stays capped
    }

    // MARK: - Start Reconnecting Tests

    func test_startReconnecting_emitsReconnectingState() async {
        // Given
        var states: [ConnectionState] = []
        let stateExpectation = expectation(description: "State updated")

        let manager = ReconnectionManager(
            configuration: .testing,
            onAttemptReconnect: { false }, // Always fail
            onStateChange: { state in
                states.append(state)
                if state.isReconnecting {
                    stateExpectation.fulfill()
                }
            }
        )

        // When
        await manager.startReconnecting()

        // Then
        await fulfillment(of: [stateExpectation], timeout: 1.0)
        XCTAssertTrue(states.contains(where: { $0.isReconnecting }))

        // Cleanup
        await manager.cancelReconnection()
    }

    func test_successfulReconnection_emitsConnectedState() async {
        // Given
        var states: [ConnectionState] = []
        let connectedExpectation = expectation(description: "Connected")

        let manager = ReconnectionManager(
            configuration: .testing,
            onAttemptReconnect: { true }, // Always succeed
            onStateChange: { state in
                states.append(state)
                if state.isConnected {
                    connectedExpectation.fulfill()
                }
            }
        )

        // When
        await manager.startReconnecting()

        // Then
        await fulfillment(of: [connectedExpectation], timeout: 1.0)
        XCTAssertTrue(states.contains(where: { $0.isConnected }))
    }

    func test_cancelReconnection_stopsRetries() async {
        // Given
        var attemptCount = 0
        let manager = ReconnectionManager(
            configuration: .testing,
            onAttemptReconnect: {
                attemptCount += 1
                return false
            },
            onStateChange: { _ in }
        )

        // When
        await manager.startReconnecting()
        try? await Task.sleep(for: .milliseconds(150))
        await manager.cancelReconnection()
        let countAtCancel = attemptCount
        try? await Task.sleep(for: .milliseconds(500))

        // Then - no new attempts after cancel
        XCTAssertEqual(attemptCount, countAtCancel)
    }

    func test_reset_clearsAttemptCounter() async {
        // Given
        var attemptCount = 0
        let expectation = expectation(description: "Attempts made")

        let manager = ReconnectionManager(
            configuration: .testing,
            onAttemptReconnect: {
                attemptCount += 1
                if attemptCount >= 2 {
                    expectation.fulfill()
                }
                return false
            },
            onStateChange: { _ in }
        )

        // When
        await manager.startReconnecting()
        await fulfillment(of: [expectation], timeout: 2.0)
        await manager.reset()

        // Then - after reset, delay should be initial delay again
        let delay = await manager.calculateDelay(attempt: 0)
        XCTAssertEqual(delay, 0.1) // testing config initial delay
    }

    // MARK: - Max Attempts Tests

    func test_maxAttempts_stopsAfterLimit() async {
        // Given
        var attemptCount = 0
        var states: [ConnectionState] = []
        let disconnectedExpectation = expectation(description: "Disconnected after max attempts")

        let config = ReconnectionConfiguration(
            initialDelay: 0.05,
            multiplier: 1.0, // No backoff increase for faster test
            maxDelay: 0.05,
            maxAttempts: 3
        )

        let manager = ReconnectionManager(
            configuration: config,
            onAttemptReconnect: {
                attemptCount += 1
                return false // Always fail
            },
            onStateChange: { state in
                states.append(state)
                if case .disconnected = state {
                    disconnectedExpectation.fulfill()
                }
            }
        )

        // When
        await manager.startReconnecting()

        // Then
        await fulfillment(of: [disconnectedExpectation], timeout: 2.0)
        XCTAssertEqual(attemptCount, 3)
        XCTAssertEqual(states.last, .disconnected)
    }

    // MARK: - Reconnection Success Tests

    func test_reconnectionSucceedsOnSecondAttempt() async {
        // Given
        var attemptCount = 0
        var states: [ConnectionState] = []
        let connectedExpectation = expectation(description: "Connected")

        let manager = ReconnectionManager(
            configuration: .testing,
            onAttemptReconnect: {
                attemptCount += 1
                return attemptCount >= 2 // Succeed on 2nd attempt
            },
            onStateChange: { state in
                states.append(state)
                if state.isConnected {
                    connectedExpectation.fulfill()
                }
            }
        )

        // When
        await manager.startReconnecting()

        // Then
        await fulfillment(of: [connectedExpectation], timeout: 2.0)
        XCTAssertEqual(attemptCount, 2)
        XCTAssertTrue(states.contains(where: { $0.isConnected }))
    }

    // MARK: - State Transition Tests

    func test_stateTransition_reconnecting_to_connecting_to_connected() async {
        // Given
        var states: [ConnectionState] = []
        let connectedExpectation = expectation(description: "Connected")

        let manager = ReconnectionManager(
            configuration: .testing,
            onAttemptReconnect: { true },
            onStateChange: { state in
                states.append(state)
                if state.isConnected {
                    connectedExpectation.fulfill()
                }
            }
        )

        // When
        await manager.startReconnecting()

        // Then
        await fulfillment(of: [connectedExpectation], timeout: 1.0)

        // Verify state sequence includes reconnecting and connected
        XCTAssertTrue(states.contains(where: { $0.isReconnecting }))
        XCTAssertTrue(states.contains(where: { $0.isConnected }))
    }
}
