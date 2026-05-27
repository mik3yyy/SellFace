import UIKit

final class PersonaSuccessViewController: UIViewController {

    private let persona: Persona
    private let viewModel: CreatePersonaViewModel

    // MARK: - UI

    private let leftPanel = UIView()
    private let rightPanel = UIView()
    private let divider = UIView()
    private let continueButton = SFButton(title: "Continue →", style: .primary)

    // MARK: - Init

    init(persona: Persona, viewModel: CreatePersonaViewModel) {
        self.persona = persona
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true

        leftPanel.backgroundColor = UIColor(hex: "#0D0D0D")
        leftPanel.translatesAutoresizingMaskIntoConstraints = false

        rightPanel.backgroundColor = UIColor(hex: "#0F0F1E")
        rightPanel.translatesAutoresizingMaskIntoConstraints = false

        divider.backgroundColor = SFColors.separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(leftPanel)
        view.addSubview(rightPanel)
        view.addSubview(divider)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            leftPanel.topAnchor.constraint(equalTo: view.topAnchor),
            leftPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            leftPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            leftPanel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),

            rightPanel.topAnchor.constraint(equalTo: view.topAnchor),
            rightPanel.leadingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            rightPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rightPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            divider.topAnchor.constraint(equalTo: view.topAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            divider.widthAnchor.constraint(equalToConstant: 0.5),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            continueButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),
        ])

        buildLeftContent()
        buildRightContent()

        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
    }

    // MARK: - Left panel (Photographer)

    private func buildLeftContent() {
        let iconContainer = makeIconContainer(color: SFColors.secondaryBackground)
        let iconView = UIImageView(image: UIImage(systemName: "camera.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),
        ])

        let nameLabel = makeNameLabel("Photographer", color: SFColors.label)
        let timeCaptionLabel = makeCaptionLabel("TIME")
        let timeValueLabel = makeValueLabel("3 hours+")
        let costCaptionLabel = makeCaptionLabel("COST")
        let costValueLabel = makeValueLabel("£230")

        let stack = UIStackView(arrangedSubviews: [
            iconContainer, nameLabel, timeCaptionLabel, timeValueLabel, costCaptionLabel, costValueLabel
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = SFSpacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(SFSpacing.md, after: iconContainer)
        stack.setCustomSpacing(SFSpacing.md, after: nameLabel)
        stack.setCustomSpacing(SFSpacing.md, after: timeValueLabel)

        leftPanel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: leftPanel.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: leftPanel.centerYAnchor, constant: -SFSpacing.xl),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leftPanel.leadingAnchor, constant: SFSpacing.sm),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: leftPanel.trailingAnchor, constant: -SFSpacing.sm),
        ])
    }

    // MARK: - Right panel (SellFace)

    private func buildRightContent() {
        let iconContainer = makeIconContainer(color: SFColors.secondaryBackground)
        let appIcon = UIImage(named: "SellFaceIcon") ?? UIImage(systemName: "sparkles")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 36, weight: .medium))
        let iconView = UIImageView(image: appIcon)
        iconView.tintColor = SFColors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 12
        iconView.layer.cornerCurve = .continuous
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),
        ])

        let nameLabel = makeNameLabel("SellFace", color: SFColors.accent)
        let timeCaptionLabel = makeCaptionLabel("TIME")
        let timeValueLabel = makeValueLabel("~1 min")
        let costCaptionLabel = makeCaptionLabel("COST")
        let costValueLabel = makeValueLabel("£9.99", color: SFColors.accent)
        let badgeLabel = makeBadgeLabel("20X CHEAPER")

        let stack = UIStackView(arrangedSubviews: [
            iconContainer, nameLabel, timeCaptionLabel, timeValueLabel, costCaptionLabel, costValueLabel, badgeLabel
        ])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = SFSpacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(SFSpacing.md, after: iconContainer)
        stack.setCustomSpacing(SFSpacing.md, after: nameLabel)
        stack.setCustomSpacing(SFSpacing.md, after: timeValueLabel)
        stack.setCustomSpacing(SFSpacing.sm, after: costValueLabel)

        rightPanel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: rightPanel.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: rightPanel.centerYAnchor, constant: -SFSpacing.xl),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: rightPanel.leadingAnchor, constant: SFSpacing.sm),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: rightPanel.trailingAnchor, constant: -SFSpacing.sm),
        ])
    }

    // MARK: - Factory helpers

    private func makeIconContainer(color: UIColor) -> UIView {
        let v = UIView()
        v.backgroundColor = color
        v.layer.cornerRadius = SFSpacing.cardRadius
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 80),
            v.heightAnchor.constraint(equalToConstant: 80),
        ])
        return v
    }

    private func makeNameLabel(_ text: String, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = SFTypography.title3()
        l.textColor = color
        l.textAlignment = .center
        return l
    }

    private func makeCaptionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = SFTypography.captionMedium()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.setTracking(1.5)
        return l
    }

    private func makeValueLabel(_ text: String, color: UIColor = SFColors.label) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = SFTypography.title2()
        l.textColor = color
        l.textAlignment = .center
        return l
    }

    private func makeBadgeLabel(_ text: String) -> PaddedLabel {
        let l = PaddedLabel(insets: UIEdgeInsets(top: SFSpacing.xs, left: SFSpacing.sm, bottom: SFSpacing.xs, right: SFSpacing.sm))
        l.text = text
        l.font = SFTypography.captionMedium()
        l.textColor = UIColor(hex: "#1A1208")
        l.textAlignment = .center
        l.backgroundColor = SFColors.accent
        l.layer.cornerRadius = SFSpacing.badgeRadius
        l.layer.cornerCurve = .continuous
        l.clipsToBounds = true
        return l
    }

    // MARK: - Actions

    @objc private func didTapContinue() {
        viewModel.coordinator?.showPersonaDetailAfterCreation(persona)
    }
}

// MARK: - PaddedLabel

private final class PaddedLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + insets.left + insets.right,
            height: base.height + insets.top + insets.bottom
        )
    }
}
