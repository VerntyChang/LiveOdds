import Foundation

enum APIError: Error, LocalizedError {
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to connect. Please check your connection."
        case .decodingError:
            return "Unable to process server response."
        case .invalidResponse:
            return "Invalid response from server."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}

protocol APIServiceProtocol: Sendable {
    func fetchMatches() async throws -> [Match]
    func fetchOdds() async throws -> [Odds]
}
