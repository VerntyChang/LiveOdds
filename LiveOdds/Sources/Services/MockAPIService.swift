import Foundation

final class MockAPIService: APIServiceProtocol, @unchecked Sendable {

    struct Configuration: Sendable {
        var matchCount: Int
        var simulatedDelayMatches: TimeInterval
        var simulatedDelayOdds: TimeInterval
        var shouldFailMatches: Bool
        var shouldFailOdds: Bool
        var matchesWithMissingOdds: Set<Int>
        var failureError: APIError

        init(
            matchCount: Int = 100,
            simulatedDelay: TimeInterval = 0.3,
            simulatedDelayMatches: TimeInterval? = nil,
            simulatedDelayOdds: TimeInterval? = nil,
            shouldFail: Bool = false,
            shouldFailMatches: Bool? = nil,
            shouldFailOdds: Bool = false,
            matchesWithMissingOdds: Set<Int> = [],
            failureError: APIError = .networkError(underlying: URLError(.notConnectedToInternet))
        ) {
            self.matchCount = matchCount
            self.simulatedDelayMatches = simulatedDelayMatches ?? simulatedDelay
            self.simulatedDelayOdds = simulatedDelayOdds ?? simulatedDelay
            self.shouldFailMatches = shouldFailMatches ?? shouldFail
            self.shouldFailOdds = shouldFailOdds
            self.matchesWithMissingOdds = matchesWithMissingOdds
            self.failureError = failureError
        }
    }

    private let configuration: Configuration

    private var generatedMatches: [Match]?

    private let teamNames = [
        "Eagles", "Tigers", "Warriors", "Lions", "Sharks",
        "Panthers", "Wolves", "Bears", "Falcons", "Hawks",
        "Cobras", "Dragons", "Phoenix", "Thunder", "Storm",
        "Titans", "Giants", "Knights", "Spartans", "Vikings"
    ]

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
    }

    func fetchMatches() async throws -> [Match] {
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(Int(configuration.simulatedDelayMatches * 1000)))

        // Simulate failure if configured
        if configuration.shouldFailMatches {
            throw configuration.failureError
        }

        let matches = generateMockMatches(count: configuration.matchCount)
        generatedMatches = matches
        return matches
    }

    func fetchOdds() async throws -> [Odds] {
        try await Task.sleep(for: .milliseconds(Int(configuration.simulatedDelayOdds * 1000)))

        if configuration.shouldFailOdds {
            throw configuration.failureError
        }

        let matchIDs: [Int]
        if let cached = generatedMatches {
            matchIDs = cached.map { $0.matchID }
        } else {
            matchIDs = (0..<configuration.matchCount).map { 1001 + $0 }
        }

        return generateMockOdds(for: matchIDs)
    }

    private func generateMockMatches(count: Int) -> [Match] {
        var matches: [Match] = []
        let now = Date()
        let sevenDaysInSeconds: TimeInterval = 7 * 24 * 60 * 60

        for index in 0..<count {
            let teamAIndex = Int.random(in: 0..<teamNames.count)
            var teamBIndex = Int.random(in: 0..<teamNames.count)

            while teamBIndex == teamAIndex {
                teamBIndex = Int.random(in: 0..<teamNames.count)
            }

            let randomTimeOffset = TimeInterval.random(in: 0...sevenDaysInSeconds)
            let startTime = now.addingTimeInterval(randomTimeOffset)

            let match = Match(
                matchID: 1001 + index,
                teamA: teamNames[teamAIndex],
                teamB: teamNames[teamBIndex],
                startTime: startTime
            )

            matches.append(match)
        }

        return matches
    }

    private func generateMockOdds(for matchIDs: [Int]) -> [Odds] {
        matchIDs.compactMap { matchID in
            guard !configuration.matchesWithMissingOdds.contains(matchID) else {
                return nil
            }

            let (teamA, teamB) = generateOddsPair()
            return Odds(matchID: matchID, teamAOdds: teamA, teamBOdds: teamB)
        }
    }

    private func generateOddsPair() -> (teamA: Double, teamB: Double) {
        // Generate realistic odds with inverse relationship
        let teamAProbability = Double.random(in: 0.30...0.70)
        let teamBProbability = 1.0 - teamAProbability

        let margin = 1.05
        var teamAOdds = (1.0 / teamAProbability) * margin
        var teamBOdds = (1.0 / teamBProbability) * margin

        // Clamp to valid range
        teamAOdds = min(max(teamAOdds, 1.01), 99.0)
        teamBOdds = min(max(teamBOdds, 1.01), 99.0)

        teamAOdds = (teamAOdds * 100).rounded() / 100
        teamBOdds = (teamBOdds * 100).rounded() / 100

        return (teamAOdds, teamBOdds)
    }
}
