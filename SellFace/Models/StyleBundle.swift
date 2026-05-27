import Foundation

struct StyleBundle: Identifiable, Codable {
    var id: String
    var name: String
    var description: String
    var tagline: String          // short hook shown in first-purchase state
    var productId: String
    var price: String            // always from StoreKit displayPrice
    var oldPrice: String?        // only set when Apple price < regularPrice
    var previewImageName: String
    var isUnlocked: Bool
    var previewImageUrl: String? // first generated image URL, set after results load

    // MARK: - Static metadata
    struct Metadata {
        let id: String
        let description: String
        let tagline: String
        let productId: String
        let previewImageName: String
        let regularPrice: String?
    }

    static let staticMetadata: [Metadata] = [
        Metadata(id: "professional", description: "Sharp business headshots",    tagline: "Perfect for corporate profiles",  productId: ProductID.professional, previewImageName: "briefcase.fill",           regularPrice: "9.99"),
        Metadata(id: "casual",       description: "Relaxed everyday looks",      tagline: "Great for social media",          productId: ProductID.casual,       previewImageName: "figure.walk",              regularPrice: "9.99"),
        Metadata(id: "executive",    description: "C-suite authority looks",     tagline: "For C-suite & leadership",        productId: ProductID.executive,    previewImageName: "star.fill",                regularPrice: "9.99"),
        Metadata(id: "creator",      description: "Standout creator content",    tagline: "Stand out as a creator",          productId: ProductID.creator,      previewImageName: "video.fill",               regularPrice: "9.99"),
        Metadata(id: "linkedin",     description: "Profile-ready portraits",     tagline: "Perfect for LinkedIn",            productId: ProductID.linkedin,     previewImageName: "person.crop.square.fill",  regularPrice: "9.99"),
        Metadata(id: "oldmoney",     description: "Classic aristocratic vibes",  tagline: "Timeless aristocratic look",      productId: ProductID.oldMoney,     previewImageName: "crown.fill",               regularPrice: "9.99"),
        Metadata(id: "sales",        description: "High-trust, high-conversion", tagline: "High-trust, high-conversion",     productId: ProductID.sales,        previewImageName: "chart.line.uptrend.xyaxis",regularPrice: "9.99"),
        Metadata(id: "studio",       description: "Premium studio lighting",     tagline: "Premium studio quality",          productId: ProductID.studio,       previewImageName: "camera.fill",              regularPrice: "9.99"),
    ]
}
