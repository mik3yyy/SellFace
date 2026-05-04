import Foundation

struct StyleBundle: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var productId: String
    var price: String
    var oldPrice: String?
    var previewImageName: String
    var isUnlocked: Bool

    static let mockBundles: [StyleBundle] = [
        StyleBundle(id: "professional", name: "Professional", description: "Sharp business headshots", productId: ProductID.professional, price: "£2.99", oldPrice: "£9.99", previewImageName: "briefcase.fill", isUnlocked: false),
        StyleBundle(id: "casual", name: "Casual", description: "Relaxed everyday looks", productId: ProductID.casual, price: "£2.99", oldPrice: "£9.99", previewImageName: "figure.walk", isUnlocked: false),
        StyleBundle(id: "executive", name: "Executive", description: "C-suite authority looks", productId: ProductID.executive, price: "£2.99", oldPrice: "£9.99", previewImageName: "star.fill", isUnlocked: false),
        StyleBundle(id: "creator", name: "Creator", description: "Standout creator content", productId: ProductID.creator, price: "£2.99", oldPrice: "£9.99", previewImageName: "video.fill", isUnlocked: false),
        StyleBundle(id: "linkedin", name: "LinkedIn", description: "Profile-ready portraits", productId: ProductID.linkedin, price: "£2.99", oldPrice: "£9.99", previewImageName: "person.crop.square.fill", isUnlocked: false),
        StyleBundle(id: "oldmoney", name: "Old Money", description: "Classic aristocratic vibes", productId: ProductID.oldMoney, price: "£2.99", oldPrice: "£9.99", previewImageName: "crown.fill", isUnlocked: false),
        StyleBundle(id: "sales", name: "Sales", description: "High-trust, high-conversion", productId: ProductID.sales, price: "£2.99", oldPrice: "£9.99", previewImageName: "chart.line.uptrend.xyaxis", isUnlocked: false),
        StyleBundle(id: "studio", name: "Studio", description: "Premium studio lighting", productId: ProductID.studio, price: "£2.99", oldPrice: "£9.99", previewImageName: "camera.fill", isUnlocked: false),
    ]
}
