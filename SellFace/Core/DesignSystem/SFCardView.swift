import UIKit

class SFCardView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = SFColors.cardBackground
        layer.cornerRadius = SFSpacing.cardRadius
        layer.cornerCurve = .continuous   // Apple's smooth "squircle" curve

        // Subtle gold border
        layer.borderColor = SFColors.cardBorder.cgColor
        layer.borderWidth = 0.5

        // Deep shadow for depth
        layer.shadowColor = SFColors.cardShadow.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 24
        layer.shadowOpacity = 1
        layer.masksToBounds = false
    }

    // MARK: - Press Animation
    func animatePress(down: Bool) {
        let scale: CGFloat = down ? 0.965 : 1.0
        UIView.animate(
            withDuration: down ? 0.12 : 0.45,
            delay: 0,
            usingSpringWithDamping: down ? 1.0 : 0.62,
            initialSpringVelocity: down ? 0 : 0.8,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
