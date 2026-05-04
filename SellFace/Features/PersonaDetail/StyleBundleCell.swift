import UIKit

final class StyleBundleCell: UICollectionViewCell {
    static let reuseID = "StyleBundleCell"

    let card = SFCardView()

    private let iconContainer: UIView = {
        let v = UIView()
        v.backgroundColor = SFColors.secondaryBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = SFColors.accent
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let lockOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let lockIcon: UIImageView = {
        let iv = UIImageView(
            image: UIImage(systemName: "lock.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        )
        iv.tintColor = SFColors.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.headline()
        l.textColor = SFColors.label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let oldPriceLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.strikePrice()
        l.textColor = SFColors.strikethroughPrice
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let priceLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.price()
        l.textColor = SFColors.livePrice
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let accentLine: UIView = {
        let v = UIView()
        v.backgroundColor = SFColors.accent
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
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

        [iconContainer, lockOverlay, lockIcon, nameLabel, oldPriceLabel, priceLabel, accentLine]
            .forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            accentLine.topAnchor.constraint(equalTo: card.topAnchor),
            accentLine.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            accentLine.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            accentLine.heightAnchor.constraint(equalToConstant: 2),

            iconContainer.topAnchor.constraint(equalTo: accentLine.bottomAnchor),
            iconContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            iconContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            iconContainer.heightAnchor.constraint(equalTo: iconContainer.widthAnchor, multiplier: 0.85),

            lockOverlay.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            lockOverlay.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor),
            lockOverlay.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor),
            lockOverlay.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),

            lockIcon.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            lockIcon.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: SFSpacing.sm),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.sm),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.xs),

            oldPriceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            oldPriceLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.sm),
            oldPriceLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.sm),

            priceLabel.centerYAnchor.constraint(equalTo: oldPriceLabel.centerYAnchor),
            priceLabel.leadingAnchor.constraint(equalTo: oldPriceLabel.trailingAnchor, constant: SFSpacing.xs),
        ])

        iconContainer.addSubview(previewImageView)
        NSLayoutConstraint.activate([
            previewImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            previewImageView.widthAnchor.constraint(equalToConstant: 36),
            previewImageView.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    func configure(with bundle: StyleBundle) {
        nameLabel.text = bundle.name
        let sym = UIImage.SymbolConfiguration(pointSize: 28, weight: .light)
        previewImageView.image = UIImage(systemName: bundle.previewImageName, withConfiguration: sym)

        if bundle.isUnlocked {
            lockOverlay.isHidden = true
            lockIcon.isHidden    = true
            accentLine.isHidden  = false
            priceLabel.text = "Unlocked"
            priceLabel.textColor = SFColors.success
            oldPriceLabel.text = nil
        } else {
            lockOverlay.isHidden = false
            lockIcon.isHidden    = false
            accentLine.isHidden  = true
            if let old = bundle.oldPrice {
                oldPriceLabel.attributedText = NSAttributedString(
                    string: old,
                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                 .foregroundColor: SFColors.strikethroughPrice]
                )
            } else { oldPriceLabel.text = nil }
            priceLabel.text = bundle.price
            priceLabel.textColor = SFColors.livePrice
        }
    }

    override var isHighlighted: Bool {
        didSet { card.animatePress(down: isHighlighted) }
    }
}
