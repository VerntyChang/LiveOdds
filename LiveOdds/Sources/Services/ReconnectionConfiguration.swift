import Foundation

/// Configuration for the reconnection behavior with exponential backoff.
struct ReconnectionConfiguration {
    /// Initial delay before first reconnection attempt (in seconds)
    let initialDelay: TimeInterval

    /// Multiplier applied to delay after each failed attempt
    let multiplier: Double

    /// Maximum delay between reconnection attempts (in seconds)
    let maxDelay: TimeInterval

    /// Optional maximum number of attempts (nil = unlimited)
    let maxAttempts: Int?

    /// Default configuration matching PRD requirements.
    /// - Initial delay: 1s
    /// - Multiplier: 2x
    /// - Max delay: 30s
    /// - Attempts: unlimited
    static let `default` = ReconnectionConfiguration(
        initialDelay: 1.0,
        multiplier: 2.0,
        maxDelay: 30.0,
        maxAttempts: nil
    )

    /// Fast configuration for testing with shorter delays.
    static let testing = ReconnectionConfiguration(
        initialDelay: 0.1,
        multiplier: 2.0,
        maxDelay: 0.5,
        maxAttempts: 5
    )
}
