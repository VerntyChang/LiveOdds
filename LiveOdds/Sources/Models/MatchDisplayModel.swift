import Foundation

struct MatchDisplayModel: Equatable {
    let matchID: Int
    let matchup: String
    let startTime: String
    let teamAOdds: String
    let teamBOdds: String

    // MARK: - Animation
    var teamADirection: Odds.ChangeDirection?
    var teamBDirection: Odds.ChangeDirection?
}
