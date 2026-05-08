import SwiftUI
import UIKit

struct ReceiptScannerView: UIViewControllerRepresentable {
    enum Source {
        case camera
        case photoLibrary

        var pickerSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
            case .photoLibrary:
                return .photoLibrary
            }
        }
    }

    let source: Source
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = source.pickerSourceType
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ReceiptScannerView

        init(parent: ReceiptScannerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
