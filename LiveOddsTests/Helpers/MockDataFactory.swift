import Foundation
@testable import LiveOdds

/// Factory for creating test data with optional overrides.
enum MockDataFactory {

    // MARK: - Match Factory

    static func makeMatch(
        matchID: Int = 1001,
        teamA: String = "Eagles",
        teamB: String = "Tigers",
        startTime: Date = Date()
    ) -> Match {
        Match(
            matchID: matchID,
            teamA: teamA,
            teamB: teamB,
            startTime: startTime
        )
    }

    static func makeMatches(count: Int) -> [Match] {
        (0..<count).map { index in
            makeMatch(
                matchID: 1001 + index,
                teamA: "Team \(index * 2)",
                teamB: "Team \(index * 2 + 1)",
                startTime: Date().addingTimeInterval(Double(index * 3600))
            )
        }
    }

    // MARK: - Odds Factory

    static func makeOdds(
        matchID: Int = 1001,
        teamAOdds: Double = 1.95,
        teamBOdds: Double = 2.10
    ) -> Odds {
        Odds(
            matchID: matchID,
            teamAOdds: teamAOdds,
            teamBOdds: teamBOdds
        )
    }

    static func makeOddsList(for matches: [Match]) -> [Odds] {
        matches.map { match in
            makeOdds(
                matchID: match.matchID,
                teamAOdds: Double.random(in: 1.10...5.00).rounded(toPlaces: 2),
                teamBOdds: Double.random(in: 1.10...5.00).rounded(toPlaces: 2)
            )
        }
    }

    // MARK: - Snapshot Factory

    static func makeSnapshot(matchCount: Int, createdAt: Date = Date()) -> StoreSnapshot {
        let matches = makeMatches(count: matchCount)
        let sortedMatches = matches.sorted { $0.startTime < $1.startTime }
        let odds = makeOddsList(for: matches)
        let oddsDict = Dictionary(uniqueKeysWithValues: odds.map { ($0.matchID, $0) })
        let idToIndex = Dictionary(uniqueKeysWithValues: sortedMatches.enumerated().map { ($1.matchID, $0) })

        return StoreSnapshot(
            sortedMatches: sortedMatches,
            oddsDict: oddsDict,
            idToIndex: idToIndex,
            createdAt: createdAt
        )
    }
}

// MARK: - Double Extension for Rounding

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
