import UIKit

final class ResultsViewController: UIViewController {

    private let viewModel: ResultsViewModel

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = SFSpacing.sm
        layout.minimumInteritemSpacing = SFSpacing.sm
        layout.sectionInset = UIEdgeInsets(top: SFSpacing.sm, left: SFSpacing.md, bottom: SFSpacing.md, right: SFSpacing.md)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(ResultImageCell.self, forCellWithReuseIdentifier: ResultImageCell.reuseID)
        cv.delegate = self
        cv.dataSource = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let loadingView = ResultsLoadingView()

    init(viewModel: ResultsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        viewModel.onStateChanged = { [weak self] in self?.updateState() }
        viewModel.onImagesLoaded = { [weak self] in self?.collectionView.reloadData() }
        viewModel.loadImages()
    }

    private func updateState() {
        let loading = viewModel.isLoading
        loadingView.isHidden = !loading
        collectionView.isHidden = loading
        loadingView.setMessage(viewModel.statusMessage, phase: viewModel.phase)

        if !loading && viewModel.images.isEmpty {
            loadingView.isHidden = false
            loadingView.setFinished()
        }

        collectionView.reloadData()
    }

    private func setupUI() {
        title = viewModel.bundle.name
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(didTapShare)
        )

        view.addSubview(collectionView)
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            loadingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        loadingView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.isHidden = false
        collectionView.isHidden = true
    }

    @objc private func didTapShare() {
        guard !viewModel.images.isEmpty else { return }
        let ac = UIActivityViewController(activityItems: viewModel.images, applicationActivities: nil)
        present(ac, animated: true)
    }
}

extension ResultsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.images.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ResultImageCell.reuseID, for: indexPath) as! ResultImageCell
        cell.imageView.image = viewModel.images[indexPath.item]
        return cell
    }
}

extension ResultsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let vc = ImagePreviewViewController(image: viewModel.images[indexPath.item])
        present(vc, animated: true)
    }
}

extension ResultsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset = SFSpacing.md
        let spacing = SFSpacing.sm
        let width = (collectionView.bounds.width - inset * 2 - spacing) / 2
        return CGSize(width: width, height: width * 1.2)
    }
}

// MARK: - Shimmer loading state

private final class ResultsLoadingView: UIView {

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let grid: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = SFSpacing.sm
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let phaseBadge: UILabel = {
        let l = UILabel()
        l.font = SFTypography.captionMedium()
        l.textAlignment = .center
        l.layer.cornerRadius = 12
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 4 rows × 2 = 8 shimmer placeholders — matches ASTRIA_IMAGES_PER_JOB
        for _ in 0..<4 {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = SFSpacing.sm
            row.distribution = .fillEqually
            for _ in 0..<2 {
                let card = SFCardView()
                card.backgroundColor = SFColors.secondaryBackground
                card.translatesAutoresizingMaskIntoConstraints = false
                card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 1.2).isActive = true
                let shimmer = SFShimmerView()
                shimmer.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(shimmer)
                NSLayoutConstraint.activate([
                    shimmer.topAnchor.constraint(equalTo: card.topAnchor),
                    shimmer.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                    shimmer.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    shimmer.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                ])
                row.addArrangedSubview(card)
            }
            grid.addArrangedSubview(row)
        }

        scrollView.addSubview(grid)
        addSubview(scrollView)
        addSubview(phaseBadge)
        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: phaseBadge.topAnchor, constant: -SFSpacing.lg),

            grid.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: SFSpacing.sm),
            grid.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: SFSpacing.md),
            grid.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -SFSpacing.md),
            grid.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -SFSpacing.sm),
            grid.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -SFSpacing.md * 2),

            phaseBadge.bottomAnchor.constraint(equalTo: messageLabel.topAnchor, constant: -SFSpacing.sm),
            phaseBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            phaseBadge.heightAnchor.constraint(equalToConstant: 28),
            phaseBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SFSpacing.xl),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SFSpacing.xl),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SFSpacing.xl),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setMessage(_ text: String, phase: String = "generating") {
        messageLabel.text = text
        switch phase {
        case "training":
            phaseBadge.text = "  🧠 Training AI  "
            phaseBadge.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
            phaseBadge.textColor = .systemOrange
            phaseBadge.isHidden = false
        case "generating":
            phaseBadge.text = "  ✨ Generating  "
            phaseBadge.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.15)
            phaseBadge.textColor = .systemPurple
            phaseBadge.isHidden = false
        default:
            phaseBadge.isHidden = true
        }
    }

    func setFinished() {
        grid.isHidden = true
        phaseBadge.isHidden = true
    }
}

// MARK: - Full Screen Preview

private final class ImagePreviewViewController: UIViewController {

    private let image: UIImage

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let downloadButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "arrow.down.circle.fill"), for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        imageView.image = image
        view.addSubview(imageView)
        view.addSubview(closeButton)
        view.addSubview(downloadButton)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.md),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            downloadButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),
            downloadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            downloadButton.widthAnchor.constraint(equalToConstant: 44),
            downloadButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        closeButton.addTarget(self, action: #selector(dismiss_), for: .touchUpInside)
        downloadButton.addTarget(self, action: #selector(download), for: .touchUpInside)
    }

    @objc private func dismiss_() { dismiss(animated: true) }

    @objc private func download() {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        let banner = UILabel()
        banner.text = "  Saved to Photos  "
        banner.backgroundColor = SFColors.accent
        banner.textColor = .white
        banner.font = SFTypography.captionMedium()
        banner.layer.cornerRadius = SFSpacing.chipRadius
        banner.clipsToBounds = true
        banner.sizeToFit()
        banner.center = CGPoint(x: view.center.x, y: view.bounds.height - 120)
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        UIView.animate(withDuration: 1.5, delay: 1, options: .curveEaseOut) { banner.alpha = 0 } completion: { _ in banner.removeFromSuperview() }
    }
}
