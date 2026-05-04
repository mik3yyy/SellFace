import UIKit

enum SFColors {

    // MARK: - Backgrounds (deep navy-black → elevated layers)
    static let background       = UIColor(hex: "#07070F")   // near-black with slight cool tint
    static let cardBackground   = UIColor(hex: "#11111C")   // card surface
    static let secondaryBackground = UIColor(hex: "#1C1C2C") // elevated
    static let tertiaryBackground  = UIColor(hex: "#26263A") // input fields, chips

    // MARK: - Labels (warm whites)
    static let label            = UIColor(hex: "#F0EAE0")   // warm off-white
    static let secondaryLabel   = UIColor(hex: "#8A8898")   // muted warm gray
    static let tertiaryLabel    = UIColor(hex: "#52515F")   // very muted

    // MARK: - Accent (champagne gold)
    static let accent           = UIColor(hex: "#C8A86A")   // main gold
    static let accentLight      = UIColor(hex: "#C8A86A").withAlphaComponent(0.13)
    static let accentSubtle     = UIColor(hex: "#C8A86A").withAlphaComponent(0.06)

    // MARK: - Status
    static let success          = UIColor(hex: "#4EB87A")
    static let warning          = UIColor(hex: "#E0923E")
    static let destructive      = UIColor(hex: "#D95252")

    // MARK: - Structural
    static let separator        = UIColor(hex: "#C8A86A").withAlphaComponent(0.10)
    static let cardBorder       = UIColor(hex: "#C8A86A").withAlphaComponent(0.08)
    static let cardShadow       = UIColor.black.withAlphaComponent(0.55)

    // MARK: - Price
    static let livePrice        = UIColor(hex: "#C8A86A")
    static let strikethroughPrice = UIColor(hex: "#52515F")
}

// MARK: - Hex initialiser
extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8)  & 0xFF) / 255
        let b = CGFloat( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
