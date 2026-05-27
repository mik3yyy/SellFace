import UIKit

final class PersonaNameGenderViewController: UIViewController {

    private let viewModel: CreatePersonaViewModel
    private var selectedGender: String = "male"

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Name your persona"
        l.font = SFTypography.title1()
        l.textColor = SFColors.label
        l.numberOfLines = 0
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "We'll use this to identify your AI model."
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "e.g. Michael"
        tf.attributedPlaceholder = NSAttributedString(
            string: "e.g. Michael",
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
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let genderSectionLabel: UILabel = {
        let l = UILabel()
        l.text = "SELECT GENDER"
        l.font = SFTypography.captionMedium()
        l.textColor = SFColors.secondaryLabel
        l.setTracking(1.5)
        return l
    }()

    private lazy var maleButton: UIButton = buildGenderButton(title: "Male", symbol: "person.fill", gender: "male")
    private lazy var femaleButton: UIButton = buildGenderButton(title: "Female", symbol: "person.fill", gender: "female")

    private lazy var genderStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [maleButton, femaleButton])
        s.axis = .horizontal
        s.spacing = SFSpacing.sm
        s.distribution = .fillEqually
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let continueButton = SFButton(title: "Continue →", style: .primary)

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
        updateGenderSelection()
        registerKeyboardObservers()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.nameField.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = SFSpacing.sm
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        mainStack.addArrangedSubview(titleLabel)
        mainStack.addArrangedSubview(subtitleLabel)
        mainStack.setCustomSpacing(SFSpacing.lg, after: subtitleLabel)
        mainStack.addArrangedSubview(nameField)
        mainStack.setCustomSpacing(SFSpacing.lg, after: nameField)
        mainStack.addArrangedSubview(genderSectionLabel)
        mainStack.setCustomSpacing(SFSpacing.sm, after: genderSectionLabel)
        mainStack.addArrangedSubview(genderStack)

        view.addSubview(mainStack)
        view.addSubview(buttonBackdrop)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.xl),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),

            nameField.heightAnchor.constraint(equalToConstant: 54),
            genderStack.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),

            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),
            continueButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),

            buttonBackdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonBackdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonBackdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonBackdrop.topAnchor.constraint(equalTo: continueButton.topAnchor, constant: -SFSpacing.xl),
        ])

        buttonBottomConstraint = continueButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -SFSpacing.md)
        buttonBottomConstraint.isActive = true

        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
    }

    // MARK: - Gender buttons

    private func buildGenderButton(title: String, symbol: String, gender: String) -> UIButton {
        var cfg = UIButton.Configuration.filled()
        cfg.title = title
        cfg.image = UIImage(systemName: symbol)
        cfg.imagePadding = SFSpacing.sm
        cfg.imagePlacement = .leading
        cfg.cornerStyle = .fixed
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = SFTypography.headline()
            return a
        }

        let btn = UIButton(configuration: cfg)
        btn.layer.cornerRadius = SFSpacing.buttonRadius
        btn.layer.cornerCurve = .continuous
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.tag = gender == "male" ? 0 : 1
        btn.addTarget(self, action: #selector(didTapGender(_:)), for: .touchUpInside)
        return btn
    }

    private func updateGenderSelection() {
        let buttons = [maleButton, femaleButton]
        let genders = ["male", "female"]

        for (btn, gender) in zip(buttons, genders) {
            let isSelected = gender == selectedGender
            var cfg = btn.configuration
            cfg?.baseForegroundColor = isSelected ? UIColor(hex: "#1A1208") : SFColors.secondaryLabel
            cfg?.baseBackgroundColor = isSelected ? SFColors.accent : SFColors.secondaryBackground
            btn.configuration = cfg
        }
    }

    // MARK: - Keyboard

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        let overlap = frame.height - view.safeAreaInsets.bottom
        buttonBottomConstraint.constant = -(overlap + SFSpacing.md)
        UIView.animate(withDuration: duration, delay: 0, options: .init(rawValue: curveRaw << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = notification.userInfo,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        buttonBottomConstraint.constant = -SFSpacing.md
        UIView.animate(withDuration: duration, delay: 0, options: .init(rawValue: curveRaw << 16)) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func didTapGender(_ sender: UIButton) {
        selectedGender = sender.tag == 0 ? "male" : "female"
        updateGenderSelection()
    }

    @objc private func didTapContinue() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !name.isEmpty else {
            nameField.layer.borderColor = SFColors.destructive.cgColor
            nameField.layer.borderWidth = 1
            nameField.becomeFirstResponder()
            return
        }
        nameField.layer.borderWidth = 0
        nameField.resignFirstResponder()

        let vc = PersonaReviewViewController(viewModel: viewModel, name: name, gender: selectedGender)
        navigationController?.pushViewController(vc, animated: true)
    }
}
