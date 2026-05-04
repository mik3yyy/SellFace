import UIKit

enum SFButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive
}

final class SFButton: UIButton {

    private var buttonStyle: SFButtonStyle = .primary
    private let impact = UIImpactFeedbackGenerator(style: .light)

    convenience init(title: String, style: SFButtonStyle = .primary, systemImage: String? = nil) {
        self.init(type: .system)
        self.buttonStyle = style
        translatesAutoresizingMaskIntoConstraints = false

        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.baseForegroundColor = Self.foregroundColor(for: style)
        cfg.baseBackgroundColor = Self.backgroundColor(for: style)
        cfg.cornerStyle = .fixed
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: SFSpacing.lg, bottom: 0, trailing: SFSpacing.lg)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = SFTypography.headline()
            a.kern = 0.3
            return a
        }
        if let systemImage {
            cfg.image = UIImage(systemName: systemImage)
            cfg.imagePadding = SFSpacing.sm
            cfg.imagePlacement = .leading
        }
        configuration = cfg
        layer.cornerRadius = SFSpacing.buttonRadius
        layer.cornerCurve = .continuous

        if style == .primary { applyGoldGlow() }

        addTarget(self, action: #selector(pressDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(pressUp),   for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
    }

    override init(frame: CGRect) { super.init(frame: frame) }
    required init?(coder: NSCoder) { super.init(coder: coder) }

    private func applyGoldGlow() {
        layer.shadowColor   = SFColors.accent.withAlphaComponent(0.40).cgColor
        layer.shadowOffset  = CGSize(width: 0, height: 6)
        layer.shadowRadius  = 14
        layer.shadowOpacity = 1
    }

    @objc private func pressDown() {
        impact.prepare()
        UIView.animate(withDuration: 0.10, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.alpha = 0.88
        }
    }

    @objc private func pressUp() {
        impact.impactOccurred()
        UIView.animate(
            withDuration: 0.44, delay: 0,
            usingSpringWithDamping: 0.58, initialSpringVelocity: 0.9,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = .identity
            self.alpha = 1
        }
    }

    func setLoading(_ loading: Bool) {
        isEnabled = !loading
        configuration?.showsActivityIndicator = loading
    }

    private static func foregroundColor(for style: SFButtonStyle) -> UIColor {
        switch style {
        case .primary:     return UIColor(hex: "#1A1208")  // dark text on gold
        case .secondary:   return SFColors.accent
        case .ghost:       return SFColors.label
        case .destructive: return .white
        }
    }

    private static func backgroundColor(for style: SFButtonStyle) -> UIColor {
        switch style {
        case .primary:     return SFColors.accent
        case .secondary:   return SFColors.accentLight
        case .ghost:       return .clear
        case .destructive: return SFColors.destructive
        }
    }
}
