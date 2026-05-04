import UIKit

final class PersonaCell: UICollectionViewCell {
    static let reuseID = "PersonaCell"

    // Exposed so the transition animator can read its frame
    let card = SFCardView()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = SFColors.secondaryBackground
        iv.tintColor = SFColors.tertiaryLabel
        iv.image = UIImage(systemName: "person.crop.rectangle.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 36, weight: .thin))
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let gradientLayer: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.75).cgColor]
        g.locations = [0.38, 1.0]
        return g
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.title3()
        l.textColor = UIColor(hex: "#F0EAE0")
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusBadge: UILabel = {
        let l = UILabel()
        l.font = SFTypography.captionMedium()
        l.layer.cornerRadius = SFSpacing.badgeRadius
        l.layer.cornerCurve = .continuous
        l.clipsToBounds = true
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        contentView.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        card.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        imageView.layer.cornerRadius = SFSpacing.cardRadius
        imageView.layer.cornerCurve = .continuous

        card.layer.addSublayer(gradientLayer)

        card.addSubview(nameLabel)
        card.addSubview(statusBadge)
        NSLayoutConstraint.activate([
            statusBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            statusBadge.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.md),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),

            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.md),
            nameLabel.bottomAnchor.constraint(equalTo: statusBadge.topAnchor, constant: -4),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = card.bounds
    }

    func configure(with persona: Persona) {
        nameLabel.text = persona.name

        if let path = persona.localCoverImagePath,
           let img = ImageStorageManager.shared.load(fromPath: path) {
            imageView.image = img
            imageView.contentMode = .scaleAspectFill
        } else {
            imageView.image = UIImage(systemName: "person.crop.rectangle.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 36, weight: .thin))
            imageView.contentMode = .scaleAspectFit
        }

        // Only surface non-happy states — a "Ready" card needs no label
        switch persona.status {
        case .ready, .draft:
            statusBadge.isHidden = true
        case .uploading:
            statusBadge.isHidden = false
            statusBadge.text = "  Uploading…  "
            statusBadge.backgroundColor = SFColors.warning.withAlphaComponent(0.18)
            statusBadge.textColor = SFColors.warning
        case .processing:
            statusBadge.isHidden = false
            statusBadge.text = "  Training  "
            statusBadge.backgroundColor = SFColors.accentLight
            statusBadge.textColor = SFColors.accent
        case .failed:
            statusBadge.isHidden = false
            statusBadge.text = "  Failed  "
            statusBadge.backgroundColor = SFColors.destructive.withAlphaComponent(0.18)
            statusBadge.textColor = SFColors.destructive
        }
    }

    override var isHighlighted: Bool {
        didSet { card.animatePress(down: isHighlighted) }
    }
}
