import XCTest
@testable import LiveOdds

final class APIErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func test_networkError_providesUserFriendlyMessage() {
        // Given
        let underlyingError = URLError(.notConnectedToInternet)
        let error = APIError.networkError(underlying: underlyingError)

        // Then
        XCTAssertEqual(
            error.errorDescription,
            "Unable to connect. Please check your connection."
        )
    }

    func test_decodingError_providesUserFriendlyMessage() {
        // Given
        let underlyingError = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "test")
        )
        let error = APIError.decodingError(underlying: underlyingError)

        // Then
        XCTAssertEqual(
            error.errorDescription,
            "Unable to process server response."
        )
    }

    func test_invalidResponse_providesUserFriendlyMessage() {
        // Given
        let error = APIError.invalidResponse

        // Then
        XCTAssertEqual(
            error.errorDescription,
            "Invalid response from server."
        )
    }

    func test_timeout_providesUserFriendlyMessage() {
        // Given
        let error = APIError.timeout

        // Then
        XCTAssertEqual(
            error.errorDescription,
            "Request timed out. Please try again."
        )
    }

    // MARK: - LocalizedError Conformance Tests

    func test_localizedDescription_returnsErrorDescription() {
        // Given
        let error = APIError.timeout

        // Then
        XCTAssertEqual(
            error.localizedDescription,
            "Request timed out. Please try again."
        )
    }
}
