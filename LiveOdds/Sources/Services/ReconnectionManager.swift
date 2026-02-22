import Foundation

/// Manages automatic reconnection with exponential backoff.
actor ReconnectionManager {

    private let configuration: ReconnectionConfiguration

    private var currentAttempt: Int = 0
    private var reconnectionTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    private let onAttemptReconnect: @Sendable () async -> Bool
    private let onStateChange: @Sendable (ConnectionState) -> Void

    init(
        configuration: ReconnectionConfiguration = .default,
        onAttemptReconnect: @escaping @Sendable () async -> Bool,
        onStateChange: @escaping @Sendable (ConnectionState) -> Void
    ) {
        self.configuration = configuration
        self.onAttemptReconnect = onAttemptReconnect
        self.onStateChange = onStateChange
    }

    func startReconnecting() {
        cancelReconnection()

        reconnectionTask = Task {
            await reconnectionLoop()
        }
    }

    func cancelReconnection() {
        reconnectionTask?.cancel()
        reconnectionTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    func reset() {
        currentAttempt = 0
        cancelReconnection()
    }
 
    func calculateDelay(attempt: Int) -> TimeInterval {
        let exponentialDelay = configuration.initialDelay * pow(configuration.multiplier, Double(attempt))
        return min(exponentialDelay, configuration.maxDelay)
    }

    private func reconnectionLoop() async {
        while !Task.isCancelled {
            if let maxAttempts = configuration.maxAttempts,
               currentAttempt >= maxAttempts {
                onStateChange(.disconnected)
                return
            }

            let delay = calculateDelay(attempt: currentAttempt)

            await startCountdown(delay: delay)

            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            if Task.isCancelled { return }

            onStateChange(.connecting)

            let success = await onAttemptReconnect()

            if Task.isCancelled { return }

            if success {
                currentAttempt = 0
                onStateChange(.connected)
                return
            } else {
                currentAttempt += 1
            }
        }
    }

    /// Starts countdown timer that updates state every second.
    private func startCountdown(delay: TimeInterval) async {
        countdownTask?.cancel()

        // Initial state update
        onStateChange(.reconnecting(attempt: currentAttempt, nextRetryIn: delay))

        countdownTask = Task {
            var remaining = delay
            while remaining > 0 && !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                    remaining -= 1
                    if remaining > 0 && !Task.isCancelled {
                        onStateChange(.reconnecting(attempt: currentAttempt, nextRetryIn: remaining))
                    }
                } catch {
                    return
                }
            }
        }
    }
}
