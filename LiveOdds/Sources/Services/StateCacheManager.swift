import Foundation

actor StateCacheManager {

    static let shared = StateCacheManager()

    private init() {}

    private var cachedSnapshot: StoreSnapshot?

    func cache(_ snapshot: StoreSnapshot) {
        cachedSnapshot = snapshot

        #if DEBUG
        print("[Cache] Stored snapshot with \(snapshot.matchCount) matches")
        #endif
    }

    func retrieve() -> StoreSnapshot? {
        #if DEBUG
        if let snapshot = cachedSnapshot {
            print("[Cache] Retrieved snapshot (age: \(Int(snapshot.age))s)")
        } else {
            print("[Cache] No snapshot available")
        }
        #endif

        return cachedSnapshot
    }

    func invalidate() {
        cachedSnapshot = nil

        #if DEBUG
        print("[Cache] Snapshot invalidated")
        #endif
    }
 
    var hasCache: Bool {
        cachedSnapshot != nil
    }
}
