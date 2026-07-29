import SwiftUI
import UIKit

enum ProfileAvatarStore {
    private static let maximumPixelSize: CGFloat = 512
    private static let jpegQuality: CGFloat = 0.84

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: avatarURL) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func save(_ image: UIImage) throws -> UIImage {
        let processedImage = squareImage(from: image)
        guard let data = processedImage.jpegData(compressionQuality: jpegQuality) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        let directory = avatarURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: avatarURL, options: .atomic)
        return processedImage
    }

    static func delete() throws {
        guard FileManager.default.fileExists(atPath: avatarURL.path) else { return }
        try FileManager.default.removeItem(at: avatarURL)
    }

    private static var avatarURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("avatar.jpg")
    }

    private static func squareImage(from image: UIImage) -> UIImage {
        let outputSize = CGSize(width: maximumPixelSize, height: maximumPixelSize)
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return image }

        let scale = max(
            outputSize.width / imageSize.width,
            outputSize.height / imageSize.height
        )
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let drawRect = CGRect(
            x: (outputSize.width - scaledSize.width) / 2,
            y: (outputSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: outputSize))
            image.draw(in: drawRect)
        }
    }
}

struct ProfileAvatarCameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ProfileAvatarCameraPicker

        init(parent: ProfileAvatarCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            if let image {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
    }
}
