import UIKit

final class PersonaValuePropViewController: UIViewController {

    private let viewModel: CreatePersonaViewModel

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = SFSpacing.lg
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "21× More\nLinkedIn Views"
        l.font = SFTypography.title1()
        l.textColor = SFColors.label
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private lazy var linkedInCard: UIView = buildLinkedInCard()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Profiles with a photo get 21× more views\n& 9× more connection requests"
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let continueButton = SFButton(title: "Continue →", style: .primary)

    private let buttonBackdrop: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    init(viewModel: CreatePersonaViewModel) {
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

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(buttonBackdrop)
        view.addSubview(continueButton)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(linkedInCard)
        contentStack.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: SFSpacing.xl),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: SFSpacing.md),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -SFSpacing.md),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -(SFSpacing.buttonHeight + SFSpacing.xxl)),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -SFSpacing.md * 2),

            linkedInCard.widthAnchor.constraint(equalTo: contentStack.widthAnchor),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            continueButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: continueButton.topAnchor, constant: -SFSpacing.xl),
        ])

        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
    }

    // MARK: - LinkedIn card builder

    private func buildLinkedInCard() -> UIView {
        let card = SFCardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        // LinkedIn "in" badge
        let inLabel = UILabel()
        inLabel.text = "in"
        inLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        inLabel.textColor = .white
        inLabel.textAlignment = .center
        inLabel.translatesAutoresizingMaskIntoConstraints = false

        let inBackground = UIView()
        inBackground.backgroundColor = UIColor(hex: "#0A66C2")
        inBackground.layer.cornerRadius = 4
        inBackground.layer.cornerCurve = .continuous
        inBackground.clipsToBounds = true
        inBackground.translatesAutoresizingMaskIntoConstraints = false
        inBackground.addSubview(inLabel)

        // Profile photo
        let avatarImage = UIImage(systemName: "person.crop.circle.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 48, weight: .light))
        let avatarView = UIImageView(image: avatarImage)
        avatarView.tintColor = SFColors.tertiaryLabel
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 24
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        // Name
        let nameLabel = UILabel()
        nameLabel.text = "Emily Johnson"
        nameLabel.font = SFTypography.title3()
        nameLabel.textColor = SFColors.label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.text = "Marketing Coordinator · Acme Inc."
        headlineLabel.font = SFTypography.subheadline()
        headlineLabel.textColor = SFColors.secondaryLabel
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false

        // Education
        let educationLabel = UILabel()
        educationLabel.text = "University of California, Berkeley"
        educationLabel.font = SFTypography.subheadline()
        educationLabel.textColor = SFColors.secondaryLabel
        educationLabel.translatesAutoresizingMaskIntoConstraints = false

        // Location/connections
        let locationLabel = UILabel()
        locationLabel.text = "San Francisco Bay Area · 500+ connections"
        locationLabel.font = SFTypography.caption()
        locationLabel.textColor = SFColors.tertiaryLabel
        locationLabel.translatesAutoresizingMaskIntoConstraints = false

        // Action buttons row
        let openToButton = makeLinkedInPillButton(title: "Open to")
        let messageButton = makeLinkedInPillButton(title: "Message")
        let buttonStack = UIStackView(arrangedSubviews: [openToButton, messageButton, UIView()])
        buttonStack.axis = .horizontal
        buttonStack.spacing = SFSpacing.sm
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Info stack (name, headline, etc.)
        let infoStack = UIStackView(arrangedSubviews: [nameLabel, headlineLabel, educationLabel, locationLabel, buttonStack])
        infoStack.axis = .vertical
        infoStack.spacing = SFSpacing.xs
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.setCustomSpacing(SFSpacing.sm, after: locationLabel)

        card.addSubview(inBackground)
        card.addSubview(inLabel)
        card.addSubview(avatarView)
        card.addSubview(infoStack)

        NSLayoutConstraint.activate([
            inBackground.topAnchor.constraint(equalTo: card.topAnchor, constant: SFSpacing.md),
            inBackground.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            inBackground.widthAnchor.constraint(equalToConstant: 28),
            inBackground.heightAnchor.constraint(equalToConstant: 28),

            inLabel.centerXAnchor.constraint(equalTo: inBackground.centerXAnchor),
            inLabel.centerYAnchor.constraint(equalTo: inBackground.centerYAnchor),

            avatarView.topAnchor.constraint(equalTo: inBackground.bottomAnchor, constant: SFSpacing.md),
            avatarView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),

            infoStack.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: SFSpacing.sm),
            infoStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            infoStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.md),
            infoStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.md),
        ])

        return card
    }

    private func makeLinkedInPillButton(title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = SFColors.secondaryBackground
        container.layer.cornerRadius = 14
        container.layer.cornerCurve = .continuous
        container.layer.borderColor = SFColors.separator.cgColor
        container.layer.borderWidth = 0.5
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = SFTypography.captionMedium()
        label.textColor = SFColors.secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: SFSpacing.xs),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -SFSpacing.xs),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SFSpacing.sm),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SFSpacing.sm),
        ])

        return container
    }

    // MARK: - Actions

    @objc private func didTapContinue() {
        let vc = PersonaNameGenderViewController(viewModel: viewModel)
        navigationController?.pushViewController(vc, animated: true)
    }
}
