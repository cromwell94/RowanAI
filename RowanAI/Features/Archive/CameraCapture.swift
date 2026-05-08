import SwiftUI
import UIKit

// MARK: - Camera Capture (UIImagePickerController bridge)
// PhotosPicker handles the photo library; the camera path needs the older
// UIImagePickerController. Wrapped here so SwiftUI sheets can present it
// the same way they present a PhotosPicker.

struct CameraCaptureSheet: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Only present this sheet when the camera is available — caller checks.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage) -> Void
        let onCancel: () -> Void
        init(onPicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPicked = onPicked; self.onCancel = onCancel
        }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onPicked(image)
            } else {
                onCancel()
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}

extension UIImagePickerController {
    static var hasCamera: Bool { isSourceTypeAvailable(.camera) }
}
