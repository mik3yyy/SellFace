import UIKit

final class PersonaDetailViewController: UIViewController {

    private let viewModel: PersonaDetailViewModel
    private var selectedCellFrame: CGRect = .zero
    private var isFirstAppearance = true

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = SFSpacing.md
        layout.minimumInteritemSpacing = SFSpacing.md
        layout.sectionInset = UIEdgeInsets(top: SFSpacing.md, left: SFSpacing.md, bottom: SFSpacing.md + 20, right: SFSpacing.md)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(StyleBundleCell.self, forCellWithReuseIdentifier: StyleBundleCell.reuseID)
        cv.register(PersonaDetailHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: PersonaDetailHeaderView.reuseID)
        cv.delegate = self
        cv.dataSource = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    init(viewModel: PersonaDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bindViewModel()
        viewModel.loadBundles()
        navigationItem.backButtonDisplayMode = .minimal
        navigationController?.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.delegate = self
        if isFirstAppearance {
            isFirstAppearance = false
        } else {
            viewModel.loadBundles()
        }
    }


    private func setupUI() {
        title = viewModel.persona.name
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func bindViewModel() {
        viewModel.onBundlesUpdated = { [weak self] in
            guard let self else { return }
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadData()
        }
        viewModel.onError = { [weak self] message in
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

// MARK: - Data source

extension PersonaDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.styleBundles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StyleBundleCell.reuseID, for: indexPath) as! StyleBundleCell
        let bundle = viewModel.styleBundles[indexPath.item]
        cell.configure(
            with: bundle,
            isFirstPurchase: !viewModel.hasGeneratedAnyBundle,
            isGenerating: bundle.id == viewModel.generatingBundleId,
            previewImage: viewModel.previewImage(for: bundle)
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: PersonaDetailHeaderView.reuseID,
            for: indexPath
        ) as! PersonaDetailHeaderView
        header.configure(hasGeneratedAnyBundle: viewModel.hasGeneratedAnyBundle)
        return header
    }
}

// MARK: - Delegate + Layout

extension PersonaDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleBundleCell {
            selectedCellFrame = cell.card.convert(cell.card.bounds, to: view.window)
        }
        viewModel.didTapBundle(viewModel.styleBundles[indexPath.item])
    }
}

extension PersonaDetailViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset   = SFSpacing.md
        let spacing = SFSpacing.md
        let width   = (collectionView.bounds.width - inset * 2 - spacing) / 2
        // Square card + label area below (name row + tagline/price row)
        return CGSize(width: width, height: width + 54)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let height: CGFloat = viewModel.hasGeneratedAnyBundle ? 44 : 162
        return CGSize(width: collectionView.bounds.width, height: height)
    }
}

// MARK: - Header

final class PersonaDetailHeaderView: UICollectionReusableView {
    static let reuseID = "PersonaDetailHeaderView"

    // First-purchase state
    private let firstPurchaseView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nextStepLabel: UILabel = {
        let l = UILabel()
        l.text = "NEXT STEP"
        l.font = SFTypography.captionMedium()
        l.textColor = SFColors.accent
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let selectTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Select your bundles"
        l.font = SFTypography.title1()
        l.textColor = SFColors.label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.text = "Select bundle packs of 25 generated photos. You can also add bundles after the initial bundles have been generated."
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Returning state
    private let availableLabel: UILabel = {
        let l = UILabel()
        l.text = "Available bundles"
        l.font = SFTypography.title3()
        l.textColor = SFColors.secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        // First-purchase view
        firstPurchaseView.addSubview(nextStepLabel)
        firstPurchaseView.addSubview(selectTitleLabel)
        firstPurchaseView.addSubview(descriptionLabel)
        addSubview(firstPurchaseView)
        addSubview(availableLabel)

        NSLayoutConstraint.activate([
            firstPurchaseView.topAnchor.constraint(equalTo: topAnchor, constant: SFSpacing.sm),
            firstPurchaseView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SFSpacing.md),
            firstPurchaseView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SFSpacing.md),
            firstPurchaseView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SFSpacing.sm),

            nextStepLabel.topAnchor.constraint(equalTo: firstPurchaseView.topAnchor),
            nextStepLabel.leadingAnchor.constraint(equalTo: firstPurchaseView.leadingAnchor),

            selectTitleLabel.topAnchor.constraint(equalTo: nextStepLabel.bottomAnchor, constant: 4),
            selectTitleLabel.leadingAnchor.constraint(equalTo: firstPurchaseView.leadingAnchor),
            selectTitleLabel.trailingAnchor.constraint(equalTo: firstPurchaseView.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: selectTitleLabel.bottomAnchor, constant: SFSpacing.sm),
            descriptionLabel.leadingAnchor.constraint(equalTo: firstPurchaseView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: firstPurchaseView.trailingAnchor),

            // Returning label — vertically centered in header
            availableLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            availableLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SFSpacing.md),
        ])
    }

    func configure(hasGeneratedAnyBundle: Bool) {
        firstPurchaseView.isHidden = hasGeneratedAnyBundle
        availableLabel.isHidden    = !hasGeneratedAnyBundle
    }
}

// MARK: - Card Open Transition (bundle → results)

extension PersonaDetailViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push where fromVC === self && toVC is ResultsViewController && selectedCellFrame != .zero:
            return CardPushAnimator(sourceFrame: selectedCellFrame)
        case .pop where fromVC is ResultsViewController && toVC === self && selectedCellFrame != .zero:
            return CardPopAnimator(destinationFrame: selectedCellFrame)
        default:
            return nil
        }
    }
}
