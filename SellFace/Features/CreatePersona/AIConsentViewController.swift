import UIKit

/// Shown once before the user's first photo upload. Discloses that photos are
/// processed by Astria AI and obtains explicit consent, satisfying App Store
/// Guideline 2.1 (third-party AI data sharing disclosure).
final class AIConsentViewController: UIViewController {

    var onConsent: (() -> Void)?
    var onDecline: (() -> Void)?

    // MARK: - UI

    private let handleBar: UIView = {
        let v = UIView()
        v.backgroundColor = SFColors.tertiaryBackground
        v.layer.cornerRadius = 2.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 36, weight: .light)
        iv.image = UIImage(systemName: "cpu.fill", withConfiguration: cfg)
        iv.tintColor = SFColors.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "How Your Photos Are Used"
        l.font = SFTypography.title2()
        l.textColor = SFColors.label
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Before we start, here's exactly what happens to the photos you selected."
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bulletStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let agreeButton = SFButton(title: "I Agree & Continue", style: .primary, systemImage: "checkmark")

    private let privacyButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Read our Privacy Policy", for: .normal)
        b.titleLabel?.font = SFTypography.footnote()
        b.tintColor = SFColors.accent
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let declineButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cancel", for: .normal)
        b.titleLabel?.font = SFTypography.subheadline()
        b.tintColor = SFColors.secondaryLabel
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = SFColors.background
        view.layer.cornerRadius = 24
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        let bullets: [(icon: String, text: String)] = [
            ("arrow.up.to.line.circle.fill",
             "Your photos are securely uploaded to our servers and sent to Astria AI for processing."),
            ("person.crop.circle.fill",
             "Astria AI creates a personalized model trained only on your photos — for your portraits."),
            ("lock.shield.fill",
             "Your photos are not used to train public AI models or shared with anyone else."),
            ("trash.circle.fill",
             "Your training photos are deleted from our servers the moment they are sent to Astria. Only your generated images are kept — and you can delete those any time from the Help screen."),
        ]

        for item in bullets {
            bulletStack.addArrangedSubview(makeBulletRow(icon: item.icon, text: item.text))
        }

        view.addSubview(handleBar)
        view.addSubview(iconView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(bulletStack)
        view.addSubview(agreeButton)
        view.addSubview(privacyButton)
        view.addSubview(declineButton)

        agreeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            iconView.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: SFSpacing.lg),
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 52),
            iconView.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: SFSpacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.lg),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: SFSpacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.lg),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.lg),

            bulletStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: SFSpacing.lg),
            bulletStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            bulletStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),

            agreeButton.topAnchor.constraint(equalTo: bulletStack.bottomAnchor, constant: SFSpacing.xl),
            agreeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            agreeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            agreeButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),

            privacyButton.topAnchor.constraint(equalTo: agreeButton.bottomAnchor, constant: SFSpacing.sm),
            privacyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            declineButton.topAnchor.constraint(equalTo: privacyButton.bottomAnchor, constant: SFSpacing.xs),
            declineButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            declineButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),
        ])

        agreeButton.addTarget(self, action: #selector(didTapAgree), for: .touchUpInside)
        privacyButton.addTarget(self, action: #selector(didTapPrivacy), for: .touchUpInside)
        declineButton.addTarget(self, action: #selector(didTapDecline), for: .touchUpInside)
    }

    private func makeBulletRow(icon: String, text: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg))
        iv.tintColor = SFColors.accent
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.translatesAutoresizingMaskIntoConstraints = false

        let l = UILabel()
        l.text = text
        l.font = SFTypography.footnote()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(iv)
        row.addSubview(l)

        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: SFSpacing.sm),
            iv.topAnchor.constraint(equalTo: row.topAnchor, constant: 2),
            iv.widthAnchor.constraint(equalToConstant: 24),
            iv.heightAnchor.constraint(equalToConstant: 24),

            l.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: SFSpacing.sm),
            l.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -SFSpacing.sm),
            l.topAnchor.constraint(equalTo: row.topAnchor),
            l.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])

        return row
    }

    // MARK: - Actions

    @objc private func didTapAgree() {
        LocalStorageManager.shared.markAIConsentGiven()
        dismiss(animated: true) { [weak self] in self?.onConsent?() }
    }

    @objc private func didTapPrivacy() {
        guard let url = URL(string: "https://github.com/mik3yyy/SellFace/blob/main/PRIVACY.md") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func didTapDecline() {
        dismiss(animated: true) { [weak self] in self?.onDecline?() }
    }
}
