import XCTest
@testable import LiveOdds

final class OddsLabelTests: XCTestCase {

    // MARK: - Initialization Tests

    func test_init_createsFlashLayer() {
        // Given/When
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))

        // Then
        XCTAssertNotNil(label.layer.sublayers)
        XCTAssertGreaterThanOrEqual(label.layer.sublayers?.count ?? 0, 1)
    }

    func test_init_flashLayerIsAtBottom() {
        // Given/When
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertNotNil(flashLayer)
        XCTAssertEqual(flashLayer?.opacity, 0)
    }

    // MARK: - Flash Animation Tests

    func test_flash_up_appliesGreenColor() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // When
        label.flash(direction: .up)

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.backgroundColor, UIColor.systemGreen.cgColor)
    }

    func test_flash_down_appliesRedColor() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // When
        label.flash(direction: .down)

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.backgroundColor, UIColor.systemRed.cgColor)
    }

    func test_flash_none_noAnimation() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // When
        label.flash(direction: .none)

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertNil(flashLayer?.animation(forKey: "oddsFlash"))
    }

    func test_flash_up_addsAnimation() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // When
        label.flash(direction: .up)

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertNotNil(flashLayer?.animation(forKey: "oddsFlash"))
    }

    func test_flash_down_addsAnimation() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // When
        label.flash(direction: .down)

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertNotNil(flashLayer?.animation(forKey: "oddsFlash"))
    }

    // MARK: - Cancel Animation Tests

    func test_cancelAnimation_removesOngoingAnimation() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()
        label.flash(direction: .up)

        // When
        label.cancelAnimation()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertNil(flashLayer?.animation(forKey: "oddsFlash"))
    }

    func test_cancelAnimation_resetsOpacityToZero() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()
        label.flash(direction: .up)

        // When
        label.cancelAnimation()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.opacity, 0)
    }

    func test_cancelAnimation_whenNoAnimation_doesNotCrash() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))

        // When/Then - should not crash
        label.cancelAnimation()

        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.opacity, 0)
    }

    // MARK: - Layout Tests

    func test_layoutSubviews_updatesFlashLayerFrame() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))

        // When
        label.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        label.layoutIfNeeded()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.frame, label.bounds)
    }

    func test_layoutSubviews_flashLayerMatchesLabelBounds() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 10, y: 20, width: 80, height: 40))

        // When
        label.layoutIfNeeded()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.frame.width, 80)
        XCTAssertEqual(flashLayer?.frame.height, 40)
        XCTAssertEqual(flashLayer?.frame.origin.x, 0)
        XCTAssertEqual(flashLayer?.frame.origin.y, 0)
    }

    // MARK: - Animation Configuration Tests

    func test_flashLayer_hasCorrectCornerRadius() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))

        // When
        label.layoutIfNeeded()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.cornerRadius, 4.0)
    }

    func test_flashLayer_masksToBounds() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))

        // When
        label.layoutIfNeeded()

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.masksToBounds, true)
    }

    // MARK: - Rapid Animation Tests

    func test_flash_multipleConsecutiveCalls_doesNotCrash() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()

        // When/Then - should not crash
        for _ in 0..<10 {
            label.flash(direction: .up)
            label.flash(direction: .down)
        }

        let flashLayer = label.layer.sublayers?.first
        XCTAssertNotNil(flashLayer)
    }

    func test_flash_replacesExistingAnimation() {
        // Given
        let label = OddsLabel(frame: CGRect(x: 0, y: 0, width: 60, height: 30))
        label.layoutIfNeeded()
        label.flash(direction: .up)

        // When
        label.flash(direction: .down)

        // Then
        let flashLayer = label.layer.sublayers?.first
        XCTAssertEqual(flashLayer?.backgroundColor, UIColor.systemRed.cgColor)
        XCTAssertNotNil(flashLayer?.animation(forKey: "oddsFlash"))
    }
}
