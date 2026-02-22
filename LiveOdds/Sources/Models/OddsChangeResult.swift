import Foundation

struct OddsChangeResult: Equatable {
    /// Row index in the table view
    let rowIndex: Int

    let matchID: Int
    let teamADirection: Odds.ChangeDirection
    let teamBDirection: Odds.ChangeDirection

    init(
        rowIndex: Int,
        matchID: Int,
        previousOdds: Odds?,
        currentOdds: Odds
    ) {
        self.rowIndex = rowIndex
        self.matchID = matchID
        self.teamADirection = Odds.direction(
            from: previousOdds?.teamAOdds,
            to: currentOdds.teamAOdds
        )
        self.teamBDirection = Odds.direction(
            from: previousOdds?.teamBOdds,
            to: currentOdds.teamBOdds
        )
    }

    /// Direct initializer with directions (for testing).
    init(
        rowIndex: Int,
        matchID: Int,
        teamADirection: Odds.ChangeDirection,
        teamBDirection: Odds.ChangeDirection
    ) {
        self.rowIndex = rowIndex
        self.matchID = matchID
        self.teamADirection = teamADirection
        self.teamBDirection = teamBDirection
    }

    var hasAnimation: Bool {
        teamADirection != .none || teamBDirection != .none
    }
}
