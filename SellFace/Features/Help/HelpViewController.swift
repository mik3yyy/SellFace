import UIKit
import WebKit

// MARK: - Help Entry Point (sheet modal)

final class HelpViewController: UIViewController {

    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Articles", "Chat"])
        sc.selectedSegmentIndex = 0
        sc.selectedSegmentTintColor = SFColors.accent
        sc.setTitleTextAttributes([.foregroundColor: SFColors.label, .font: SFTypography.subheadline()], for: .normal)
        sc.setTitleTextAttributes([.foregroundColor: UIColor(hex: "#1A1208"), .font: SFTypography.subheadlineBold()], for: .selected)
        sc.backgroundColor = SFColors.secondaryBackground
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let faqPage = FAQPageView()
    private let chatPage = ChatPageView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Help & Support"
        view.backgroundColor = SFColors.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem?.tintColor = SFColors.secondaryLabel

        view.addSubview(segmentedControl)
        view.addSubview(faqPage)
        view.addSubview(chatPage)

        faqPage.translatesAutoresizingMaskIntoConstraints = false
        chatPage.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: SFSpacing.md),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: SFSpacing.md),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -SFSpacing.md),

            faqPage.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: SFSpacing.md),
            faqPage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            faqPage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            faqPage.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            chatPage.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: SFSpacing.md),
            chatPage.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatPage.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatPage.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        chatPage.isHidden = true
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }

    @objc private func segmentChanged() {
        let showFAQ = segmentedControl.selectedSegmentIndex == 0
        UIView.animate(withDuration: 0.22) {
            self.faqPage.alpha = showFAQ ? 1 : 0
            self.chatPage.alpha = showFAQ ? 0 : 1
        } completion: { _ in
            self.faqPage.isHidden = !showFAQ
            self.chatPage.isHidden = showFAQ
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

// MARK: - FAQ Page

private final class FAQPageView: UIView {

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 60
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var expandedIndex: Int? = nil
    private let articles = FAQArticle.all

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView.register(FAQCell.self, forCellReuseIdentifier: FAQCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension FAQPageView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { articles.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FAQCell.reuseID, for: indexPath) as! FAQCell
        cell.configure(with: articles[indexPath.row], expanded: expandedIndex == indexPath.row)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let wasExpanded = expandedIndex == indexPath.row
        let previousIndex = expandedIndex
        expandedIndex = wasExpanded ? nil : indexPath.row

        var toReload: [IndexPath] = [indexPath]
        if let prev = previousIndex, prev != indexPath.row {
            toReload.append(IndexPath(row: prev, section: 0))
        }
        tableView.reloadRows(at: toReload, with: .automatic)
    }
}

// MARK: - FAQ Cell
// Uses a vertical UIStackView so hiding answerLabel automatically collapses its space

private final class FAQCell: UITableViewCell {
    static let reuseID = "FAQCell"

    private let card = SFCardView()

    private let questionLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.subheadlineBold()
        l.textColor = SFColors.label
        l.numberOfLines = 0
        return l
    }()

    private let chevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.down"))
        iv.tintColor = SFColors.secondaryLabel
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        return iv
    }()

    private let answerLabel: UILabel = {
        let l = UILabel()
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        // Question row: question text + chevron side by side
        let questionRow = UIStackView(arrangedSubviews: [questionLabel, chevron])
        questionRow.axis = .horizontal
        questionRow.spacing = SFSpacing.sm
        questionRow.alignment = .center

        // Vertical stack: question row on top, answer below
        // When answerLabel.isHidden = true the stack collapses its space automatically
        let vStack = UIStackView(arrangedSubviews: [questionRow, answerLabel])
        vStack.axis = .vertical
        vStack.spacing = SFSpacing.sm
        vStack.translatesAutoresizingMaskIntoConstraints = false

        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        card.addSubview(vStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SFSpacing.xs),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SFSpacing.md),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SFSpacing.md),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SFSpacing.xs),

            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: SFSpacing.md),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: SFSpacing.md),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -SFSpacing.md),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -SFSpacing.md),

            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with article: FAQArticle, expanded: Bool) {
        questionLabel.text = article.question
        answerLabel.text = article.answer
        answerLabel.isHidden = !expanded
        UIView.animate(withDuration: 0.18) {
            self.chevron.transform = expanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        }
        chevron.tintColor = expanded ? SFColors.accent : SFColors.secondaryLabel
    }
}

// MARK: - Chat Page

private final class ChatPageView: UIView {

    private let promptView = UIView()
    private var webView: WKWebView?

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "message.badge.waveform.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 40, weight: .thin)))
        iv.tintColor = SFColors.accent
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Chat with us"
        l.font = SFTypography.title2()
        l.textColor = SFColors.label
        l.textAlignment = .center
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "We typically respond within a few hours.\nTap below to open live chat."
        l.font = SFTypography.callout()
        l.textColor = SFColors.secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let chatButton = SFButton(title: "Start Chat", style: .primary, systemImage: "bubble.left.and.bubble.right.fill")

    private let emailButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Email: support@sellface.app", for: .normal)
        b.titleLabel?.font = SFTypography.footnote()
        b.tintColor = SFColors.accent
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = SFSpacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        promptView.translatesAutoresizingMaskIntoConstraints = false
        chatButton.translatesAutoresizingMaskIntoConstraints = false

        promptView.addSubview(stack)
        promptView.addSubview(chatButton)
        promptView.addSubview(emailButton)
        addSubview(promptView)

        NSLayoutConstraint.activate([
            promptView.topAnchor.constraint(equalTo: topAnchor),
            promptView.leadingAnchor.constraint(equalTo: leadingAnchor),
            promptView.trailingAnchor.constraint(equalTo: trailingAnchor),
            promptView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.heightAnchor.constraint(equalToConstant: 56),

            stack.centerXAnchor.constraint(equalTo: promptView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: promptView.centerYAnchor, constant: -60),
            stack.leadingAnchor.constraint(equalTo: promptView.leadingAnchor, constant: SFSpacing.xl),
            stack.trailingAnchor.constraint(equalTo: promptView.trailingAnchor, constant: -SFSpacing.xl),

            chatButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: SFSpacing.xl),
            chatButton.leadingAnchor.constraint(equalTo: promptView.leadingAnchor, constant: SFSpacing.md),
            chatButton.trailingAnchor.constraint(equalTo: promptView.trailingAnchor, constant: -SFSpacing.md),
            chatButton.heightAnchor.constraint(equalToConstant: SFSpacing.buttonHeight),

            emailButton.topAnchor.constraint(equalTo: chatButton.bottomAnchor, constant: SFSpacing.md),
            emailButton.centerXAnchor.constraint(equalTo: promptView.centerXAnchor),
        ])

        chatButton.addTarget(self, action: #selector(openChat), for: .touchUpInside)
        emailButton.addTarget(self, action: #selector(openEmail), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func openChat() {
        // Load an HTML page that executes the Tawk.to embed script.
        // Loading the embed URL directly returns raw JS source — we must wrap it.
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { width: 100%; height: 100%; background: #07070f; }
        </style>
        </head>
        <body>
        <script type="text/javascript">
        var Tawk_API=Tawk_API||{}, Tawk_LoadStart=new Date();
        (function(){
        var s1=document.createElement("script"),s0=document.getElementsByTagName("script")[0];
        s1.async=true;
        s1.src='https://embed.tawk.to/69f7c383f7a9801c3e05b70b/1jnnt7fd7';
        s1.charset='UTF-8';
        s1.setAttribute('crossorigin','*');
        s0.parentNode.insertBefore(s1,s0);
        })();
        </script>
        </body>
        </html>
        """

        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = SFColors.background
        wv.scrollView.backgroundColor = SFColors.background
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.alpha = 0
        addSubview(wv)

        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: topAnchor),
            wv.leadingAnchor.constraint(equalTo: leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // baseURL must be https so the script is allowed to load external resources
        wv.loadHTMLString(html, baseURL: URL(string: "https://tawk.to"))

        UIView.animate(withDuration: 0.28) {
            self.promptView.alpha = 0
            wv.alpha = 1
        }

        webView = wv
    }

    @objc private func openEmail() {
        if let url = URL(string: "mailto:support@sellface.app") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - FAQ Data

struct FAQArticle {
    let question: String
    let answer: String

    static let all: [FAQArticle] = [
        FAQArticle(
            question: "What is SellFace?",
            answer: "SellFace uses AI to generate elite professional headshots from your photos. Upload 10–15 photos of yourself and choose a style — we'll train a personal AI model and deliver polished portraits within 20–30 minutes."
        ),
        FAQArticle(
            question: "How many photos should I upload?",
            answer: "For best results, upload 10–15 clear, well-lit photos. Use a variety of angles (front, slight left, slight right) and avoid group shots, sunglasses, or heavily filtered images."
        ),
        FAQArticle(
            question: "How long does processing take?",
            answer: "Training your personal AI model takes around 20–30 minutes. Once training is complete, generating images in a chosen style takes just 2–5 minutes. We'll send a notification when your results are ready."
        ),
        FAQArticle(
            question: "What style bundles are available?",
            answer: "We currently offer Professional, Casual, Executive, Creator, LinkedIn, Old Money, Sales, and Studio styles. Each bundle generates 8 unique headshots tailored to that style."
        ),
        FAQArticle(
            question: "Can I create multiple personas?",
            answer: "Yes — you can create as many personas as you like. Each persona is trained separately, so you can have different looks for different purposes (e.g. one for corporate, one for creative work)."
        ),
        FAQArticle(
            question: "Why did my persona fail?",
            answer: "Processing can fail if the uploaded photos are very low resolution, heavily obscured, or if there's a temporary service issue. Try creating a new persona with clearer photos. If the problem persists, contact support."
        ),
        FAQArticle(
            question: "Are my photos stored securely?",
            answer: "Your photos are uploaded securely and used only to train your personal AI model. We do not share your images with third parties or use them to train shared models."
        ),
        FAQArticle(
            question: "How do I download my generated images?",
            answer: "On the Results screen, tap any image and use the share button to save it to your Photos library or share it directly. All generated images remain accessible in your persona's history."
        ),
        FAQArticle(
            question: "What if I'm not happy with the results?",
            answer: "Results depend on photo quality. For best output, ensure your training photos are sharp, well-lit, and show your face clearly. If you consistently get poor results, try a new persona with higher quality photos."
        ),
        FAQArticle(
            question: "How do I contact support?",
            answer: "Switch to the Chat tab to start a live conversation with our team, or email us at support@sellface.app. We typically respond within a few hours."
        ),
    ]
}
