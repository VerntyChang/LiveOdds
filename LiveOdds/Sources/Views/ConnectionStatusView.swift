import UIKit

final class ConnectionStatusView: UIView {

    private let statusDot: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 5
        view.backgroundColor = .systemGray
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.text = "Disconnected"
        return label
    }()

    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .systemBackground

        addSubview(stackView)

        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 10),
            statusDot.heightAnchor.constraint(equalToConstant: 10),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }

    func update(for state: ConnectionState) {
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.statusDot.backgroundColor = state.indicatorColor
        }
        statusLabel.text = state.displayText

        if state.isReconnecting {
            startPulseAnimation()
        } else {
            stopPulseAnimation()
        }
    }
 
    private func startPulseAnimation() {
        guard statusDot.layer.animation(forKey: "pulse") == nil else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.4
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        statusDot.layer.add(pulse, forKey: "pulse")
    }

    private func stopPulseAnimation() {
        statusDot.layer.removeAnimation(forKey: "pulse")
        statusDot.layer.opacity = 1.0
    }
}
