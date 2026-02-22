import UIKit

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected

    /// Attempting to reconnect after connection loss
    /// - Parameters:
    ///   - attempt: Current attempt number (0-indexed)
    ///   - nextRetryIn: Seconds until next reconnection attempt
    case reconnecting(attempt: Int, nextRetryIn: TimeInterval)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reconnecting(_, let nextRetry):
            return "Reconnecting in \(Int(nextRetry))s..."
        }
    }

    var indicatorColor: UIColor {
        switch self {
        case .disconnected:
            return .systemGray
        case .connecting:
            return .systemYellow
        case .connected:
            return .systemGreen
        case .reconnecting:
            return .systemOrange
        }
    }
}
