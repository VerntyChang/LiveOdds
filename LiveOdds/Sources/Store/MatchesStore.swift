import Foundation

actor MatchesStore {

    private var sortedMatches: [Match] = []

    /// O(1) lookup: matchID → array index
    private var idToIndex: [Int: Int] = [:]

    /// O(1) lookup: matchID → Odds
    private var oddsDict: [Int: Odds] = [:]

    var matchCount: Int {
        sortedMatches.count
    }

    func bootstrap(matches: [Match], oddsList: [Odds] = []) {
        // Sort matches once by startTime (ascending - soonest first)
        sortedMatches = matches.sorted { $0.startTime < $1.startTime }

        buildIndexMapping()
        oddsDict = oddsList.reduce(into: [:]) { $0[$1.matchID] = $1 }
    }

    private func buildIndexMapping() {
        idToIndex = [:]
        for (index, match) in sortedMatches.enumerated() {
            idToIndex[match.matchID] = index
        }
    }
}

// MARK: - Query

extension MatchesStore {

    func match(at index: Int) -> Match? {
        guard index >= 0 && index < sortedMatches.count else { return nil }
        return sortedMatches[index]
    }

    func odds(for matchID: Int) -> Odds? {
        oddsDict[matchID]
    }

    func matchWithOdds(at index: Int) -> (match: Match, odds: Odds?)? {
        guard let match = match(at: index) else { return nil }
        return (match, oddsDict[match.matchID])
    }
}

// MARK: - Mutation

extension MatchesStore {

    func updateOdds(_ odds: Odds) -> OddsChangeResult? {
        guard let rowIndex = idToIndex[odds.matchID] else {
            return nil
        }

        let previousOdds = oddsDict[odds.matchID]

        oddsDict[odds.matchID] = odds

        return OddsChangeResult(
            rowIndex: rowIndex,
            matchID: odds.matchID,
            previousOdds: previousOdds,
            currentOdds: odds
        )
    }

    func getAllOdds() -> [Int: Odds] {
        oddsDict
    }

    func getAllMatchIDs() -> [Int] {
        Array(idToIndex.keys)
    }
}

// MARK: - Snapshot

extension MatchesStore {

    func createSnapshot() -> StoreSnapshot {
        StoreSnapshot(
            sortedMatches: sortedMatches,
            oddsDict: oddsDict,
            idToIndex: idToIndex,
            createdAt: Date()
        )
    }

    func restore(from snapshot: StoreSnapshot) {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        #endif

        sortedMatches = snapshot.sortedMatches
        oddsDict = snapshot.oddsDict
        idToIndex = snapshot.idToIndex

        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print("[Perf] Restore from snapshot: \(String(format: "%.2f", elapsed))ms")
        assert(elapsed < 100, "Restore exceeded 100ms target!")
        #endif
    }
}

// MARK: - Testing

#if DEBUG
extension MatchesStore {
    var testSortedMatches: [Match] { sortedMatches }

    func index(for matchID: Int) -> Int? {
        idToIndex[matchID]
    }
 
    func reset() {
        sortedMatches = []
        idToIndex = [:]
        oddsDict = [:]
    }
}
#endif
