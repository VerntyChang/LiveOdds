import XCTest
@testable import LiveOdds

final class ConnectionStatusViewTests: XCTestCase {

    var sut: ConnectionStatusView!

    override func setUp() {
        super.setUp()
        sut = ConnectionStatusView()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func test_initialState_showsDisconnectedText() {
        // Given
        let label = findStatusLabel()

        // Then
        XCTAssertEqual(label?.text, "Disconnected")
    }

    func test_initialState_showsGrayDot() {
        // Given
        let dot = findStatusDot()

        // Then
        XCTAssertEqual(dot?.backgroundColor, .systemGray)
    }

    // MARK: - Connected State Tests

    func test_update_connected_showsConnectedText() {
        // When
        sut.update(for: .connected)

        // Then
        let label = findStatusLabel()
        XCTAssertEqual(label?.text, "Connected")
    }

    func test_update_connected_showsGreenDot() {
        // When
        sut.update(for: .connected)

        // Then
        let dot = findStatusDot()
        XCTAssertEqual(dot?.backgroundColor, .systemGreen)
    }

    func test_update_connected_noPulseAnimation() {
        // When
        sut.update(for: .connected)

        // Then
        let dot = findStatusDot()
        XCTAssertNil(dot?.layer.animation(forKey: "pulse"))
    }

    // MARK: - Connecting State Tests

    func test_update_connecting_showsConnectingText() {
        // When
        sut.update(for: .connecting)

        // Then
        let label = findStatusLabel()
        XCTAssertEqual(label?.text, "Connecting...")
    }

    func test_update_connecting_showsYellowDot() {
        // When
        sut.update(for: .connecting)

        // Then
        let dot = findStatusDot()
        XCTAssertEqual(dot?.backgroundColor, .systemYellow)
    }

    // MARK: - Reconnecting State Tests

    func test_update_reconnecting_showsReconnectingText() {
        // When
        sut.update(for: .reconnecting(attempt: 2, nextRetryIn: 5))

        // Then
        let label = findStatusLabel()
        XCTAssertEqual(label?.text, "Reconnecting in 5s...")
    }

    func test_update_reconnecting_showsOrangeDot() {
        // When
        sut.update(for: .reconnecting(attempt: 0, nextRetryIn: 1))

        // Then
        let dot = findStatusDot()
        XCTAssertEqual(dot?.backgroundColor, .systemOrange)
    }

    func test_update_reconnecting_startsPulseAnimation() {
        // When
        sut.update(for: .reconnecting(attempt: 0, nextRetryIn: 1))

        // Then
        let dot = findStatusDot()
        XCTAssertNotNil(dot?.layer.animation(forKey: "pulse"))
    }

    func test_update_reconnecting_thenConnected_stopsPulseAnimation() {
        // Given
        sut.update(for: .reconnecting(attempt: 0, nextRetryIn: 1))

        // When
        sut.update(for: .connected)

        // Then
        let dot = findStatusDot()
        XCTAssertNil(dot?.layer.animation(forKey: "pulse"))
    }

    // MARK: - Disconnected State Tests

    func test_update_disconnected_showsDisconnectedText() {
        // Given
        sut.update(for: .connected) // First set to different state

        // When
        sut.update(for: .disconnected)

        // Then
        let label = findStatusLabel()
        XCTAssertEqual(label?.text, "Disconnected")
    }

    func test_update_disconnected_showsGrayDot() {
        // Given
        sut.update(for: .connected) // First set to different state

        // When
        sut.update(for: .disconnected)

        // Then
        let dot = findStatusDot()
        XCTAssertEqual(dot?.backgroundColor, .systemGray)
    }

    // MARK: - Countdown Updates

    func test_update_reconnecting_countsDown() {
        // When
        sut.update(for: .reconnecting(attempt: 0, nextRetryIn: 10))

        // Then
        var label = findStatusLabel()
        XCTAssertEqual(label?.text, "Reconnecting in 10s...")

        // When
        sut.update(for: .reconnecting(attempt: 0, nextRetryIn: 9))

        // Then
        label = findStatusLabel()
        XCTAssertEqual(label?.text, "Reconnecting in 9s...")
    }

    // MARK: - Helpers

    private func findStatusDot() -> UIView? {
        // Status dot is inside a stack view
        for subview in sut.subviews {
            if let stackView = subview as? UIStackView {
                for arrangedSubview in stackView.arrangedSubviews {
                    if arrangedSubview is UILabel {
                        continue
                    }
                    return arrangedSubview
                }
            }
        }
        return nil
    }

    private func findStatusLabel() -> UILabel? {
        for subview in sut.subviews {
            if let stackView = subview as? UIStackView {
                for arrangedSubview in stackView.arrangedSubviews {
                    if let label = arrangedSubview as? UILabel {
                        return label
                    }
                }
            }
        }
        return nil
    }
}
