import XCTest
import Combine
@testable import LiveOdds

final class FPSMonitorTests: XCTestCase {

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

    func test_initialState_fpsIsZero() {
        // Given
        let monitor = FPSMonitor()

        // Then
        XCTAssertEqual(monitor.currentFPS, 0)
    }

    // MARK: - Start/Stop Tests

    func test_start_beginsFPSMonitoring() {
        // Given
        let monitor = FPSMonitor(updateInterval: 0.1)

        let expectation = XCTestExpectation(description: "FPS updated")

        monitor.$currentFPS
            .dropFirst()
            .sink { fps in
                if fps > 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        monitor.start()

        // Then
        wait(for: [expectation], timeout: 1.0)
        monitor.stop()
    }

    func test_stop_resetsFPSToZero() {
        // Given
        let monitor = FPSMonitor(updateInterval: 0.1)

        let startedExpectation = XCTestExpectation(description: "FPS started")

        monitor.$currentFPS
            .dropFirst()
            .sink { fps in
                if fps > 0 {
                    startedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        monitor.start()
        wait(for: [startedExpectation], timeout: 1.0)

        // When
        monitor.stop()

        // Then
        XCTAssertEqual(monitor.currentFPS, 0)
    }

    func test_startTwice_doesNotCrash() {
        // Given
        let monitor = FPSMonitor()

        // When
        monitor.start()
        monitor.start() // Should be ignored

        // Then - no crash
        monitor.stop()
    }

    // MARK: - FPS Publishing Tests

    func test_fpsPublisher_emitsUpdates() {
        // Given
        let monitor = FPSMonitor(updateInterval: 0.1)
        var receivedFPS: [Int] = []

        let expectation = XCTestExpectation(description: "Multiple FPS updates received")

        monitor.$currentFPS
            .dropFirst()
            .prefix(3)
            .sink { fps in
                receivedFPS.append(fps)
                if receivedFPS.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        monitor.start()

        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(receivedFPS.count, 3)
        monitor.stop()
    }

    func test_fps_isReasonableValue() {
        // Given
        let monitor = FPSMonitor(updateInterval: 0.2)
        var measuredFPS: Int = 0

        let expectation = XCTestExpectation(description: "FPS measured")

        monitor.$currentFPS
            .dropFirst()
            .first()
            .sink { fps in
                measuredFPS = fps
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        monitor.start()

        // Then
        wait(for: [expectation], timeout: 1.0)
        // FPS should be between 30-120 on most devices (including CI)
        XCTAssertGreaterThan(measuredFPS, 0, "FPS should be greater than 0")
        XCTAssertLessThanOrEqual(measuredFPS, 120, "FPS should not exceed 120")
        monitor.stop()
    }

    // MARK: - Deinit Tests

    func test_deinit_stopsMonitoring() {
        // Given
        var monitor: FPSMonitor? = FPSMonitor()
        monitor?.start()

        // When
        monitor = nil

        // Then - no crash, no leaks (verified by memory sanitizer)
    }
}
