import Foundation

struct StoreSnapshot: Sendable {

    /// Matches sorted by start time (ascending)
    let sortedMatches: [Match]

    /// Odds dictionary: matchID → Odds
    let oddsDict: [Int: Odds]

    /// Index mapping: matchID → array index
    let idToIndex: [Int: Int]

    /// Timestamp when snapshot was created
    let createdAt: Date

    var matchCount: Int {
        sortedMatches.count
    }

    /// Age of the snapshot in seconds (used for DEBUG logging)
    var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }
}
