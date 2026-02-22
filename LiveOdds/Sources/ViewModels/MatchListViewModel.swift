import Foundation
import Combine

@MainActor
final class MatchListViewModel: ObservableObject {

    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published private(set) var viewState: ViewState = .idle
    @Published private(set) var connectionState: ConnectionState = .disconnected

    let rowsToUpdate = PassthroughSubject<[OddsChangeResult], Never>()

    private let apiService: APIServiceProtocol
    private let webSocketService: WebSocketServiceProtocol?
    private let store: MatchesStore
    private let cacheManager: StateCacheManager
    private let batchingWindowMs: Int

    private(set) var cachedMatchCount: Int = 0

    private var cachedDisplayData: [Int: MatchDisplayModel] = [:]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var cancellables = Set<AnyCancellable>()
    private var oddsUpdatesCancellable: AnyCancellable?

    init(
        apiService: APIServiceProtocol,
        webSocketService: WebSocketServiceProtocol? = nil,
        store: MatchesStore = MatchesStore(),
        cacheManager: StateCacheManager = .shared,
        batchingWindowMs: Int = 200
    ) {
        self.apiService = apiService
        self.webSocketService = webSocketService
        self.store = store
        self.cacheManager = cacheManager
        self.batchingWindowMs = batchingWindowMs

        setupConnectionStateBinding()
    }

    func loadData() async {
        if let snapshot = await cacheManager.retrieve() {
            await store.restore(from: snapshot)
            await refreshCache()
            viewState = cachedMatchCount > 0 ? .loaded : .empty
            await initializeWebSocket()
            return
        }

        viewState = .loading

        do {
            async let matchesTask = apiService.fetchMatches()
            async let oddsTask = fetchOddsGracefully()

            let (matches, odds) = try await (matchesTask, oddsTask)

            await store.bootstrap(matches: matches, oddsList: odds)
            await refreshCache()

            viewState = cachedMatchCount > 0 ? .loaded : .empty

            await cacheCurrentState()
            await initializeWebSocket()
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    func retry() async {
        await loadData()
    }

    func cacheCurrentState() async {
        let snapshot = await store.createSnapshot()
        await cacheManager.cache(snapshot)
    }

    func displayData(at index: Int) -> MatchDisplayModel? {
        cachedDisplayData[index]
    }

    // MARK: - WebSocket Streaming
    func startStreaming() {
        guard let webSocketService = webSocketService,
              webSocketService.connectionState == .disconnected else { return }
        webSocketService.connect()
    }

    func stopStreaming() {
        webSocketService?.disconnect()
    }

    // MARK: - Cache
    private func refreshCache() async {
        cachedMatchCount = await store.matchCount
        cachedDisplayData = [:]

        for index in 0..<cachedMatchCount {
            if let data = await store.matchWithOdds(at: index) {
                cachedDisplayData[index] = makeDisplayModel(from: data.match, odds: data.odds)
            }
        }
    }

    private func updateCacheWithAnimations(for changeResults: [OddsChangeResult]) async {
        for result in changeResults {
            if let data = await store.matchWithOdds(at: result.rowIndex) {
                var displayModel = makeDisplayModel(from: data.match, odds: data.odds)
                displayModel.teamADirection = result.teamADirection
                displayModel.teamBDirection = result.teamBDirection
                cachedDisplayData[result.rowIndex] = displayModel
            }
        }
    }

    func clearAnimation(at index: Int) {
        guard var displayModel = cachedDisplayData[index] else { return }
        displayModel.teamADirection = nil
        displayModel.teamBDirection = nil
        cachedDisplayData[index] = displayModel
    }

    // MARK: - Subscriptions
    private func setupConnectionStateBinding() {
        webSocketService?.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
    }

    private func subscribeToOddsUpdates() {
        guard let webSocketService = webSocketService else { return }

        oddsUpdatesCancellable?.cancel()

        oddsUpdatesCancellable = webSocketService.oddsPublisher
            .collect(.byTime(DispatchQueue.main, .milliseconds(batchingWindowMs)))
            .sink { [weak self] updates in
                guard let self = self, !updates.isEmpty else { return }
                Task {
                    await self.processBatchedUpdates(updates)
                }
            }
    }

    // MARK: - Private Methods
    private func fetchOddsGracefully() async -> [Odds] {
        do {
            return try await apiService.fetchOdds()
        } catch {
            // Log error but don't propagate - allow matches to display
            print("Odds fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func initializeWebSocket() async {
        guard let webSocketService = webSocketService else { return }

        let oddsDict = await store.getAllOdds()
        let matchIDs = await store.getAllMatchIDs()

        if let mockService = webSocketService as? MockWebSocketService {
            mockService.setInitialOdds(oddsDict, matchIDs: matchIDs)
        }

        subscribeToOddsUpdates()

        webSocketService.connect()
    }

    private func processBatchedUpdates(_ updates: [Odds]) async {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        #endif

        var latestUpdates: [Int: Odds] = [:]
        for update in updates {
            latestUpdates[update.matchID] = update
        }

        var changeResults: [OddsChangeResult] = []
        for odds in latestUpdates.values {
            if let changeResult = await store.updateOdds(odds) {
                changeResults.append(changeResult)
            }
        }

        if !changeResults.isEmpty {
            await updateCacheWithAnimations(for: changeResults)
            rowsToUpdate.send(changeResults)

            #if DEBUG
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("[Odds] Batch: \(updates.count) updates → \(changeResults.count) rows | Delay: \(String(format: "%.1f", elapsed))ms")
            #endif
        }
    }

    private func makeDisplayModel(from match: Match, odds: Odds?) -> MatchDisplayModel {
        MatchDisplayModel(
            matchID: match.matchID,
            matchup: "\(match.teamA) vs \(match.teamB)",
            startTime: Self.dateFormatter.string(from: match.startTime),
            teamAOdds: Odds.format(odds?.teamAOdds),
            teamBOdds: Odds.format(odds?.teamBOdds)
        )
    }
}

// MARK: - Testing

#if DEBUG
extension MatchListViewModel {

    func numberOfMatches() async -> Int {
        await store.matchCount
    }

    func match(at index: Int) async -> Match? {
        await store.match(at: index)
    }

    func odds(for matchID: Int) async -> Odds? {
        await store.odds(for: matchID)
    }
 
    func matchWithOdds(at index: Int) async -> (match: Match, odds: Odds?)? {
        await store.matchWithOdds(at: index)
    }
}
#endif
