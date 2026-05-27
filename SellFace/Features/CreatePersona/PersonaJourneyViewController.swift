import UIKit

// Single screen that slides through all 4 steps of persona creation.
final class PersonaJourneyViewController: UIViewController {

    private let viewModel: CreatePersonaViewModel

    // MARK: - Step state

    private enum Step: Int, CaseIterable {
        case socialProof, nameGender, review, success
    }

    private var currentStep: Step = .socialProof
    private var selectedGender = "male"
    private var personaName = ""
    private var createdPersona: Persona?

    // Weak refs to step-specific controls
    private weak var nameFieldRef: UITextField?
    private weak var maleButtonRef: UIButton?
    private weak var femaleButtonRef: UIButton?
    private weak var progressBarRef: UIProgressView?
    private weak var uploadingLabelRef: UILabel?
    private weak var photoGridRef: UICollectionView?

    // MARK: - Fixed chrome

    private let containerView: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var currentStepView: UIView?

    private let continueButton = SFButton(title: "Continue", style: .primary, systemImage: "chevron.right")
    private var buttonBottomConstraint: NSLayoutConstraint!
    private var containerBottomConstraint: NSLayoutConstraint!

    private let buttonBackdrop: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Uploading bar (replaces button during upload)

    private let uploadingBarView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.alpha = 0
        return v
    }()

    private let uploadThumbScroll: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let uploadThumbStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 4
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
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
        setupChrome()
        bindViewModel()
        showStep(.socialProof, animated: false)
        registerKeyboardObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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

    // MARK: - Chrome setup

    private func setupChrome() {
        view.backgroundColor = SFColors.background

        continueButton.translatesAutoresizingMaskIntoConstraints = false

        // Build uploading bar content
        uploadThumbScroll.addSubview(uploadThumbStack)

        let progressBar = UIProgressView(progressViewStyle: .default)
        progressBar.progressTintColor = SFColors.accent
        progressBar.trackTintColor = SFColors.tertiaryBackground
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBarRef = progressBar

        let uploadLabel = UILabel()
        uploadLabel.text = "Preparing upload…"
        uploadLabel.font = SFTypography.subheadline()
        uploadLabel.textColor = SFColors.secondaryLabel
        uploadLabel.textAlignment = .center
        uploadLabel.translatesAutoresizingMaskIntoConstraints = false
        uploadingLabelRef = uploadLabel

        uploadingBarView.addSubview(uploadThumbScroll)
        uploadingBarView.addSubview(uploadLabel)
        uploadingBarView.addSubview(progressBar)

        view.addSubview(containerView)
        view.addSubview(buttonBackdrop)
        view.addSubview(continueButton)
        view.addSubview(uploadingBarView)

        containerBottomConstraint = containerView.bottomAnchor.constraint(
            equalTo: continueButton.topAnchor, constant: -SFSpacing.md)

        buttonBottomConstraint = continueButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerBottomConstraint,

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: continueButton.topAnchor, constant: -80),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            continueButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),
            buttonBottomConstraint,

            // Uploading bar — same horizontal as button
            uploadingBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            uploadingBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            uploadingBarView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.sm),

            // Thumb scroll
            uploadThumbStack.topAnchor.constraint(equalTo: uploadThumbScroll.topAnchor),
            uploadThumbStack.leadingAnchor.constraint(equalTo: uploadThumbScroll.leadingAnchor, constant: SFSpacing.md),
            uploadThumbStack.trailingAnchor.constraint(equalTo: uploadThumbScroll.trailingAnchor, constant: -SFSpacing.md),
            uploadThumbStack.bottomAnchor.constraint(equalTo: uploadThumbScroll.bottomAnchor),
            uploadThumbStack.heightAnchor.constraint(equalTo: uploadThumbScroll.heightAnchor),

            uploadThumbScroll.topAnchor.constraint(equalTo: uploadingBarView.topAnchor),
            uploadThumbScroll.leadingAnchor.constraint(equalTo: uploadingBarView.leadingAnchor),
            uploadThumbScroll.trailingAnchor.constraint(equalTo: uploadingBarView.trailingAnchor),
            uploadThumbScroll.heightAnchor.constraint(equalToConstant: 64),

            uploadLabel.topAnchor.constraint(equalTo: uploadThumbScroll.bottomAnchor, constant: SFSpacing.xs),
            uploadLabel.centerXAnchor.constraint(equalTo: uploadingBarView.centerXAnchor),

            progressBar.topAnchor.constraint(equalTo: uploadLabel.bottomAnchor, constant: SFSpacing.xs),
            progressBar.leadingAnchor.constraint(equalTo: uploadingBarView.leadingAnchor, constant: SFSpacing.md),
            progressBar.trailingAnchor.constraint(equalTo: uploadingBarView.trailingAnchor, constant: -SFSpacing.md),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressBar.bottomAnchor.constraint(equalTo: uploadingBarView.bottomAnchor),
        ])

        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
    }

    // MARK: - Step management

    private func showStep(_ step: Step, animated: Bool) {
        currentStep = step
        let newView = buildView(for: step)
        newView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        updateButtonTitle(for: step)

        guard animated, let old = currentStepView else {
            currentStepView?.removeFromSuperview()
            containerView.addSubview(newView)
            newView.frame = containerView.bounds
            currentStepView = newView
            return
        }

        let w = containerView.bounds.width
        newView.frame = CGRect(x: w, y: 0, width: w, height: containerView.bounds.height)
        containerView.addSubview(newView)

        UIView.animate(withDuration: 0.44, delay: 0,
                       usingSpringWithDamping: 0.86, initialSpringVelocity: 0.15) {
            old.frame.origin.x = -w
            newView.frame.origin.x = 0
        } completion: { _ in old.removeFromSuperview() }

        currentStepView = newView
    }

    private func updateButtonTitle(for step: Step) {
        let (title, icon): (String, String) = {
            switch step {
            case .socialProof: return ("Continue", "chevron.right")
            case .nameGender:  return ("Continue", "chevron.right")
            case .review:      return ("Start Creating", "sparkles")
            case .success:     return ("Let's Go", "arrow.right")
            }
        }()
        UIView.transition(with: continueButton, duration: 0.22, options: .transitionCrossDissolve) {
            var cfg = self.continueButton.configuration
            cfg?.title = title
            cfg?.image = UIImage(systemName: icon)
            self.continueButton.configuration = cfg
        }
    }

    // MARK: - Action

    @objc private func didTapContinue() {
        view.endEditing(true)
        switch currentStep {
        case .socialProof:
            showStep(.nameGender, animated: true)

        case .nameGender:
            let name = nameFieldRef?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !name.isEmpty else {
                nameFieldRef?.layer.borderColor = SFColors.destructive.cgColor
                nameFieldRef?.layer.borderWidth = 1.5
                nameFieldRef?.becomeFirstResponder()
                return
            }
            nameFieldRef?.layer.borderWidth = 0
            personaName = name
            showStep(.review, animated: true)

        case .review:
            navigationItem.hidesBackButton = true
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false

            // Populate upload thumbnails with selected photos
            uploadThumbStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for img in viewModel.selectedImages {
                let iv = UIImageView(image: img)
                iv.contentMode = .scaleAspectFill
                iv.clipsToBounds = true
                iv.layer.cornerRadius = 8
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.widthAnchor.constraint(equalToConstant: 64).isActive = true
                iv.heightAnchor.constraint(equalToConstant: 64).isActive = true
                iv.alpha = 0.35
                uploadThumbStack.addArrangedSubview(iv)
            }

            // Swap bottom chrome: button → uploading bar
            containerBottomConstraint.isActive = false
            containerBottomConstraint = containerView.bottomAnchor.constraint(
                equalTo: uploadingBarView.topAnchor, constant: -SFSpacing.sm)
            containerBottomConstraint.isActive = true

            UIView.animate(withDuration: 0.35, delay: 0,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
                self.continueButton.alpha = 0
                self.uploadingBarView.alpha = 1
                self.view.layoutIfNeeded()
            }

            viewModel.createPersona(name: personaName, gender: selectedGender)

        case .success:
            guard let persona = createdPersona else { return }
            viewModel.coordinator?.showPersonaDetailAfterCreation(persona)
        }
    }

    // MARK: - Bind

    private func bindViewModel() {
        viewModel.onProgress = { [weak self] uploaded, total in
            guard let self else { return }
            progressBarRef?.setProgress(Float(uploaded) / Float(total), animated: true)
            uploadingLabelRef?.text = "Uploading \(uploaded) of \(total)…"

            // Highlight completed and current thumbnails
            let thumbs = uploadThumbStack.arrangedSubviews
            for (i, thumb) in thumbs.enumerated() {
                UIView.animate(withDuration: 0.25) {
                    if i < uploaded - 1 {
                        thumb.alpha = 1.0
                        thumb.transform = .identity
                    } else if i == uploaded - 1 {
                        thumb.alpha = 1.0
                        thumb.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                    } else {
                        thumb.alpha = 0.35
                        thumb.transform = .identity
                    }
                }
            }

            // Scroll to current thumb
            if uploaded - 1 < thumbs.count {
                let thumb = thumbs[uploaded - 1]
                uploadThumbScroll.scrollRectToVisible(thumb.frame, animated: true)
            }
        }

        viewModel.onCreationComplete = { [weak self] persona in
            guard let self else { return }
            createdPersona = persona
            // Re-show button for success step
            containerBottomConstraint.isActive = false
            containerBottomConstraint = containerView.bottomAnchor.constraint(
                equalTo: continueButton.topAnchor, constant: -SFSpacing.md)
            containerBottomConstraint.isActive = true
            UIView.animate(withDuration: 0.3) {
                self.continueButton.alpha = 1
                self.uploadingBarView.alpha = 0
                self.view.layoutIfNeeded()
            }
            showStep(.success, animated: true)
        }

        viewModel.onError = { [weak self] message in
            guard let self else { return }
            navigationItem.hidesBackButton = false
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            // Restore button
            containerBottomConstraint.isActive = false
            containerBottomConstraint = containerView.bottomAnchor.constraint(
                equalTo: continueButton.topAnchor, constant: -SFSpacing.md)
            containerBottomConstraint.isActive = true
            UIView.animate(withDuration: 0.3) {
                self.continueButton.alpha = 1
                self.uploadingBarView.alpha = 0
                self.view.layoutIfNeeded()
            }
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Keyboard

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let info = n.userInfo,
              let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let dur = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        buttonBottomConstraint.constant = -(frame.height - view.safeAreaInsets.bottom + SFSpacing.md)
        UIView.animate(withDuration: dur, delay: 0, options: .init(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        guard let info = n.userInfo,
              let dur = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curve = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        buttonBottomConstraint.constant = -SFSpacing.md
        UIView.animate(withDuration: dur, delay: 0, options: .init(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Step builders

    private func buildView(for step: Step) -> UIView {
        switch step {
        case .socialProof: return buildSocialProofView()
        case .nameGender:  return buildNameGenderView()
        case .review:      return buildReviewView()
        case .success:     return buildSuccessView()
        }
    }

    // MARK: - Step 1: Social proof

    private func buildSocialProofView() -> UIView {
        let container = UIView()

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = SFSpacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let stat = UILabel()
        stat.text = "21×"
        stat.font = UIFont.systemFont(ofSize: 80, weight: .black)
        stat.textColor = SFColors.accent
        stat.textAlignment = .center

        let statSub = UILabel()
        statSub.text = "More LinkedIn Views"
        statSub.font = SFTypography.title2()
        statSub.textColor = SFColors.label
        statSub.textAlignment = .center

        let card = UIImageView(image: UIImage(named: "Linkedin_ex"))
        card.contentMode = .scaleAspectFit
        card.layer.cornerRadius = 10
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true

        let subtitle = UILabel()
        subtitle.text = "Profiles with a photo get 21× more views\n& 9× more connection requests"
        subtitle.font = SFTypography.callout()
        subtitle.textColor = SFColors.secondaryLabel
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        stack.addArrangedSubview(stat)
        stack.setCustomSpacing(0, after: stat)
        stack.addArrangedSubview(statSub)
        stack.setCustomSpacing(SFSpacing.lg, after: statSub)
        stack.addArrangedSubview(card)
        stack.setCustomSpacing(SFSpacing.lg, after: card)
        stack.addArrangedSubview(subtitle)

        card.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        card.heightAnchor.constraint(equalTo: card.widthAnchor, multiplier: 0.55).isActive = true

        let centerY = stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        centerY.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(greaterThanOrEqualTo: container.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.xl),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -SFSpacing.md),
            centerY,
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SFSpacing.md),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SFSpacing.md),
        ])
        return container
    }

    // MARK: - Step 2: Name + Gender

    private func buildNameGenderView() -> UIView {
        let container = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = SFSpacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let title = UILabel()
        title.text = "What should we\ncall you?"
        title.font = SFTypography.title1()
        title.textColor = SFColors.label
        title.numberOfLines = 2

        let subtitle = UILabel()
        subtitle.text = "Give your AI persona a name."
        subtitle.font = SFTypography.callout()
        subtitle.textColor = SFColors.secondaryLabel

        let field = UITextField()
        field.placeholder = "e.g. Michael"
        field.attributedPlaceholder = NSAttributedString(
            string: "e.g. Michael",
            attributes: [.foregroundColor: SFColors.tertiaryLabel])
        field.borderStyle = .none
        field.font = SFTypography.body()
        field.textColor = SFColors.label
        field.backgroundColor = SFColors.secondaryBackground
        field.layer.cornerRadius = SFSpacing.chipRadius
        field.layer.cornerCurve = .continuous
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: SFSpacing.md, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 54).isActive = true
        field.returnKeyType = .done
        field.addTarget(self, action: #selector(textFieldDone), for: .editingDidEndOnExit)
        nameFieldRef = field

        let genderCaption = UILabel()
        genderCaption.text = "I AM A"
        genderCaption.font = SFTypography.captionMedium()
        genderCaption.textColor = SFColors.secondaryLabel

        let maleBtn = makeGenderButton(title: "Male", icon: "person.fill", isSelected: selectedGender == "male")
        maleBtn.tag = 0
        maleBtn.addTarget(self, action: #selector(didTapGender(_:)), for: .touchUpInside)
        maleButtonRef = maleBtn

        let femaleBtn = makeGenderButton(title: "Female", icon: "person.fill", isSelected: selectedGender == "female")
        femaleBtn.tag = 1
        femaleBtn.addTarget(self, action: #selector(didTapGender(_:)), for: .touchUpInside)
        femaleButtonRef = femaleBtn

        let genderRow = UIStackView(arrangedSubviews: [maleBtn, femaleBtn])
        genderRow.axis = .horizontal
        genderRow.spacing = SFSpacing.sm
        genderRow.distribution = .fillEqually

        stack.addArrangedSubview(title)
        stack.setCustomSpacing(SFSpacing.xs, after: title)
        stack.addArrangedSubview(subtitle)
        stack.setCustomSpacing(SFSpacing.lg, after: subtitle)
        stack.addArrangedSubview(field)
        stack.setCustomSpacing(SFSpacing.lg, after: field)
        stack.addArrangedSubview(genderCaption)
        stack.setCustomSpacing(SFSpacing.sm, after: genderCaption)
        stack.addArrangedSubview(genderRow)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.xl),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SFSpacing.md),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SFSpacing.md),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak field] in
            field?.becomeFirstResponder()
        }
        return container
    }

    private func makeGenderButton(title: String, icon: String, isSelected: Bool) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.image = UIImage(systemName: icon)
        cfg.imagePlacement = .leading
        cfg.imagePadding = SFSpacing.sm
        cfg.baseBackgroundColor = isSelected ? SFColors.accent : SFColors.secondaryBackground
        cfg.baseForegroundColor = isSelected ? .white : SFColors.secondaryLabel
        cfg.cornerStyle = .fixed
        cfg.background.cornerRadius = SFSpacing.buttonRadius
        let btn = UIButton(configuration: cfg)
        btn.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight).isActive = true
        return btn
    }

    @objc private func didTapGender(_ sender: UIButton) {
        selectedGender = sender.tag == 0 ? "male" : "female"
        guard let mBtn = maleButtonRef, let fBtn = femaleButtonRef else { return }
        UIView.animate(withDuration: 0.2) {
            var mCfg = mBtn.configuration
            mCfg?.baseBackgroundColor = self.selectedGender == "male" ? SFColors.accent : SFColors.secondaryBackground
            mCfg?.baseForegroundColor = self.selectedGender == "male" ? .white : SFColors.secondaryLabel
            mBtn.configuration = mCfg

            var fCfg = fBtn.configuration
            fCfg?.baseBackgroundColor = self.selectedGender == "female" ? SFColors.accent : SFColors.secondaryBackground
            fCfg?.baseForegroundColor = self.selectedGender == "female" ? .white : SFColors.secondaryLabel
            fBtn.configuration = fCfg
        }
    }

    @objc private func textFieldDone() { view.endEditing(true) }

    // MARK: - Step 3: Review

    private func buildReviewView() -> UIView {
        let container = UIView()

        // Back button — lets users return to photo selection
        let backBtn = UIButton(type: .system)
        var backCfg = UIButton.Configuration.plain()
        backCfg.title = "Edit Photos"
        backCfg.image = UIImage(systemName: "chevron.left")
        backCfg.imagePlacement = .leading
        backCfg.imagePadding = 4
        backCfg.baseForegroundColor = SFColors.secondaryLabel
        backCfg.contentInsets = .zero
        backBtn.configuration = backCfg
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.addTarget(self, action: #selector(didTapBackInReview), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = "Overview"
        titleLabel.font = SFTypography.title1()
        titleLabel.textColor = SFColors.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "Are you happy with your photos for \(personaName)?"
        subtitle.font = SFTypography.callout()
        subtitle.textColor = SFColors.secondaryLabel
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let grid = UICollectionView(frame: .zero, collectionViewLayout: makeReviewGridLayout())
        grid.backgroundColor = .clear
        grid.showsVerticalScrollIndicator = false
        grid.isScrollEnabled = true
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.register(JourneyPhotoCell.self, forCellWithReuseIdentifier: JourneyPhotoCell.reuseID)
        grid.dataSource = self
        photoGridRef = grid

        container.addSubview(backBtn)
        container.addSubview(titleLabel)
        container.addSubview(subtitle)
        container.addSubview(grid)

        NSLayoutConstraint.activate([
            backBtn.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.sm),
            backBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SFSpacing.md),

            titleLabel.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: SFSpacing.xs),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SFSpacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SFSpacing.md),

            subtitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: SFSpacing.xs),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: SFSpacing.md),
            subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -SFSpacing.md),

            grid.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: SFSpacing.md),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    @objc private func didTapBackInReview() {
        navigationController?.popViewController(animated: true)
    }

    private func makeReviewGridLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, env in
            let hPad: CGFloat = SFSpacing.md
            let gap: CGFloat = 3
            let colW = (env.container.effectiveContentSize.width - hPad * 2) / 3
            // All 3 items in a row share the row height — no gaps within rows
            let tallH: CGFloat  = colW * 1.5
            let shortH: CGFloat = colW * 0.95

            func makeItem() -> NSCollectionLayoutItem {
                let it = NSCollectionLayoutItem(layoutSize: .init(
                    widthDimension: .fractionalWidth(1.0 / 3.0),
                    heightDimension: .fractionalHeight(1.0)))  // fills full row height
                it.contentInsets = NSDirectionalEdgeInsets(
                    top: 0, leading: gap / 2, bottom: 0, trailing: gap / 2)
                return it
            }

            func makeRow(height: CGFloat) -> NSCollectionLayoutGroup {
                NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(widthDimension: .fractionalWidth(1),
                                      heightDimension: .absolute(height)),
                    subitems: [makeItem(), makeItem(), makeItem()])
            }

            // Outer group: tall row + short row (6 items, zero gaps within rows)
            let outerGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: .init(widthDimension: .fractionalWidth(1),
                                  heightDimension: .absolute(tallH + shortH + gap)),
                subitems: [makeRow(height: tallH), makeRow(height: shortH)])
            outerGroup.interItemSpacing = .fixed(gap)

            let section = NSCollectionLayoutSection(group: outerGroup)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: hPad, bottom: 0, trailing: hPad)
            section.interGroupSpacing = gap
            return section
        }
    }

    // MARK: - Step 4: Success comparison

    private func buildSuccessView() -> UIView {
        let container = UIView()

        let leftPanel = UIView()
        leftPanel.backgroundColor = UIColor(hex: "#080808")
        leftPanel.translatesAutoresizingMaskIntoConstraints = false

        let rightPanel = UIView()
        rightPanel.backgroundColor = UIColor(hex: "#0F0F2A")
        rightPanel.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        divider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(leftPanel)
        container.addSubview(rightPanel)
        container.addSubview(divider)

        NSLayoutConstraint.activate([
            leftPanel.topAnchor.constraint(equalTo: container.topAnchor),
            leftPanel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftPanel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leftPanel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5),

            rightPanel.topAnchor.constraint(equalTo: container.topAnchor),
            rightPanel.leadingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            rightPanel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rightPanel.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            divider.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
        ])

        addPanelContent(to: leftPanel,
            icon: UIImage(systemName: "camera.fill"),
            iconTint: UIColor(white: 0.8, alpha: 1),
            iconBg: UIColor(white: 0.12, alpha: 1),
            name: "Photographer",
            nameColor: SFColors.secondaryLabel,
            time: "3 hours+",
            cost: "£230",
            costColor: SFColors.label,
            badge: nil)

        let appIcon = UIImage(named: "SellFaceIcon") ?? UIImage(systemName: "sparkles")
        addPanelContent(to: rightPanel,
            icon: appIcon,
            iconTint: appIcon?.isSymbolImage == true ? SFColors.accent : nil,
            iconBg: UIColor.white,
            name: "SellFace",
            nameColor: SFColors.accent,
            time: "~1 min",
            cost: "£9.99",
            costColor: SFColors.accent,
            badge: "20X CHEAPER")

        return container
    }

    private func addPanelContent(to panel: UIView, icon: UIImage?, iconTint: UIColor?, iconBg: UIColor,
                                  name: String, nameColor: UIColor, time: String,
                                  cost: String, costColor: UIColor, badge: String?) {
        let iconContainer = UIView()
        iconContainer.backgroundColor = iconBg
        iconContainer.layer.cornerRadius = SFSpacing.cardRadius
        iconContainer.layer.cornerCurve = .continuous
        iconContainer.clipsToBounds = true
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: icon)
        iconView.contentMode = iconTint != nil ? .scaleAspectFit : .scaleAspectFill
        if let t = iconTint { iconView.tintColor = t }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        let pad: CGFloat = iconTint != nil ? SFSpacing.md : 0
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: pad),
            iconView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor, constant: pad),
            iconView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: -pad),
            iconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: -pad),
        ])

        let makeLabel = { (text: String, font: UIFont, color: UIColor) -> UILabel in
            let l = UILabel()
            l.text = text
            l.font = font
            l.textColor = color
            l.textAlignment = .center
            return l
        }

        let nameLabel  = makeLabel(name, SFTypography.callout(), nameColor)
        let timeCap    = makeLabel("TIME", SFTypography.captionMedium(), SFColors.secondaryLabel)
        let timeLabel  = makeLabel(time, SFTypography.title2(), SFColors.label)
        let costCap    = makeLabel("COST", SFTypography.captionMedium(), SFColors.secondaryLabel)
        let costLabel  = makeLabel(cost, SFTypography.title2(), costColor)

        var views: [UIView] = [iconContainer, nameLabel, timeCap, timeLabel, costCap, costLabel]

        if let badgeText = badge {
            let lbl = UILabel()
            lbl.text = badgeText
            lbl.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            lbl.textColor = SFColors.background
            lbl.backgroundColor = SFColors.accent
            lbl.textAlignment = .center
            lbl.layer.cornerRadius = 6
            lbl.clipsToBounds = true

            let wrapper = UIView()
            lbl.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
                lbl.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
                lbl.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 10),
                lbl.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -10),
                lbl.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            ])
            views.append(wrapper)
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = SFSpacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 80),
            iconContainer.heightAnchor.constraint(equalToConstant: 80),
            stack.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: SFSpacing.md),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -SFSpacing.md),
        ])
    }
}

// MARK: - Collection view

extension PersonaJourneyViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.selectedImages.count
    }
    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: JourneyPhotoCell.reuseID, for: indexPath) as! JourneyPhotoCell
        cell.configure(image: viewModel.selectedImages[indexPath.item])
        return cell
    }
}

// MARK: - Photo cell

private final class JourneyPhotoCell: UICollectionViewCell {
    static let reuseID = "JourneyPhotoCell"
    private let iv: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: contentView.topAnchor),
            iv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            iv.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(image: UIImage) { iv.image = image }
}
