import XCTest
@testable import LiveOdds

final class ConnectionStateTests: XCTestCase {

    // MARK: - Equatable Tests

    func test_equality_sameStates_returnsTrue() {
        XCTAssertEqual(ConnectionState.disconnected, .disconnected)
        XCTAssertEqual(ConnectionState.connecting, .connecting)
        XCTAssertEqual(ConnectionState.connected, .connected)
        XCTAssertEqual(
            ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1),
            .reconnecting(attempt: 0, nextRetryIn: 1)
        )
    }

    func test_equality_differentStates_returnsFalse() {
        XCTAssertNotEqual(ConnectionState.disconnected, .connecting)
        XCTAssertNotEqual(ConnectionState.connecting, .connected)
        XCTAssertNotEqual(ConnectionState.connected, .reconnecting(attempt: 0, nextRetryIn: 1))
        XCTAssertNotEqual(ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1), .disconnected)
    }

    func test_equality_reconnectingWithDifferentValues_returnsFalse() {
        XCTAssertNotEqual(
            ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1),
            .reconnecting(attempt: 1, nextRetryIn: 1)
        )
        XCTAssertNotEqual(
            ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1),
            .reconnecting(attempt: 0, nextRetryIn: 2)
        )
    }

    // MARK: - Sendable Tests

    func test_canBeUsedAcrossActorBoundaries() async {
        // Given
        let state = ConnectionState.connected

        // When
        let result = await Task.detached {
            return state
        }.value

        // Then
        XCTAssertEqual(result, .connected)
    }

    // MARK: - All Cases Test

    func test_allCasesExist() {
        // Verify all cases can be instantiated
        let cases: [ConnectionState] = [
            .disconnected,
            .connecting,
            .connected,
            .reconnecting(attempt: 0, nextRetryIn: 1)
        ]

        XCTAssertEqual(cases.count, 4)
    }

    // MARK: - isConnected Tests

    func test_isConnected_whenConnected_returnsTrue() {
        XCTAssertTrue(ConnectionState.connected.isConnected)
    }

    func test_isConnected_whenNotConnected_returnsFalse() {
        XCTAssertFalse(ConnectionState.disconnected.isConnected)
        XCTAssertFalse(ConnectionState.connecting.isConnected)
        XCTAssertFalse(ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1).isConnected)
    }

    // MARK: - isReconnecting Tests

    func test_isReconnecting_whenReconnecting_returnsTrue() {
        XCTAssertTrue(ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1).isReconnecting)
        XCTAssertTrue(ConnectionState.reconnecting(attempt: 5, nextRetryIn: 30).isReconnecting)
    }

    func test_isReconnecting_whenNotReconnecting_returnsFalse() {
        XCTAssertFalse(ConnectionState.disconnected.isReconnecting)
        XCTAssertFalse(ConnectionState.connecting.isReconnecting)
        XCTAssertFalse(ConnectionState.connected.isReconnecting)
    }

    // MARK: - displayText Tests

    func test_displayText_disconnected() {
        XCTAssertEqual(ConnectionState.disconnected.displayText, "Disconnected")
    }

    func test_displayText_connecting() {
        XCTAssertEqual(ConnectionState.connecting.displayText, "Connecting...")
    }

    func test_displayText_connected() {
        XCTAssertEqual(ConnectionState.connected.displayText, "Connected")
    }

    func test_displayText_reconnecting() {
        let state = ConnectionState.reconnecting(attempt: 2, nextRetryIn: 5)
        XCTAssertEqual(state.displayText, "Reconnecting in 5s...")
    }

    func test_displayText_reconnecting_roundsDown() {
        let state = ConnectionState.reconnecting(attempt: 0, nextRetryIn: 3.7)
        XCTAssertEqual(state.displayText, "Reconnecting in 3s...")
    }

    // MARK: - indicatorColor Tests

    func test_indicatorColor_disconnected() {
        XCTAssertEqual(ConnectionState.disconnected.indicatorColor, .systemGray)
    }

    func test_indicatorColor_connecting() {
        XCTAssertEqual(ConnectionState.connecting.indicatorColor, .systemYellow)
    }

    func test_indicatorColor_connected() {
        XCTAssertEqual(ConnectionState.connected.indicatorColor, .systemGreen)
    }

    func test_indicatorColor_reconnecting() {
        let state = ConnectionState.reconnecting(attempt: 0, nextRetryIn: 1)
        XCTAssertEqual(state.indicatorColor, .systemOrange)
    }
}
