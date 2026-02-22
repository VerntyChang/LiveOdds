import XCTest
@testable import LiveOdds

final class ReconnectionConfigurationTests: XCTestCase {

    // MARK: - Default Configuration Tests

    func test_default_hasCorrectInitialDelay() {
        XCTAssertEqual(ReconnectionConfiguration.default.initialDelay, 1.0)
    }

    func test_default_hasCorrectMultiplier() {
        XCTAssertEqual(ReconnectionConfiguration.default.multiplier, 2.0)
    }

    func test_default_hasCorrectMaxDelay() {
        XCTAssertEqual(ReconnectionConfiguration.default.maxDelay, 30.0)
    }

    func test_default_hasUnlimitedAttempts() {
        XCTAssertNil(ReconnectionConfiguration.default.maxAttempts)
    }

    // MARK: - Testing Configuration Tests

    func test_testing_hasCorrectInitialDelay() {
        XCTAssertEqual(ReconnectionConfiguration.testing.initialDelay, 0.1)
    }

    func test_testing_hasCorrectMultiplier() {
        XCTAssertEqual(ReconnectionConfiguration.testing.multiplier, 2.0)
    }

    func test_testing_hasCorrectMaxDelay() {
        XCTAssertEqual(ReconnectionConfiguration.testing.maxDelay, 0.5)
    }

    func test_testing_hasLimitedAttempts() {
        XCTAssertEqual(ReconnectionConfiguration.testing.maxAttempts, 5)
    }

    // MARK: - Custom Configuration Tests

    func test_customConfiguration_preservesValues() {
        let config = ReconnectionConfiguration(
            initialDelay: 2.0,
            multiplier: 3.0,
            maxDelay: 60.0,
            maxAttempts: 10
        )

        XCTAssertEqual(config.initialDelay, 2.0)
        XCTAssertEqual(config.multiplier, 3.0)
        XCTAssertEqual(config.maxDelay, 60.0)
        XCTAssertEqual(config.maxAttempts, 10)
    }

    // MARK: - Sendable Tests

    func test_canBeUsedAcrossActorBoundaries() async {
        let config = ReconnectionConfiguration.default

        let result = await Task.detached {
            return config.initialDelay
        }.value

        XCTAssertEqual(result, 1.0)
    }
}
