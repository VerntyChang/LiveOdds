import UIKit

final class OddsLabel: UILabel {

    private enum AnimationConfig {
        static let fadeInDuration: CFTimeInterval = 0.10
        static let holdDuration: CFTimeInterval = 0.5    // 顏色持續顯示時間
        static let fadeOutDuration: CFTimeInterval = 0.10
        static let totalDuration: CFTimeInterval = 0.7  // 0.10 + 0.5 + 0.10
        static let peakOpacity: Float = 0.3
        static let cornerRadius: CGFloat = 4.0
        static let animationKey = "oddsFlash"
    }

    private lazy var flashLayer: CALayer = {
        let layer = CALayer()
        layer.cornerRadius = AnimationConfig.cornerRadius
        layer.opacity = 0
        layer.masksToBounds = true
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFlashLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFlashLayer()
    }

    private func setupFlashLayer() {
        layer.insertSublayer(flashLayer, at: 0)
    }

    func flash(direction: Odds.ChangeDirection) {
        guard direction != .none else { return }
        performFlashAnimation(direction: direction)
    }

    private func performFlashAnimation(direction: Odds.ChangeDirection) {
        flashLayer.removeAnimation(forKey: AnimationConfig.animationKey)

        let color: UIColor = direction == .up ? .systemGreen : .systemRed
        flashLayer.backgroundColor = color.cgColor

        let fadeInEnd = AnimationConfig.fadeInDuration / AnimationConfig.totalDuration
        let holdEnd = (AnimationConfig.fadeInDuration + AnimationConfig.holdDuration) / AnimationConfig.totalDuration

        // Create keyframe animation for smooth fade in -> hold -> fade out
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [
            0,                              // Start: transparent
            AnimationConfig.peakOpacity,    // After fade in: visible
            AnimationConfig.peakOpacity,    // During hold: stay visible
            0                               // After fade out: transparent
        ]
        animation.keyTimes = [
            0,                              // t=0
            NSNumber(value: fadeInEnd),     // t=fadeIn end
            NSNumber(value: holdEnd),       // t=hold end
            1                               // t=total end
        ]
        animation.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),   // fade in
            CAMediaTimingFunction(name: .linear),   // hold (no change)
            CAMediaTimingFunction(name: .easeOut)   // fade out
        ]
        animation.duration = AnimationConfig.totalDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = true

        flashLayer.add(animation, forKey: AnimationConfig.animationKey)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure flash layer covers entire label without implicit animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flashLayer.frame = bounds
        CATransaction.commit()
    }
 
    /// Cancels any ongoing animation (called on cell reuse).
    func cancelAnimation() {
        flashLayer.removeAnimation(forKey: AnimationConfig.animationKey)
        flashLayer.opacity = 0
    }
}
