import UIKit

final class PersonaCell: UICollectionViewCell {
    static let reuseID = "PersonaCell"

    // Exposed so the transition animator can read its frame
    let card = SFCardView()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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

    // Name sits outside the card, below it
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.headline()
        l.textColor = SFColors.label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Pre-saved smooth dark palette — harmonises with #07070F background
    private static let placeholderColors: [UIColor] = [
        UIColor(hex: "#141420"),  // deep charcoal-navy
        UIColor(hex: "#091624"),  // deep ocean navy
        UIColor(hex: "#0F1410"),  // deep forest
        UIColor(hex: "#190A0F"),  // deep wine
        UIColor(hex: "#14100A"),  // deep amber
        UIColor(hex: "#0A0F1E"),  // deep indigo
        UIColor(hex: "#0F1918"),  // deep teal
        UIColor(hex: "#1E0A14"),  // deep rose
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            // Square card — fills full width, height = width
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.heightAnchor.constraint(equalTo: card.widthAnchor),

            // Name label below the card, left-aligned
            nameLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: SFSpacing.sm),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        card.addSubview(imageView)
        card.addSubview(statusBadge)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: card.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            statusBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.sm),
            statusBadge.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.sm),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
        ])

        imageView.layer.cornerRadius = SFSpacing.cardRadius
        imageView.layer.cornerCurve = .continuous
    }

    func configure(with persona: Persona) {
        nameLabel.text = persona.name

        // Consistent color per persona derived from its ID
        let colorIndex = abs(persona.id.hashValue) % Self.placeholderColors.count
        card.backgroundColor = Self.placeholderColors[colorIndex]

        if let path = persona.localCoverImagePath,
           let img = ImageStorageManager.shared.load(fromPath: path) {
            imageView.image = img
            imageView.isHidden = false
        } else {
            imageView.image = nil
            imageView.isHidden = true
        }

        switch persona.status {
        case .ready, .draft:
            statusBadge.isHidden = true
        case .uploading:
            statusBadge.isHidden = false
            statusBadge.text = "  Uploading…  "
            statusBadge.backgroundColor = SFColors.warning.withAlphaComponent(0.18)
            statusBadge.textColor = SFColors.warning
        case .processing:
            statusBadge.isHidden = true
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
