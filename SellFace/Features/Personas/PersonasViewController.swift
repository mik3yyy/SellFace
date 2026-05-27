import UIKit

final class PersonasViewController: UIViewController {

    private let viewModel: PersonasViewModel

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
        cv.register(PersonaShimmerCell.self, forCellWithReuseIdentifier: PersonaShimmerCell.reuseID)
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
        let showEmpty = viewModel.personas.isEmpty && !viewModel.isLoading
        emptyStateView.isHidden = !showEmpty
        collectionView.isHidden = showEmpty

        collectionView.reloadData()

        if !viewModel.personas.isEmpty && !hasAnimatedEntrance {
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
        viewModel.isLoading && viewModel.personas.isEmpty ? 4 : viewModel.personas.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if viewModel.isLoading && viewModel.personas.isEmpty {
            return collectionView.dequeueReusableCell(withReuseIdentifier: PersonaShimmerCell.reuseID, for: indexPath)
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PersonaCell.reuseID, for: indexPath) as! PersonaCell
        cell.configure(with: viewModel.personas[indexPath.item])
        return cell
    }
}

extension PersonasViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !viewModel.isLoading || !viewModel.personas.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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

// MARK: - Shimmer Skeleton Cell

final class PersonaShimmerCell: UICollectionViewCell {
    static let reuseID = "PersonaShimmerCell"

    private let cardShimmer: SFShimmerView = {
        let v = SFShimmerView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.06)
        v.layer.cornerRadius = SFSpacing.cardRadius
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nameLine: SFShimmerView = {
        let v = SFShimmerView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.06)
        v.layer.cornerRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(cardShimmer)
        contentView.addSubview(nameLine)
        NSLayoutConstraint.activate([
            cardShimmer.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardShimmer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardShimmer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardShimmer.heightAnchor.constraint(equalTo: cardShimmer.widthAnchor),

            nameLine.topAnchor.constraint(equalTo: cardShimmer.bottomAnchor, constant: SFSpacing.sm),
            nameLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            nameLine.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.55),
            nameLine.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
