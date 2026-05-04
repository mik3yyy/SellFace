import UIKit

enum SFTypography {

    // MARK: - Display (SF Pro Rounded — used for hero titles and key headings)
    static func largeTitle() -> UIFont  { rounded(size: 32, weight: .bold) }
    static func title1() -> UIFont      { rounded(size: 26, weight: .bold) }
    static func title2() -> UIFont      { rounded(size: 21, weight: .semibold) }
    static func title3() -> UIFont      { rounded(size: 18, weight: .semibold) }

    // MARK: - Text (SF Pro — used for body and captions)
    static func headline() -> UIFont    { .systemFont(ofSize: 16, weight: .semibold) }
    static func body() -> UIFont        { .systemFont(ofSize: 16, weight: .regular) }
    static func callout() -> UIFont     { .systemFont(ofSize: 15, weight: .regular) }
    static func subheadline() -> UIFont     { .systemFont(ofSize: 14, weight: .regular) }
    static func subheadlineBold() -> UIFont { .systemFont(ofSize: 14, weight: .semibold) }
    static func footnote() -> UIFont    { .systemFont(ofSize: 13, weight: .regular) }
    static func caption() -> UIFont     { .systemFont(ofSize: 12, weight: .regular) }
    static func captionMedium() -> UIFont { rounded(size: 11, weight: .medium) }

    // MARK: - Price
    static func price() -> UIFont       { rounded(size: 14, weight: .bold) }
    static func strikePrice() -> UIFont { .systemFont(ofSize: 12, weight: .regular) }

    // MARK: - Private helper
    private static func rounded(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}

// MARK: - Tracked attributed string helper
extension UILabel {
    /// Apply letter-spacing (tracking) in points. Call after setting font.
    func setTracking(_ tracking: CGFloat) {
        guard let text else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font as Any,
            .foregroundColor: textColor as Any,
            .kern: tracking
        ]
        attributedText = NSAttributedString(string: text, attributes: attrs)
    }
}
