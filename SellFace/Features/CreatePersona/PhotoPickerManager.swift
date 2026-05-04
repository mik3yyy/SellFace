import UIKit
import PhotosUI

protocol PhotoPickerManagerDelegate: AnyObject {
    func photoPickerManager(_ manager: PhotoPickerManager, didSelect images: [UIImage])
    func photoPickerManagerDidCancel(_ manager: PhotoPickerManager)
}

@MainActor
final class PhotoPickerManager: NSObject {
    weak var delegate: PhotoPickerManagerDelegate?
    weak var presentingViewController: UIViewController?

    private let minCount = 10
    private let maxCount = 15

    func present(from viewController: UIViewController) {
        presentingViewController = viewController
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = maxCount
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    private func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }
}

extension PhotoPickerManager: PHPickerViewControllerDelegate {
    nonisolated func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        Task { @MainActor in
            picker.dismiss(animated: true)
            guard !results.isEmpty else {
                self.delegate?.photoPickerManagerDidCancel(self)
                return
            }

            var images: [UIImage] = []
            for result in results {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                if let image = await self.loadImage(from: result.itemProvider) {
                    images.append(image)
                }
            }

            if images.count < self.minCount {
                self.showCountError(from: self.presentingViewController)
            } else {
                self.delegate?.photoPickerManager(self, didSelect: Array(images.prefix(self.maxCount)))
            }
        }
    }

    private func showCountError(from vc: UIViewController?) {
        guard let vc else { return }
        let alert = UIAlertController(
            title: "Not Enough Photos",
            message: "Please select at least \(minCount) photos for best results.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc.present(alert, animated: true)
        delegate?.photoPickerManagerDidCancel(self)
    }
}
