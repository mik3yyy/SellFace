import UIKit

class SFImageCard: UIView {

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        layer.cornerRadius = SFSpacing.cardRadius

        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.5).cgColor]
        gradientLayer.locations = [0.5, 1.0]
        layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
    }

    func setPlaceholder(systemName: String) {
        imageView.image = UIImage(systemName: systemName)
        imageView.tintColor = SFColors.secondaryLabel
        imageView.contentMode = .center
    }
}
