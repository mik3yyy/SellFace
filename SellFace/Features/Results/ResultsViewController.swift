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

    private let loadingView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = SFColors.accent
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.tag = 99
        label.font = SFTypography.body()
        label.textColor = SFColors.secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(spinner)
        v.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: v.centerYAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: SFSpacing.xl),
            label.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -SFSpacing.xl),
        ])
        return v
    }()

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

        if let label = loadingView.viewWithTag(99) as? UILabel {
            label.text = viewModel.statusMessage
        }

        if !loading && viewModel.images.isEmpty {
            loadingView.isHidden = false
            if let spinner = loadingView.subviews.first(where: { $0 is UIActivityIndicatorView }) as? UIActivityIndicatorView {
                spinner.stopAnimating()
            }
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
