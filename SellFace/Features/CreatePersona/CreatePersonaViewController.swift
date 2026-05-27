import UIKit

final class CreatePersonaViewController: UIViewController {
    

    private let viewModel: CreatePersonaViewModel
    private let photoPicker = PhotoPickerManager()

    private enum SelectionState { case empty, partial, ready }
    private var selectionState: SelectionState = .empty

    // MARK: - Scroll

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = SFSpacing.sm
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let heroLabel: UILabel = {
        let l = UILabel()
        l.text = "Upload 10–15 photos"
        l.font = SFTypography.title1()
        l.textColor = SFColors.label
        l.numberOfLines = 0
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Use clear, well-lit shots from varied angles. No glasses, hats, or filters."
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    private let badLabel = CreatePersonaViewController.sectionTag("Avoid", color: SFColors.destructive)
    private lazy var badScrollView = buildExampleScroll(items: [
        (UIImage(named: "Helment"),  "Helmets",    false),
        (UIImage(named: "LowRes"),   "Low Res",    false),
        (UIImage(named: "Cap"),      "Caps",       false),
        (UIImage(named: "Glasses"),  "Sunglasses", false),
    ])

    private let goodLabel = CreatePersonaViewController.sectionTag("Ideal", color: SFColors.accent)
    private lazy var goodScrollView = buildExampleScroll(items: [
        (UIImage(named: "GoodAngle"),    "Good Angle",    true),
        (UIImage(named: "GoodLighting"), "Good Light",    true),
        (UIImage(named: "natural"),      "Natural",       true),
        (UIImage(named: "sharp_clear"),  "Sharp & Clear", true),
    ])

    private let privacyCard: SFCardView = {
        let card = SFCardView()
        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)))
        icon.tintColor = SFColors.accent
        icon.translatesAutoresizingMaskIntoConstraints = false
        let l = UILabel()
        l.text = "Photos are deleted from our servers immediately after training completes."
        l.font = SFTypography.subheadline()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(icon)
        card.addSubview(l)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: SFSpacing.md),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            l.topAnchor.constraint(equalTo: card.topAnchor, constant: SFSpacing.md),
            l.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: SFSpacing.sm),
            l.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.md),
            l.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.md),
        ])
        return card
    }()

    // MARK: - Inline post-selection

    private let photoCountLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.captionMedium()
        l.isHidden = true
        return l
    }()

    private lazy var selectedPhotosCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 72, height: 72)
        layout.minimumLineSpacing = SFSpacing.sm
        layout.sectionInset = UIEdgeInsets(top: 0, left: SFSpacing.md, bottom: 0, right: SFSpacing.md)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(SelectedPhotoCell.self, forCellWithReuseIdentifier: SelectedPhotoCell.reuseID)
        cv.isHidden = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.heightAnchor.constraint(equalToConstant: 72).isActive = true
        return cv
    }()

    // MARK: - Bottom button

    private let actionButton = SFButton(title: "Choose Photos", style: .primary, systemImage: "photo.stack")

    private let buttonBackdrop: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var buttonBottomConstraint: NSLayoutConstraint!

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
        bindViewModel()
        photoPicker.delegate = self
        selectedPhotosCollectionView.dataSource = self
        navigationItem.backButtonDisplayMode = .minimal
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let gradient = CAGradientLayer()
        gradient.frame = buttonBackdrop.bounds
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        gradient.locations = [0.0, 0.5]
        buttonBackdrop.layer.mask = gradient
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Upload Photos"
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(buttonBackdrop)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: SFSpacing.md),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: SFSpacing.md),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -SFSpacing.md),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -(SFSpacing.buttonHeight + SFSpacing.xxl)),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -SFSpacing.md * 2),

            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            actionButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: actionButton.topAnchor, constant: -80),
        ])

        let badScroll  = makeFullWidthScroll(badScrollView, height: 155)
        let goodScroll = makeFullWidthScroll(goodScrollView, height: 155)
        let photoStrip = makeFullWidthScroll(selectedPhotosCollectionView, height: 72)

        contentStack.addArrangedSubview(heroLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(SFSpacing.md, after: subtitleLabel)
        contentStack.addArrangedSubview(badLabel)
        contentStack.addArrangedSubview(badScroll)
        contentStack.setCustomSpacing(SFSpacing.md, after: badScroll)
        contentStack.addArrangedSubview(goodLabel)
        contentStack.addArrangedSubview(goodScroll)
        contentStack.setCustomSpacing(SFSpacing.md, after: goodScroll)
        contentStack.addArrangedSubview(privacyCard)
        contentStack.setCustomSpacing(SFSpacing.lg, after: privacyCard)
        contentStack.addArrangedSubview(photoCountLabel)
        contentStack.setCustomSpacing(SFSpacing.sm, after: photoCountLabel)
        contentStack.addArrangedSubview(photoStrip)

        buttonBottomConstraint = actionButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md)
        buttonBottomConstraint.isActive = true

        actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)
    }

    // MARK: - Post-selection

    private func revealPostSelectionUI() {
        let count = viewModel.selectedImages.count
        selectedPhotosCollectionView.reloadData()

        UIView.animate(withDuration: 0.3) {
            self.photoCountLabel.isHidden = false
            self.selectedPhotosCollectionView.isHidden = false
        }

        if count < 10 {
            selectionState = .partial
            let needed = 10 - count
            photoCountLabel.text = "\(count)/10 photos · add \(needed) more"
            photoCountLabel.textColor = SFColors.destructive
            updateButton(title: "Select \(needed) More", icon: "plus.circle")
        } else {
            selectionState = .ready
            photoCountLabel.text = "\(count) photos selected"
            photoCountLabel.textColor = SFColors.success
            updateButton(title: "Continue", icon: "chevron.right")
            pushValueProp()
        }
    }

    private func pushValueProp() {
        let vc = PersonaJourneyViewController(viewModel: viewModel)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func updateButton(title: String, icon: String) {
        UIView.transition(with: actionButton, duration: 0.22, options: .transitionCrossDissolve) {
            var cfg = self.actionButton.configuration
            cfg?.title = title
            cfg?.image = UIImage(systemName: icon)
            self.actionButton.configuration = cfg
        }
    }

    // MARK: - Bind

    private func bindViewModel() {
        viewModel.onImagesUpdated = { [weak self] in
            self?.revealPostSelectionUI()
        }
    }

    // MARK: - Actions

    @objc private func didTapAction() {
        switch selectionState {
        case .empty, .partial:
            let remaining = max(1, 15 - viewModel.selectedImages.count)
            photoPicker.present(from: self, selectionLimit: remaining)
        case .ready:
            pushValueProp()
        }
    }

    // MARK: - Helpers

    private func makeFullWidthScroll(_ innerView: UIView, height: CGFloat = 200) -> UIView {
        let container = UIView()
        container.clipsToBounds = false
        innerView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(innerView)
        NSLayoutConstraint.activate([
            innerView.topAnchor.constraint(equalTo: container.topAnchor),
            innerView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: -SFSpacing.md),
            innerView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: SFSpacing.md),
            innerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            innerView.heightAnchor.constraint(equalToConstant: height),
        ])
        return container
    }

    private func buildExampleScroll(items: [(image: UIImage?, label: String, good: Bool)]) -> UIScrollView {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = SFSpacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        sv.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: sv.topAnchor, constant: SFSpacing.xs),
            stack.leadingAnchor.constraint(equalTo: sv.leadingAnchor, constant: SFSpacing.md),
            stack.trailingAnchor.constraint(equalTo: sv.trailingAnchor, constant: -SFSpacing.md),
            stack.bottomAnchor.constraint(equalTo: sv.bottomAnchor, constant: -SFSpacing.xs),
        ])
        for item in items {
            let card = buildExampleCard(image: item.image, label: item.label, good: item.good)
            stack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: 130).isActive = true
        }
        return sv
    }

    private func buildExampleCard(image: UIImage?, label: String, good: Bool) -> UIView {
        let card = SFCardView()
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let color = good ? SFColors.success : SFColors.destructive

        let bg = UIView()
        bg.backgroundColor = color.withAlphaComponent(0.07)
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.clipsToBounds = true

        let iconView = UIImageView(image: image)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(bg)
        bg.addSubview(iconView)

        if image?.isSymbolImage == true {
            iconView.tintColor = color
            iconView.contentMode = .scaleAspectFit
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 48),
                iconView.heightAnchor.constraint(equalToConstant: 48),
            ])
        } else {
            iconView.contentMode = .scaleAspectFill
            NSLayoutConstraint.activate([
                iconView.topAnchor.constraint(equalTo: bg.topAnchor),
                iconView.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
                iconView.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
                iconView.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            ])
        }

        let badgeImg = UIImage(systemName: good ? "checkmark.circle.fill" : "xmark.circle.fill")
        let badge = UIImageView(image: badgeImg)
        badge.tintColor = color
        badge.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text = label
        lbl.font = SFTypography.captionMedium()
        lbl.textColor = SFColors.secondaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(badge)
        card.addSubview(lbl)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: card.topAnchor),
            bg.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bg.heightAnchor.constraint(equalToConstant: 110),

            badge.topAnchor.constraint(equalTo: card.topAnchor, constant: SFSpacing.sm),
            badge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.sm),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),

            lbl.topAnchor.constraint(equalTo: bg.bottomAnchor, constant: SFSpacing.sm),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.xs),
            lbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.xs),
            lbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.sm),
        ])
        return card
    }

    private static func sectionTag(_ text: String, color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text.uppercased()
        l.font = SFTypography.captionMedium()
        l.textColor = color
        l.setTracking(1.8)
        return l
    }
}

// MARK: - Photo picker delegate

extension CreatePersonaViewController: PhotoPickerManagerDelegate {
    func photoPickerManager(_ manager: PhotoPickerManager, didSelect images: [UIImage]) {
        viewModel.addImages(images)
    }
    func photoPickerManagerDidCancel(_ manager: PhotoPickerManager) {}
}

// MARK: - Collection view data source

extension CreatePersonaViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.selectedImages.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SelectedPhotoCell.reuseID, for: indexPath) as! SelectedPhotoCell
        cell.configure(image: viewModel.selectedImages[indexPath.item])
        return cell
    }
}

// MARK: - Selected photo cell

private final class SelectedPhotoCell: UICollectionViewCell {
    static let reuseID = "SelectedPhotoCell"

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
