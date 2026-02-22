import Foundation
import Combine

final class MockWebSocketService: WebSocketServiceProtocol, @unchecked Sendable {

    struct Configuration {
        /// Interval between updates (default: 100ms = 10 ticks/sec)
        var updateInterval: TimeInterval

        var oddsVariationRange: ClosedRange<Double>

        /// Probability that an update is published each tick (0.0-1.0)
        /// With 10 ticks/sec: 0.5 = avg 5 updates/sec, 1.0 = max 10 updates/sec
        var updateProbability: Double

        var reconnectionConfig: ReconnectionConfiguration

        /// Simulated success rate for reconnection attempts (0.0-1.0)
        /// 1.0 = always succeed, 0.5 = 50% chance
        var simulatedReconnectionSuccessRate: Double

        init(
            updateInterval: TimeInterval = 0.1,
            oddsVariationRange: ClosedRange<Double> = -0.10...0.10,
            updateProbability: Double = 0.5,
            reconnectionConfig: ReconnectionConfiguration = .default,
            simulatedReconnectionSuccessRate: Double = 1.0
        ) {
            self.updateInterval = updateInterval
            self.oddsVariationRange = oddsVariationRange
            self.updateProbability = updateProbability
            self.reconnectionConfig = reconnectionConfig
            self.simulatedReconnectionSuccessRate = simulatedReconnectionSuccessRate
        }
    }

    private let oddsSubject = PassthroughSubject<Odds, Never>()
    private let connectionStateSubject = CurrentValueSubject<ConnectionState, Never>(.disconnected)

    var oddsPublisher: AnyPublisher<Odds, Never> {
        oddsSubject.eraseToAnyPublisher()
    }

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    var connectionState: ConnectionState {
        connectionStateSubject.value
    }

    private let configuration: Configuration
    private var timer: AnyCancellable?
    private var currentOddsSnapshot: [Int: Odds] = [:]
    private var matchIDs: [Int] = []
    private let lock = NSLock()

    private var reconnectionManager: ReconnectionManager?

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
        setupReconnectionManager()
    }

    func setInitialOdds(_ odds: [Int: Odds], matchIDs: [Int]) {
        lock.lock()
        defer { lock.unlock() }
        self.currentOddsSnapshot = odds
        self.matchIDs = matchIDs
    }

    func connect() {
        guard connectionState == .disconnected else { return }

        connectionStateSubject.send(.connecting)

        // Simulate brief connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard self?.connectionState == .connecting else { return }
            self?.startStreaming()
        }
    }

    func disconnect() {
        // User-initiated disconnect cancels reconnection
        Task {
            await reconnectionManager?.cancelReconnection()
            await reconnectionManager?.reset()
        }
        stopStreaming()
        connectionStateSubject.send(.disconnected)
    }

    private func startStreaming() {
        connectionStateSubject.send(.connected)
        Task {
            await reconnectionManager?.reset()
        }

        timer = Timer.publish(every: configuration.updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateAndPublishUpdates()
            }
    }

    private func stopStreaming() {
        timer?.cancel()
        timer = nil
    }

    private func generateAndPublishUpdates() {
        lock.lock()
        let ids = matchIDs
        let snapshot = currentOddsSnapshot
        lock.unlock()

        guard !ids.isEmpty else { return }

        // Each tick has probability to produce an update
        // With 10 ticks/sec: 0.5 = avg 5 updates/sec, 1.0 = max 10 updates/sec
        guard Double.random(in: 0...1) < configuration.updateProbability else { return }

        // Select only 1 random match per tick (max 10 updates/sec)
        guard let randomMatchID = ids.randomElement(),
              let currentOdds = snapshot[randomMatchID] else { return }

        let newTeamAOdds = generateVariedOdds(from: currentOdds.teamAOdds)
        let newTeamBOdds = generateVariedOdds(from: currentOdds.teamBOdds)

        let newOdds = Odds(
            matchID: randomMatchID,
            teamAOdds: newTeamAOdds,
            teamBOdds: newTeamBOdds
        )

        lock.lock()
        currentOddsSnapshot[randomMatchID] = newOdds
        lock.unlock()

        oddsSubject.send(newOdds)
    }

    private func generateVariedOdds(from current: Double) -> Double {
        let variation = Double.random(in: configuration.oddsVariationRange)
        let newValue = current + variation

        // Clamp to valid range [1.01, 99.0]
        let clamped = min(max(newValue, 1.01), 99.0)

        return (clamped * 100).rounded() / 100
    }
}

// MARK: - Reconnection

extension MockWebSocketService {

    private func setupReconnectionManager() {
        reconnectionManager = ReconnectionManager(
            configuration: configuration.reconnectionConfig,
            onAttemptReconnect: { [weak self] in
                await self?.attemptReconnect() ?? false
            },
            onStateChange: { [weak self] state in
                self?.connectionStateSubject.send(state)
            }
        )
    }

    /// Simulates a connection loss for testing reconnection behavior.
    func simulateConnectionLoss() {
        stopStreaming()
        Task {
            await reconnectionManager?.startReconnecting()
        }
    }

    /// Attempts to reconnect with simulated network latency.
    /// - Returns: `true` if reconnection succeeded, `false` otherwise.
    private func attemptReconnect() async -> Bool {
        // Simulate network latency
        try? await Task.sleep(for: .milliseconds(100))

        // Simulate success/failure based on configuration
        let success = Double.random(in: 0...1) < configuration.simulatedReconnectionSuccessRate

        if success {
            await MainActor.run {
                startStreaming()
            }
        }

        return success
    }
}
