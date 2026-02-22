import UIKit
import Combine

final class MatchListViewController: UIViewController {
 
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(MatchCell.self, forCellReuseIdentifier: MatchCell.reuseIdentifier)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 72
        return table
    }()

    private lazy var loadingView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var errorView: ErrorView = {
        let view = ErrorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.onRetry = { [weak self] in
            self?.handleRetry()
        }
        return view
    }()

    private lazy var emptyView: EmptyStateView = {
        let view = EmptyStateView(message: "No matches available")
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private lazy var connectionStatusView: ConnectionStatusView = {
        let view = ConnectionStatusView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    #if DEBUG
    private lazy var fpsOverlayView: FPSOverlayView = {
        let view = FPSOverlayView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let fpsMonitor = FPSMonitor()
    #endif

    private let viewModel: MatchListViewModel
    private var cancellables = Set<AnyCancellable>()

    private var isScrolling: Bool = false

    /// Pending updates to apply after scrolling stops.
    private var pendingChangeResults: [OddsChangeResult] = []

    init(viewModel: MatchListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        bindRowUpdates()
        #if DEBUG
        bindFPSMonitor()
        #endif

        Task {
            await viewModel.loadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startStreaming()
        #if DEBUG
        fpsMonitor.start()
        #endif
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopStreaming()

        Task {
            await viewModel.cacheCurrentState()
        }

        #if DEBUG
        fpsMonitor.stop()
        #endif
    }

    private func setupUI() {
        title = "Live Odds"
        view.backgroundColor = .systemBackground

        view.addSubview(tableView)
        view.addSubview(loadingView)
        view.addSubview(errorView)
        view.addSubview(emptyView)
        view.addSubview(connectionStatusView)
        #if DEBUG
        view.addSubview(fpsOverlayView)
        #endif

        NSLayoutConstraint.activate([
            connectionStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            connectionStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            connectionStatusView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: connectionStatusView.topAnchor),

            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            errorView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        #if DEBUG
        NSLayoutConstraint.activate([
            fpsOverlayView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            fpsOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
        #endif
    }

    private func bindViewModel() {
        viewModel.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        viewModel.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionStatusView.update(for: state)
            }
            .store(in: &cancellables)
    }

    private func bindRowUpdates() {
        viewModel.rowsToUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] changeResults in
                self?.handleRowUpdates(changeResults)
            }
            .store(in: &cancellables)
    }

    #if DEBUG
    private func bindFPSMonitor() {
        fpsMonitor.$currentFPS
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fps in
                self?.fpsOverlayView.updateFPS(fps)
            }
            .store(in: &cancellables)
    }
    #endif

    private func handleStateChange(_ state: MatchListViewModel.ViewState) {
        // Hide all state views first
        loadingView.stopAnimating()
        errorView.isHidden = true
        emptyView.isHidden = true
        tableView.isHidden = true

        switch state {
        case .idle:
            break

        case .loading:
            loadingView.startAnimating()

        case .loaded:
            tableView.isHidden = false
            tableView.reloadData()

        case .empty:
            emptyView.isHidden = false

        case .error(let message):
            errorView.isHidden = false
            errorView.configure(message: message)
        }
    }

    private func handleRetry() {
        Task {
            await viewModel.retry()
        }
    }

    private func handleRowUpdates(_ changeResults: [OddsChangeResult]) {
        if isScrolling {
            pendingChangeResults.append(contentsOf: changeResults)
        } else {
            applyUpdates(changeResults)
        }
    }

    private func applyUpdates(_ changeResults: [OddsChangeResult]) {
        let rowIndices = changeResults.map { $0.rowIndex }
        let indexPaths = rowIndices.map { IndexPath(row: $0, section: 0) }
        let visibleIndexPaths = tableView.indexPathsForVisibleRows ?? []
        let toReload = indexPaths.filter { visibleIndexPaths.contains($0) }

        if !toReload.isEmpty {
            UIView.performWithoutAnimation {
                tableView.reloadRows(at: toReload, with: .none)
            }
        }

        // Clear animation directions for non-visible rows
        let visibleSet = Set(visibleIndexPaths)
        for indexPath in indexPaths where !visibleSet.contains(indexPath) {
            viewModel.clearAnimation(at: indexPath.row)
        }
    }

    private func applyPendingUpdates() {
        guard !pendingChangeResults.isEmpty else { return }

        // Deduplicate by rowIndex (keep latest change result per row)
        var latestResults: [Int: OddsChangeResult] = [:]
        for result in pendingChangeResults {
            latestResults[result.rowIndex] = result
        }

        applyUpdates(Array(latestResults.values))
        pendingChangeResults.removeAll()
    }
}

extension MatchListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.cachedMatchCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MatchCell.reuseIdentifier,
            for: indexPath
        ) as? MatchCell else {
            return UITableViewCell()
        }

        if var displayModel = viewModel.displayData(at: indexPath.row) {
            // Skip animation during scrolling
            if isScrolling {
                displayModel.teamADirection = nil
                displayModel.teamBDirection = nil
            }
            cell.configure(with: displayModel)

            // Clear animation directions after configure to prevent re-animation
            viewModel.clearAnimation(at: indexPath.row)
        }

        return cell
    }
}

extension MatchListViewController: UITableViewDelegate {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isScrolling = false
            applyPendingUpdates()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrolling = false
        applyPendingUpdates()
    }
}
