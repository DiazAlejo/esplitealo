import CoreGraphics
import EsplitealoCapture
import EsplitealoCore
import ImageIO
import PhotosUI
import ScannerLabKit
import SwiftUI
import UIKit

@MainActor
final class LabScreenState: ObservableObject {
    @Published var thumbnail: UIImage?
    @Published var display: ScanLabDisplayResult?
    @Published var errorMessage: String?
    @Published var isProcessing = false
    @Published var showDocumentCamera = false
    @Published var photoPickerItem: PhotosPickerItem?
    @Published var copyConfirmation = false

    private var lastResult: ReceiptScanResult?
    private let runner = ScanLabPipelineRunner()

    func scanWithDocumentCameraTapped() async {
        let status = await CameraPermission.requestAccessIfNeeded()
        guard status == .authorized else {
            errorMessage = "Camera access is required to scan receipts."
            return
        }
        showDocumentCamera = true
    }

    func handleDocumentCameraResult(_ result: Result<CGImage, DocumentCameraError>) {
        showDocumentCamera = false
        switch result {
        case .success(let image):
            Task { await process(image: image) }
        case .failure(let error):
            if error != .cancelled {
                errorMessage = error.labMessage
            }
        }
    }

    func handlePhotoImportResult(_ result: Result<CGImage, PhotoImportError>) {
        switch result {
        case .success(let image):
            Task { await process(image: image) }
        case .failure(let error):
            errorMessage = error.labMessage
        }
    }

    func loadPhotoItem(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = PhotoImportError.loadFailed.labMessage
            return
        }
        guard let image = Self.makeCGImage(from: data) else {
            errorMessage = PhotoImportError.notAnImage.labMessage
            return
        }
        await process(image: image)
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 12_000,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    func process(image: CGImage) async {
        isProcessing = true
        errorMessage = nil
        copyConfirmation = false
        defer { isProcessing = false }

        thumbnail = UIImage(cgImage: image)
        do {
            let outcome = try await runner.run(image: image)
            lastResult = outcome.result
            display = ScanLabResultBuilder.display(
                from: outcome.result,
                ocrDurationMilliseconds: outcome.ocrDurationMilliseconds
            )
        } catch {
            display = nil
            lastResult = nil
            errorMessage = ScanLabErrorMessages.message(for: error)
        }
    }

    func fullResultJSON() throws -> Data {
        guard let lastResult, let display else {
            throw ExportError.nothingToExport
        }
        return try ScanLabJSONExport.encodeFullResult(
            lastResult,
            ocrDurationMilliseconds: display.ocrDurationMilliseconds
        )
    }

    func recognizedTextJSON() throws -> Data {
        guard let lastResult else {
            throw ExportError.nothingToExport
        }
        return try ScanLabJSONExport.encodeRecognizedText(lastResult.recognizedText)
    }

    func copyFullResultJSON() {
        do {
            let data = try fullResultJSON()
            UIPasteboard.general.string = String(data: data, encoding: .utf8)
            copyConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    enum ExportError: LocalizedError {
        case nothingToExport

        var errorDescription: String? {
            switch self {
            case .nothingToExport:
                return "Scan a receipt before exporting."
            }
        }
    }
}
