import UIKit

final class PersonaDetailViewController: UIViewController {

    private let viewModel: PersonaDetailViewModel

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = SFSpacing.md
        layout.minimumInteritemSpacing = SFSpacing.md
        layout.sectionInset = UIEdgeInsets(top: SFSpacing.md, left: SFSpacing.md, bottom: SFSpacing.md, right: SFSpacing.md)
        layout.headerReferenceSize = CGSize(width: 0, height: 140)
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

    private let processingView = ProcessingOverlayView()

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
        // No text on back button when pushing further
        navigationItem.backButtonDisplayMode = .minimal
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadBundles()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Fade title in after the card-open transition settles
        navigationController?.navigationBar.alpha = 0
        UIView.animate(withDuration: 0.30, delay: 0.10) {
            self.navigationController?.navigationBar.alpha = 1
        }
    }

    private func setupUI() {
        title = viewModel.persona.name
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(collectionView)
        view.addSubview(processingView)

        processingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            processingView.topAnchor.constraint(equalTo: view.topAnchor),
            processingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            processingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            processingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        processingView.isHidden = !viewModel.isProcessing
    }

    private func bindViewModel() {
        viewModel.onBundlesUpdated = { [weak self] in
            self?.collectionView.reloadData()
            self?.processingView.isHidden = !(self?.viewModel.isProcessing ?? false)
        }
        viewModel.onError = { [weak self] message in
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

extension PersonaDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.styleBundles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StyleBundleCell.reuseID, for: indexPath) as! StyleBundleCell
        cell.configure(with: viewModel.styleBundles[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: PersonaDetailHeaderView.reuseID,
            for: indexPath
        ) as! PersonaDetailHeaderView
        header.configure(persona: viewModel.persona)
        return header
    }
}

extension PersonaDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.didTapBundle(viewModel.styleBundles[indexPath.item])
    }
}

extension PersonaDetailViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset = SFSpacing.md
        let spacing = SFSpacing.md
        let width = (collectionView.bounds.width - inset * 2 - spacing) / 2
        return CGSize(width: width, height: width * 1.5)
    }
}

// MARK: - Header

final class PersonaDetailHeaderView: UICollectionReusableView {
    static let reuseID = "PersonaDetailHeaderView"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.title3()
        l.textColor = SFColors.secondaryLabel
        l.text = "Available bundles"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let statusCard = SFCardView()
    private let statusLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.subheadline()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusLabel)
        addSubview(statusCard)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            statusCard.topAnchor.constraint(equalTo: topAnchor, constant: SFSpacing.sm),
            statusCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SFSpacing.md),
            statusCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SFSpacing.md),

            statusLabel.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: SFSpacing.sm),
            statusLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: SFSpacing.md),
            statusLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -SFSpacing.md),
            statusLabel.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -SFSpacing.sm),

            titleLabel.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: SFSpacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SFSpacing.md),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SFSpacing.sm),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(persona: Persona) {
        switch persona.status {
        case .ready, .draft:
            statusLabel.text = "Photos ready. Tap a style to generate your AI headshots."
        case .processing, .uploading:
            statusLabel.text = "Training your AI model — this takes about 20 minutes. You'll get a notification when done."
        case .failed:
            statusLabel.text = "Processing failed. Please try creating a new persona."
        }
    }
}

// MARK: - Processing Overlay

final class ProcessingOverlayView: UIView {

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))

    private let spinner: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .large)
        a.color = SFColors.accent
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.text = "Your images are being prepared.\nWe'll notify you when they're ready."
        l.font = SFTypography.body()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        blurView.contentView.addSubview(spinner)
        blurView.contentView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor, constant: -SFSpacing.lg),

            messageLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: SFSpacing.lg),
            messageLabel.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: SFSpacing.xl),
            messageLabel.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -SFSpacing.xl),
        ])
        spinner.startAnimating()
    }

    required init?(coder: NSCoder) { fatalError() }
}
