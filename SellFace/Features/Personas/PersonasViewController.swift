import UIKit

final class PersonasViewController: UIViewController {

    private let viewModel: PersonasViewModel

    // Tracks the tapped cell frame for the card-open transition
    private var selectedCellFrame: CGRect = .zero
    private var hasAnimatedEntrance = false

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = SFSpacing.md
        layout.minimumInteritemSpacing = SFSpacing.md
        layout.sectionInset = UIEdgeInsets(
            top: SFSpacing.md,
            left: SFSpacing.md,
            bottom: SFSpacing.md + 88,
            right: SFSpacing.md
        )
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(PersonaCell.self, forCellWithReuseIdentifier: PersonaCell.reuseID)
        cv.delegate = self
        cv.dataSource = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let emptyStateView = PersonasEmptyStateView()

    private let createButton = SFButton(title: "New Persona", style: .primary, systemImage: "plus")

    // Blur backdrop behind the pinned button
    private let buttonBackdrop: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    init(viewModel: PersonasViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        navigationController?.delegate = self
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(didTapHelp)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadPersonas()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAnimatedEntrance && !viewModel.personas.isEmpty {
            hasAnimatedEntrance = true
            collectionView.animateCellsEntrance()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Gradient mask: blur fades from fully transparent at top → fully opaque at bottom
        let gradient = CAGradientLayer()
        gradient.frame = buttonBackdrop.bounds
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        gradient.locations = [0.0, 0.5]
        buttonBackdrop.layer.mask = gradient
    }

    private func setupUI() {
        title = "SellFace"
        view.backgroundColor = SFColors.background

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(buttonBackdrop)
        view.addSubview(createButton)

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.xl),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.xl),

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: createButton.topAnchor, constant: -90),

            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),
            createButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),
        ])

        createButton.addTarget(self, action: #selector(didTapCreate), for: .touchUpInside)
    }

    private func bindViewModel() {
        viewModel.onPersonasUpdated = { [weak self] in
            self?.reload()
        }
    }

    private func reload() {
        let isEmpty = viewModel.personas.isEmpty
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty

        UIView.transition(with: collectionView,
                          duration: 0.25,
                          options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.collectionView.reloadData()
        }

        if !isEmpty && !hasAnimatedEntrance {
            hasAnimatedEntrance = true
            DispatchQueue.main.async { self.collectionView.animateCellsEntrance() }
        }
    }

    @objc private func didTapCreate() {
        viewModel.didTapCreate()
    }

    @objc private func didTapHelp() {
        viewModel.didTapHelp(from: self)
    }
}

// MARK: - Collection View

extension PersonasViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.personas.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PersonaCell.reuseID, for: indexPath) as! PersonaCell
        cell.configure(with: viewModel.personas[indexPath.item])
        return cell
    }
}

extension PersonasViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Capture cell frame in window coordinates for the transition animator
        if let cell = collectionView.cellForItem(at: indexPath) as? PersonaCell {
            selectedCellFrame = cell.card.convert(cell.card.bounds, to: view.window)
        }
        viewModel.didTapPersona(viewModel.personas[indexPath.item])
    }
}

extension PersonasViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset   = SFSpacing.md
        let spacing = SFSpacing.md
        let width   = (collectionView.bounds.width - inset * 2 - spacing) / 2
        // Square card + room for the name label below
        return CGSize(width: width, height: width + SFSpacing.sm + 22)
    }
}

// MARK: - Card Open Navigation Transition

extension PersonasViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push where fromVC === self && toVC is PersonaDetailViewController && selectedCellFrame != .zero:
            return CardPushAnimator(sourceFrame: selectedCellFrame)
        case .pop where toVC === self && fromVC is PersonaDetailViewController && selectedCellFrame != .zero:
            return CardPopAnimator(destinationFrame: selectedCellFrame)
        default:
            return nil
        }
    }
}

// MARK: - Empty State

private final class PersonasEmptyStateView: UIView {

    private let iconView: UIImageView = {
        let iv = UIImageView(
            image: UIImage(systemName: "camera.aperture")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 52, weight: .thin))
        )
        iv.tintColor = SFColors.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Your Stage Awaits"
        l.font = SFTypography.title1()
        l.textAlignment = .center
        l.textColor = SFColors.label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Upload 10–15 photos to train your personal AI model and generate elite headshots."
        l.font = SFTypography.callout()
        l.textAlignment = .center
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = SFSpacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.heightAnchor.constraint(equalToConstant: 64),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
