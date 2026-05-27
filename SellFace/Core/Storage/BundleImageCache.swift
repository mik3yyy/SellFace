import UIKit

/// Two-layer cache for bundle preview images.
/// Layer 1: in-memory dict (instant, cleared on app kill)
/// Layer 2: Caches directory on disk (persists across launches)
final class BundleImageCache {
    static let shared = BundleImageCache()

    private var memory: [String: (url: String, image: UIImage)] = [:]
    private let dir: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("SFBundlePreviews", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func get(personaId: String, productId: String) -> (url: String, image: UIImage)? {
        let key = "\(personaId)__\(productId)"

        if let hit = memory[key] { return hit }

        let urlFile   = dir.appendingPathComponent("\(key).url")
        let imageFile = dir.appendingPathComponent("\(key).jpg")
        guard let url   = try? String(contentsOf: urlFile, encoding: .utf8),
              let data  = try? Data(contentsOf: imageFile),
              let image = UIImage(data: data) else { return nil }

        let hit = (url: url, image: image)
        memory[key] = hit
        return hit
    }

    func store(personaId: String, productId: String, url: String, image: UIImage) {
        let key = "\(personaId)__\(productId)"
        memory[key] = (url: url, image: image)

        let urlFile   = dir.appendingPathComponent("\(key).url")
        let imageFile = dir.appendingPathComponent("\(key).jpg")
        Task.detached(priority: .background) {
            try? url.write(to: urlFile, atomically: true, encoding: .utf8)
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: imageFile, options: .atomic)
            }
        }
    }

    // MARK: - Full results set (multiple images per bundle)

    private var resultsMemory: [String: [UIImage]] = [:]

    func getResults(personaId: String, productId: String) -> [UIImage]? {
        let key = "\(personaId)__\(productId)"
        if let hit = resultsMemory[key] { return hit }

        let countFile = dir.appendingPathComponent("results_\(key).count")
        guard let countStr = try? String(contentsOf: countFile, encoding: .utf8),
              let count = Int(countStr), count > 0 else { return nil }

        var images: [UIImage] = []
        for i in 0..<count {
            let imageFile = dir.appendingPathComponent("results_\(key)_\(i).jpg")
            guard let data = try? Data(contentsOf: imageFile),
                  let image = UIImage(data: data) else { return nil }
            images.append(image)
        }
        resultsMemory[key] = images
        return images
    }

    func storeResults(personaId: String, productId: String, images: [UIImage]) {
        let key = "\(personaId)__\(productId)"
        resultsMemory[key] = images
        let dir = self.dir
        Task.detached(priority: .background) {
            let countFile = dir.appendingPathComponent("results_\(key).count")
            try? "\(images.count)".write(to: countFile, atomically: true, encoding: .utf8)
            for (i, image) in images.enumerated() {
                let imageFile = dir.appendingPathComponent("results_\(key)_\(i).jpg")
                if let data = image.jpegData(compressionQuality: 0.85) {
                    try? data.write(to: imageFile, options: .atomic)
                }
            }
        }
    }
}
