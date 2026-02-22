import UIKit
import Combine

final class FPSOverlayView: UIView {

    private let fpsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .right
        return label
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
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 6

        addSubview(fpsLabel)

        NSLayoutConstraint.activate([
            fpsLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            fpsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            fpsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            fpsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])

        updateFPS(0)
    }
 
    func updateFPS(_ fps: Int) {
        let color: UIColor
        if fps >= 55 {
            color = .systemGreen
        } else if fps >= 30 {
            color = .systemYellow
        } else {
            color = .systemRed
        }

        fpsLabel.text = "\(fps) FPS"
        fpsLabel.textColor = color
    }
}
