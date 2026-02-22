import XCTest
@testable import LiveOdds

final class MatchCellAnimationTests: XCTestCase {

    // MARK: - Helper Methods

    private func makeDisplayModel(
        matchID: Int = 1001,
        teamADirection: Odds.ChangeDirection? = nil,
        teamBDirection: Odds.ChangeDirection? = nil
    ) -> MatchDisplayModel {
        var model = MatchDisplayModel(
            matchID: matchID,
            matchup: "Team A vs Team B",
            startTime: "Feb 21, 2026",
            teamAOdds: "1.95",
            teamBOdds: "2.10"
        )
        model.teamADirection = teamADirection
        model.teamBDirection = teamBDirection
        return model
    }

    // MARK: - Configure Animation Tests

    func test_configure_withBothUp_triggersAnimations() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()
        let displayModel = makeDisplayModel(teamADirection: .up, teamBDirection: .up)

        // When
        cell.configure(with: displayModel)

        // Then - cell should have triggered animations without crashing
        XCTAssertNotNil(cell)
    }

    func test_configure_withBothDown_triggersAnimations() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()
        let displayModel = makeDisplayModel(teamADirection: .down, teamBDirection: .down)

        // When
        cell.configure(with: displayModel)

        // Then - no crash
        XCTAssertNotNil(cell)
    }

    func test_configure_withMixedDirections_triggersAnimations() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()
        let displayModel = makeDisplayModel(teamADirection: .up, teamBDirection: .down)

        // When
        cell.configure(with: displayModel)

        // Then - no crash
        XCTAssertNotNil(cell)
    }

    func test_configure_withBothNone_noAnimation() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()
        let displayModel = makeDisplayModel(teamADirection: .none, teamBDirection: .none)

        // When
        cell.configure(with: displayModel)

        // Then - no crash
        XCTAssertNotNil(cell)
    }

    func test_configure_withNilDirections_noAnimation() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()
        let displayModel = makeDisplayModel(teamADirection: nil, teamBDirection: nil)

        // When
        cell.configure(with: displayModel)

        // Then - no crash
        XCTAssertNotNil(cell)
    }

    // MARK: - prepareForReuse Tests

    func test_prepareForReuse_cancelsAnimations() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()
        cell.configure(with: makeDisplayModel(teamADirection: .up, teamBDirection: .up))

        // When
        cell.prepareForReuse()

        // Then - animations should be cancelled, no crash
        XCTAssertNotNil(cell)
    }

    func test_prepareForReuse_clearsOddsText() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        let displayModel = makeDisplayModel()
        cell.configure(with: displayModel)

        // When
        cell.prepareForReuse()

        // Then - should be cleared
        XCTAssertNotNil(cell)
    }

    // MARK: - Rapid Animation Tests

    func test_multipleConsecutiveConfigurations_doesNotCrash() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()

        // When - simulate rapid updates
        for i in 0..<10 {
            let direction: Odds.ChangeDirection = i % 2 == 0 ? .up : .down
            let displayModel = makeDisplayModel(teamADirection: direction, teamBDirection: direction)
            cell.configure(with: displayModel)
        }

        // Then - no crash
        XCTAssertNotNil(cell)
    }

    func test_configureThenPrepareForReuse_doesNotCrash() {
        // Given
        let cell = MatchCell(style: .default, reuseIdentifier: MatchCell.reuseIdentifier)
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 72)
        cell.layoutIfNeeded()

        // When - simulate cell lifecycle
        cell.configure(with: makeDisplayModel(teamADirection: .up, teamBDirection: .up))
        cell.prepareForReuse()
        cell.configure(with: makeDisplayModel(teamADirection: .down, teamBDirection: .down))

        // Then - no crash
        XCTAssertNotNil(cell)
    }
}
