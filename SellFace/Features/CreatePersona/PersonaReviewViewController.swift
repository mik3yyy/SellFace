import UIKit

final class PersonaReviewViewController: UIViewController {

    private let viewModel: CreatePersonaViewModel
    private let name: String
    private let gender: String

    // MARK: - UI

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 4
        let columns: CGFloat = 3
        let totalSpacing = spacing * (columns - 1)
        let itemWidth = (UIScreen.main.bounds.width - totalSpacing) / columns
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = .zero
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.register(ReviewPhotoCell.self, forCellWithReuseIdentifier: ReviewPhotoCell.reuseID)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.dataSource = self
        return cv
    }()

    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.progressTintColor = SFColors.accent
        pv.trackTintColor = SFColors.secondaryBackground
        pv.isHidden = true
        pv.translatesAutoresizingMaskIntoConstraints = false
        return pv
    }()

    private let progressLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.subheadline()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let startButton = SFButton(title: "Start Creating", style: .primary, systemImage: "sparkles")

    private let buttonBackdrop: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Init

    init(viewModel: CreatePersonaViewModel, name: String, gender: String) {
        self.viewModel = viewModel
        self.name = name
        self.gender = gender
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
        title = "Overview"
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never

        subtitleLabel.text = "Are you happy with your photos for \(name)?"
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(subtitleLabel)
        view.addSubview(collectionView)
        view.addSubview(progressView)
        view.addSubview(progressLabel)
        view.addSubview(buttonBackdrop)
        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.md),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),

            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: SFSpacing.md),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -SFSpacing.md),

            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            progressView.bottomAnchor.constraint(equalTo: progressLabel.topAnchor, constant: -SFSpacing.sm),
            progressView.heightAnchor.constraint(equalToConstant: 4),

            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            progressLabel.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -SFSpacing.sm),

            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            startButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: startButton.topAnchor, constant: -SFSpacing.xl),
        ])

        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func didTapStart() {
        startButton.setLoading(true)
        navigationItem.hidesBackButton = true
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

        progressView.isHidden = false
        progressLabel.isHidden = false
        progressLabel.text = "Uploading 0 of \(viewModel.selectedImages.count)…"

        viewModel.onProgress = { [weak self] uploaded, total in
            guard let self else { return }
            let fraction = Float(uploaded) / Float(max(total, 1))
            self.progressView.setProgress(fraction, animated: true)
            self.progressLabel.text = "Uploading \(uploaded) of \(total)…"
        }

        viewModel.onCreationComplete = { [weak self] persona in
            guard let self else { return }
            let successVC = PersonaSuccessViewController(persona: persona, viewModel: self.viewModel)
            self.navigationController?.pushViewController(successVC, animated: true)
        }

        viewModel.onError = { [weak self] message in
            guard let self else { return }
            self.startButton.setLoading(false)
            self.navigationItem.hidesBackButton = false
            self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            self.progressView.isHidden = true
            self.progressLabel.isHidden = true

            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }

        viewModel.createPersona(name: name, gender: gender)
    }
}

// MARK: - Collection view data source

extension PersonaReviewViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.selectedImages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReviewPhotoCell.reuseID, for: indexPath) as! ReviewPhotoCell
        cell.configure(image: viewModel.selectedImages[indexPath.item])
        return cell
    }
}

// MARK: - Review photo cell

private final class ReviewPhotoCell: UICollectionViewCell {
    static let reuseID = "ReviewPhotoCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = SFSpacing.chipRadius
        iv.layer.cornerCurve = .continuous
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
    func configure(image: UIImage) { imageView.image = image }
}
