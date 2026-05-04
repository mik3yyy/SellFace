import Foundation

enum ProductID {
    static let professional = "com.sellface.style.professional"
    static let casual = "com.sellface.style.casual"
    static let executive = "com.sellface.style.executive"
    static let creator = "com.sellface.style.creator"
    static let linkedin = "com.sellface.style.linkedin"
    static let sales = "com.sellface.style.sales"
    static let oldMoney = "com.sellface.style.oldmoney"
    static let studio = "com.sellface.style.studio"
    static let twoStylesBundle = "com.sellface.bundle.two_styles"
    static let allAccess = "com.sellface.bundle.all_access"

    static let all: Set<String> = [
        professional, casual, executive, creator,
        linkedin, sales, oldMoney, studio,
        twoStylesBundle, allAccess,
    ]
}
