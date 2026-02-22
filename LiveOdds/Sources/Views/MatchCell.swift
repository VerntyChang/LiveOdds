import UIKit

final class MatchCell: UITableViewCell {

    static let reuseIdentifier = "MatchCell"

    private lazy var matchupLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.numberOfLines = 1
        return label
    }()

    private lazy var startTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private lazy var teamAOddsLabel: OddsLabel = {
        let label = OddsLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()

    private lazy var teamBOddsLabel: OddsLabel = {
        let label = OddsLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()

    private lazy var oddsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [teamAOddsLabel, teamBOddsLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 16
        return stack
    }()

    private lazy var infoStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [matchupLabel, startTimeLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()

    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [infoStackView, oddsStackView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 16
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(mainStackView)

        let heightConstraint = contentView.heightAnchor.constraint(equalToConstant: 72)

        let oddsWidth: CGFloat = 60
        teamAOddsLabel.widthAnchor.constraint(equalToConstant: oddsWidth).isActive = true
        teamBOddsLabel.widthAnchor.constraint(equalToConstant: oddsWidth).isActive = true

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            heightConstraint
        ])
    }

    func configure(with model: MatchDisplayModel) {
        matchupLabel.text = model.matchup
        startTimeLabel.text = model.startTime
        teamAOddsLabel.text = model.teamAOdds
        teamBOddsLabel.text = model.teamBOdds

        if let direction = model.teamADirection {
            teamAOddsLabel.flash(direction: direction)
        }
        if let direction = model.teamBDirection {
            teamBOddsLabel.flash(direction: direction)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        matchupLabel.text = nil
        startTimeLabel.text = nil
        teamAOddsLabel.text = "--"
        teamBOddsLabel.text = "--"
        
        teamAOddsLabel.cancelAnimation()
        teamBOddsLabel.cancelAnimation()
    }
}
