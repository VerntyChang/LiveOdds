import Foundation
import QuartzCore
import Combine

final class FPSMonitor {

    @Published private(set) var currentFPS: Int = 0
    private let updateInterval: TimeInterval

    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0

    init(updateInterval: TimeInterval = 1.0) {
        self.updateInterval = updateInterval
    }

    deinit {
        stop()
    }

    func start() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink?.add(to: .main, forMode: .common)
        lastTimestamp = 0
        frameCount = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        currentFPS = 0
    }
 
    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1

        let elapsed = link.timestamp - lastTimestamp

        if elapsed >= updateInterval {
            let fps = Double(frameCount) / elapsed
            currentFPS = Int(round(fps))

            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}
