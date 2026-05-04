import UIKit

// MARK: - Card Opening Transition (push)

final class CardPushAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    /// Frame of the source card in window coordinates
    let sourceFrame: CGRect

    init(sourceFrame: CGRect) {
        self.sourceFrame = sourceFrame
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval { 0.48 }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let toVC  = context.viewController(forKey: .to),
              let toView = context.view(forKey: .to),
              let fromView = context.view(forKey: .from) else {
            context.completeTransition(false)
            return
        }

        let container  = context.containerView
        let finalFrame = context.finalFrame(for: toVC)

        // Place destination at its final frame but start it visually looking like the card
        toView.frame = finalFrame
        toView.clipsToBounds = true
        toView.layer.cornerRadius = SFSpacing.cardRadius
        toView.layer.cornerCurve = .continuous

        // Calculate the scale transform so toView appears at sourceFrame size/position
        let scaleX = sourceFrame.width  / finalFrame.width
        let scaleY = sourceFrame.height / finalFrame.height
        let tx = sourceFrame.midX - finalFrame.midX
        let ty = sourceFrame.midY - finalFrame.midY

        toView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY).translatedBy(x: tx / scaleX, y: ty / scaleY)
        toView.alpha = 0.6

        container.addSubview(toView)

        // Animate source view out slightly
        UIView.animate(withDuration: 0.20, delay: 0, options: .curveEaseOut) {
            fromView.alpha = 0.85
            fromView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }

        // Animate the card expanding into the full screen
        UIView.animate(
            withDuration: transitionDuration(using: context),
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.15,
            options: .curveEaseOut
        ) {
            toView.transform = .identity
            toView.alpha = 1
            toView.layer.cornerRadius = 0
        } completion: { finished in
            fromView.alpha = 1
            fromView.transform = .identity
            toView.clipsToBounds = false
            context.completeTransition(finished && !context.transitionWasCancelled)
        }
    }
}

// MARK: - Card Closing Transition (pop)

final class CardPopAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    let destinationFrame: CGRect

    init(destinationFrame: CGRect) {
        self.destinationFrame = destinationFrame
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval { 0.38 }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let fromView = context.view(forKey: .from),
              let toVC    = context.viewController(forKey: .to),
              let toView  = context.view(forKey: .to) else {
            context.completeTransition(false)
            return
        }

        let container  = context.containerView
        let finalFrame = context.finalFrame(for: toVC)

        toView.frame = finalFrame
        toView.alpha = 0.85
        toView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        container.insertSubview(toView, belowSubview: fromView)

        let scaleX = destinationFrame.width  / fromView.bounds.width
        let scaleY = destinationFrame.height / fromView.bounds.height
        let tx = destinationFrame.midX - fromView.bounds.midX
        let ty = destinationFrame.midY - fromView.bounds.midY

        fromView.clipsToBounds = true
        fromView.layer.cornerRadius = 0
        fromView.layer.cornerCurve = .continuous

        UIView.animate(
            withDuration: transitionDuration(using: context),
            delay: 0,
            usingSpringWithDamping: 0.90,
            initialSpringVelocity: 0.1,
            options: .curveEaseIn
        ) {
            fromView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY).translatedBy(x: tx / scaleX, y: ty / scaleY)
            fromView.alpha = 0
            fromView.layer.cornerRadius = SFSpacing.cardRadius
            toView.alpha = 1
            toView.transform = .identity
        } completion: { finished in
            fromView.clipsToBounds = false
            context.completeTransition(finished && !context.transitionWasCancelled)
        }
    }
}

// MARK: - Cell stagger helper

extension UICollectionView {
    /// Animate cells appearing one after another on first load
    func animateCellsEntrance() {
        let cells = visibleCells.sorted { $0.frame.minY < $1.frame.minY }
        cells.forEach { cell in
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 28)
        }
        for (i, cell) in cells.enumerated() {
            UIView.animate(
                withDuration: 0.52,
                delay: Double(i) * 0.07,
                usingSpringWithDamping: 0.80,
                initialSpringVelocity: 0.1,
                options: [.allowUserInteraction]
            ) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }
}

// MARK: - Navigation bar styling

extension UINavigationController {
    static func styledForSellFace() -> UINavigationController {
        let nc = UINavigationController()
        nc.applyDarkGoldStyle()
        return nc
    }

    func applyDarkGoldStyle() {
        // Scrolled-down: ultra-thin material blur (content shows through)
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithTransparentBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        scrolled.shadowColor = .clear
        scrolled.titleTextAttributes = [
            .foregroundColor: SFColors.label,
            .font: SFTypography.headline()
        ]
        scrolled.largeTitleTextAttributes = [
            .foregroundColor: SFColors.label,
            .font: SFTypography.largeTitle()
        ]

        // At rest (scroll edge): fully transparent so background shows
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.shadowColor = .clear
        edge.titleTextAttributes = scrolled.titleTextAttributes
        edge.largeTitleTextAttributes = scrolled.largeTitleTextAttributes

        navigationBar.standardAppearance   = scrolled
        navigationBar.scrollEdgeAppearance = edge
        navigationBar.compactAppearance    = scrolled
        navigationBar.tintColor            = SFColors.accent
        navigationBar.prefersLargeTitles   = true
    }
}
