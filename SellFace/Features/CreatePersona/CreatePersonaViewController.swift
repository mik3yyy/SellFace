import UIKit

final class CreatePersonaViewController: UIViewController {

    private let viewModel: CreatePersonaViewModel
    private let photoPicker = PhotoPickerManager()

    // MARK: - Scroll content

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
        ("helmet.fill",   "Helmets",     false),
        ("eye.slash.fill","Low Res",     false),
        ("baseball.fill", "Caps",        false),
        ("sunglasses",    "Sunglasses",  false),
    ])

    private let goodLabel = CreatePersonaViewController.sectionTag("Ideal", color: SFColors.accent)
    private lazy var goodScrollView = buildExampleScroll(items: [
        ("person.fill",  "Good Angle",   true),
        ("sun.max.fill", "Good Light",   true),
        ("face.smiling", "Natural",      true),
        ("photo.fill",   "Sharp & Clear",true),
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

    // MARK: - Post-selection (hidden initially)

    private let selectedPhotosHeader: UILabel = {
        let l = UILabel()
        l.text = "Selected Photos"
        l.font = SFTypography.title3()
        l.textColor = SFColors.label
        l.isHidden = true
        return l
    }()

    private let photoCountLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.captionMedium()
        l.textColor = SFColors.accent
        l.isHidden = true
        return l
    }()

    private lazy var selectedPhotosCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 88, height: 88)
        layout.minimumLineSpacing = SFSpacing.sm
        layout.sectionInset = UIEdgeInsets(top: 0, left: SFSpacing.md, bottom: 0, right: SFSpacing.md)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(SelectedPhotoCell.self, forCellWithReuseIdentifier: SelectedPhotoCell.reuseID)
        cv.isHidden = true
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.heightAnchor.constraint(equalToConstant: 88).isActive = true
        return cv
    }()

    private let nameFieldHeader: UILabel = {
        let l = UILabel()
        l.text = "Name this persona"
        l.font = SFTypography.title3()
        l.textColor = SFColors.label
        l.isHidden = true
        return l
    }()

    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "e.g.  Michael"
        tf.attributedPlaceholder = NSAttributedString(
            string: "e.g.  Michael",
            attributes: [.foregroundColor: SFColors.tertiaryLabel]
        )
        tf.borderStyle = .none
        tf.font = SFTypography.body()
        tf.textColor = SFColors.label
        tf.backgroundColor = SFColors.secondaryBackground
        tf.layer.cornerRadius = SFSpacing.chipRadius
        tf.layer.cornerCurve = .continuous
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: SFSpacing.md, height: 1))
        tf.leftViewMode = .always
        tf.isHidden = true
        tf.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return tf
    }()

    // MARK: - Pinned bottom button (outside scrollView)

    // Single action button that switches between "Pick" and "Create"
    private let actionButton = SFButton(title: "Choose Photos", style: .primary, systemImage: "photo.stack")

    private let buttonBackdrop: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var isInCreateMode = false

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

    // MARK: - Setup

    private func setupUI() {
        title = "Upload Photos"
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never

        // Scroll view (body)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        // Pinned bottom button + blur backdrop
        view.addSubview(buttonBackdrop)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            // Scroll view fills screen but inset at bottom for the button
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: SFSpacing.md),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: SFSpacing.md),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -SFSpacing.md),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -(SFSpacing.buttonHeight + SFSpacing.xxl)),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -SFSpacing.md * 2),

            // Button pinned to bottom
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md),
            actionButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: actionButton.topAnchor, constant: -SFSpacing.md),
        ])

        // Content
        contentStack.addArrangedSubview(heroLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(badLabel)
        contentStack.addArrangedSubview(makeFullWidthScroll(badScrollView))
        contentStack.addArrangedSubview(goodLabel)
        contentStack.addArrangedSubview(makeFullWidthScroll(goodScrollView))
        contentStack.addArrangedSubview(privacyCard)

        // Post-selection content (hidden initially)
        contentStack.addArrangedSubview(selectedPhotosHeader)
        contentStack.addArrangedSubview(photoCountLabel)
        contentStack.addArrangedSubview(makeFullWidthScroll(selectedPhotosCollectionView, height: 88))
        contentStack.addArrangedSubview(nameFieldHeader)
        contentStack.addArrangedSubview(nameField)

        actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)
    }

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

    private func buildExampleScroll(items: [(icon: String, label: String, good: Bool)]) -> UIScrollView {
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
            let card = buildExampleCard(icon: item.icon, label: item.label, good: item.good)
            stack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: 130).isActive = true
        }
        return sv
    }

    private func buildExampleCard(icon: String, label: String, good: Bool) -> UIView {
        let card = SFCardView()
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let color = good ? SFColors.success : SFColors.destructive

        let bg = UIView()
        bg.backgroundColor = color.withAlphaComponent(0.07)
        bg.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 40, weight: .thin)))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

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

        card.addSubview(bg)
        bg.addSubview(iconView)
        card.addSubview(badge)
        card.addSubview(lbl)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: card.topAnchor),
            bg.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bg.heightAnchor.constraint(equalToConstant: 110),

            iconView.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 48),
            iconView.heightAnchor.constraint(equalToConstant: 48),

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

    // MARK: - Bind

    private func bindViewModel() {
        viewModel.onImagesUpdated = { [weak self] in
            self?.revealPostSelectionUI()
        }
        viewModel.onCreationComplete = { [weak self] persona in
            self?.actionButton.setLoading(false)
            self?.viewModel.coordinator?.showPersonaDetail(persona)
        }
        viewModel.onError = { [weak self] message in
            self?.actionButton.setLoading(false)
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    private func revealPostSelectionUI() {
        let count = viewModel.selectedImages.count
        selectedPhotosCollectionView.reloadData()

        UIView.animate(withDuration: 0.36, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            [self.selectedPhotosHeader, self.photoCountLabel,
             self.selectedPhotosCollectionView, self.nameFieldHeader,
             self.nameField].forEach { $0.isHidden = false }
        }

        photoCountLabel.text = "\(count) photo\(count == 1 ? "" : "s") selected"

        // Switch button to "Create" mode
        if !isInCreateMode {
            isInCreateMode = true
            UIView.transition(with: actionButton, duration: 0.22, options: .transitionCrossDissolve) {
                var cfg = self.actionButton.configuration
                cfg?.title = "Create Persona"
                cfg?.image = UIImage(systemName: "sparkles")
                self.actionButton.configuration = cfg
            }
        }

        // Scroll down to reveal name field
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { [weak self] in
            guard let self else { return }
            let bottom = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
            if bottom.y > 0 { scrollView.setContentOffset(bottom, animated: true) }
            nameField.becomeFirstResponder()
        }
    }

    // MARK: - Actions

    @objc private func didTapAction() {
        if isInCreateMode {
            nameField.resignFirstResponder()
            actionButton.setLoading(true)
            viewModel.createPersona(name: nameField.text ?? "")
        } else {
            nameField.resignFirstResponder()
            photoPicker.present(from: self)
        }
    }
}

// MARK: - Photo picker delegate

extension CreatePersonaViewController: PhotoPickerManagerDelegate {
    func photoPickerManager(_ manager: PhotoPickerManager, didSelect images: [UIImage]) {
        viewModel.didSelectImages(images)
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
