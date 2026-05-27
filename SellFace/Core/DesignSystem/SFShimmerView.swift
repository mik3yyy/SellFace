import UIKit

final class SFShimmerView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [
            UIColor(white: 1, alpha: 0.04).cgColor,
            UIColor(white: 1, alpha: 0.14).cgColor,
            UIColor(white: 1, alpha: 0.04).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint   = CGPoint(x: 1, y: 0.5)
        gradient.locations  = [-1, -0.5, 0]
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimating() }
    }

    func startAnimating() {
        guard gradient.animation(forKey: "shimmer") == nil else { return }
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue   = [-1, -0.5, 0]
        anim.toValue     = [1, 1.5, 2]
        anim.duration    = 1.4
        anim.repeatCount = .infinity
        gradient.add(anim, forKey: "shimmer")
    }

    func stopAnimating() {
        gradient.removeAnimation(forKey: "shimmer")
    }
}
