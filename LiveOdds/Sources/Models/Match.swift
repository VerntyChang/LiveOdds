import Foundation

struct Match: Identifiable, Codable, Equatable {
    let matchID: Int
    let teamA: String
    let teamB: String
    let startTime: Date

    var id: Int { matchID }
}
