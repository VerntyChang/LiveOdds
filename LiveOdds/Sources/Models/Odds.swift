import Foundation

struct Odds: Codable, Equatable {
    let matchID: Int
    let teamAOdds: Double
    let teamBOdds: Double
}

extension Odds {

    enum ChangeDirection: Equatable {
        case up    // Odds increased (green flash)
        case down  // Odds decreased (red flash)
        case none  // No change (no animation)
    }

    static func direction(from oldValue: Double?, to newValue: Double) -> ChangeDirection {
        guard let oldValue = oldValue else { return .none }
        if newValue > oldValue { return .up }
        if newValue < oldValue { return .down }
        return .none
    }
}

extension Odds {
    static let placeholder = "--"

    static func format(_ value: Double?) -> String {
        guard let value = value else { return placeholder }
        return String(format: "%.2f", value)
    }
 
    var isValid: Bool {
        (1.01...99.0).contains(teamAOdds) && (1.01...99.0).contains(teamBOdds)
    }
}
