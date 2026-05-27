import UIKit

final class StyleBundleCell: UICollectionViewCell {
    static let reuseID = "StyleBundleCell"

    let card = SFCardView()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = SFColors.accent
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let generatedImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()


    private let creatingBadge: UILabel = {
        let l = UILabel()
        l.text = "  Creating…  "
        l.font = SFTypography.captionMedium()
        l.backgroundColor = SFColors.accentLight
        l.textColor = SFColors.accent
        l.layer.cornerRadius = SFSpacing.badgeRadius
        l.layer.cornerCurve = .continuous
        l.clipsToBounds = true
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let shimmerView: SFShimmerView = {
        let v = SFShimmerView()
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let timeEstimateLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.captionMedium()
        l.textColor = SFColors.accent
        l.backgroundColor = SFColors.accentLight
        l.layer.cornerRadius = SFSpacing.badgeRadius
        l.layer.cornerCurve = .continuous
        l.clipsToBounds = true
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Below-card labels
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.headline()
        l.textColor = SFColors.label
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let oldPriceLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.strikePrice()
        l.textColor = SFColors.strikethroughPrice
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let priceLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.price()
        l.textColor = SFColors.accent
        l.textAlignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // First-purchase only — short description below name
    private let taglineLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.footnote()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 2
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Stored constraint refs for the dynamic price-label top anchor
    private var priceLabelTopToCard: NSLayoutConstraint!
    private var priceLabelTopToOldPrice: NSLayoutConstraint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        generatedImageView.image = nil
        generatedImageView.isHidden = true
        iconImageView.isHidden = false
        priceLabel.isHidden = false
        shimmerView.stopAnimating()
        shimmerView.isHidden = true
        timeEstimateLabel.isHidden = true
    }

    private func setupUI() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.clipsToBounds = true  // clips generatedImageView to card's corner radius
        contentView.addSubview(card)
        contentView.addSubview(nameLabel)
        contentView.addSubview(oldPriceLabel)
        contentView.addSubview(priceLabel)
        contentView.addSubview(taglineLabel)
        card.addSubview(generatedImageView)
        card.addSubview(iconImageView)
        card.addSubview(shimmerView)
        card.addSubview(creatingBadge)
        card.addSubview(timeEstimateLabel)

        priceLabelTopToCard     = priceLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: SFSpacing.sm)
        priceLabelTopToOldPrice = priceLabel.topAnchor.constraint(equalTo: oldPriceLabel.bottomAnchor, constant: 2)
        priceLabelTopToCard.isActive = true

        NSLayoutConstraint.activate([
            // Square card
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.heightAnchor.constraint(equalTo: card.widthAnchor),

            // Generated image fills the entire card
            generatedImageView.topAnchor.constraint(equalTo: card.topAnchor),
            generatedImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            generatedImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            generatedImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // Icon centered in card
            iconImageView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 38),
            iconImageView.heightAnchor.constraint(equalToConstant: 38),

            // Shimmer fills entire card
            shimmerView.topAnchor.constraint(equalTo: card.topAnchor),
            shimmerView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            shimmerView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            // Time estimate — bottom-left inside card (replaces creating badge)
            timeEstimateLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.sm),
            timeEstimateLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.sm),
            timeEstimateLabel.heightAnchor.constraint(equalToConstant: 22),

            // Creating badge — bottom-left inside card
            creatingBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.sm),
            creatingBadge.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.sm),
            creatingBadge.heightAnchor.constraint(equalToConstant: 22),

            // Name — top-left below card, stays left of price column
            nameLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: SFSpacing.sm),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: oldPriceLabel.leadingAnchor, constant: -4),

            // Old price — top-right below card
            oldPriceLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: SFSpacing.sm),
            oldPriceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // Live price — right-aligned, top switches between priceLabelTopToCard / priceLabelTopToOldPrice
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // Tagline — below name, first-purchase only
            taglineLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            taglineLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            taglineLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    // MARK: - Configure

    func configure(with bundle: StyleBundle, isFirstPurchase: Bool, isGenerating: Bool, previewImage: UIImage? = nil) {
        nameLabel.text = bundle.name
        creatingBadge.isHidden = true
        let sym = UIImage.SymbolConfiguration(pointSize: 26, weight: .light)
        iconImageView.image = UIImage(systemName: bundle.previewImageName, withConfiguration: sym)

        // ── State 1: Has generated image — show photo, no price ───────────────
        if bundle.previewImageUrl != nil {
            iconImageView.isHidden = true
            generatedImageView.isHidden = false
            generatedImageView.image = previewImage  // set synchronously — no async, no blink
            shimmerView.stopAnimating(); shimmerView.isHidden = true
            timeEstimateLabel.isHidden = true
            card.layer.borderWidth = 0
            oldPriceLabel.isHidden = true
            priceLabel.isHidden = true
            taglineLabel.isHidden = true
            priceLabelTopToOldPrice.isActive = false
            priceLabelTopToCard.isActive = true
            return
        }

        // ── State 2: Checking for results — shimmer, no price ─────────────────
        if bundle.isCheckingPreview {
            iconImageView.isHidden = true
            generatedImageView.isHidden = true
            shimmerView.isHidden = false
            shimmerView.startAnimating()
            timeEstimateLabel.isHidden = true
            oldPriceLabel.isHidden = true
            priceLabel.isHidden = true
            taglineLabel.isHidden = true
            card.layer.borderColor = SFColors.cardBorder.cgColor
            card.layer.borderWidth = 0.5
            return
        }

        // ── State 3: Normal — icon + price ────────────────────────────────────
        iconImageView.isHidden = false
        generatedImageView.isHidden = true
        priceLabel.isHidden = false

        if isGenerating {
            shimmerView.isHidden = false
            shimmerView.startAnimating()
            timeEstimateLabel.isHidden = false
            timeEstimateLabel.text = isFirstPurchase ? "  ~25 min  " : "  ~5 min  "
        } else {
            shimmerView.isHidden = true
            shimmerView.stopAnimating()
            timeEstimateLabel.isHidden = true
        }

        if isFirstPurchase {
            card.layer.borderColor = UIColor(white: 0.28, alpha: 1).cgColor
            card.layer.borderWidth = 1.0
            priceLabelTopToOldPrice.isActive = false
            priceLabelTopToCard.isActive     = true
            oldPriceLabel.isHidden = true
            taglineLabel.isHidden = false
            taglineLabel.text     = bundle.tagline
            priceLabel.text       = bundle.price
            priceLabel.textColor  = SFColors.accent
        } else {
            card.layer.borderColor = SFColors.cardBorder.cgColor
            card.layer.borderWidth = 0.5
            taglineLabel.isHidden = true
            if let old = bundle.oldPrice {
                priceLabelTopToCard.isActive     = false
                priceLabelTopToOldPrice.isActive = true
                oldPriceLabel.isHidden = false
                oldPriceLabel.attributedText = NSAttributedString(
                    string: old,
                    attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                 .foregroundColor: SFColors.strikethroughPrice]
                )
                priceLabel.text      = bundle.price
                priceLabel.textColor = SFColors.accent
            } else {
                priceLabelTopToOldPrice.isActive = false
                priceLabelTopToCard.isActive     = true
                oldPriceLabel.isHidden = true
                priceLabel.text        = bundle.price
                priceLabel.textColor   = SFColors.accent
            }
        }
    }


    override var isHighlighted: Bool {
        didSet { card.animatePress(down: isHighlighted) }
    }
}
