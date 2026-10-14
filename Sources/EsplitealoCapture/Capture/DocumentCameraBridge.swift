import CoreGraphics
import Foundation

#if canImport(UIKit) && canImport(VisionKit)
import SwiftUI
import UIKit
import VisionKit

/// One-page VisionKit document camera; returns a flattened `CGImage` or a typed error.
public struct DocumentCameraBridge: UIViewControllerRepresentable {
    public var onResult: (Result<CGImage, DocumentCameraError>) -> Void

    public init(onResult: @escaping (Result<CGImage, DocumentCameraError>) -> Void) {
        self.onResult = onResult
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    public final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onResult: (Result<CGImage, DocumentCameraError>) -> Void

        init(onResult: @escaping (Result<CGImage, DocumentCameraError>) -> Void) {
            self.onResult = onResult
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onResult(.failure(.cancelled))
        }

        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onResult(.failure(.failed(error.localizedDescription)))
        }

        public func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount > 0 else {
                onResult(.failure(.noImage))
                return
            }
            // MVP: one photo per bill — use the first page only.
            let uiImage = scan.imageOfPage(at: 0)
            guard let cgImage = uiImage.cgImage else {
                onResult(.failure(.noImage))
                return
            }
            onResult(.success(cgImage))
        }
    }
}
#endif
