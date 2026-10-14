import CoreGraphics
import Foundation
import ImageIO
#if canImport(UIKit) && canImport(PhotosUI) && canImport(SwiftUI)
import PhotosUI
import SwiftUI
import UIKit

/// PhotosPicker wrapper that loads a `CGImage` with EXIF orientation applied.
public struct PhotoImportBridge: View {
    @Binding public var selection: PhotosPickerItem?
    public var onResult: (Result<CGImage, PhotoImportError>) -> Void

    public init(
        selection: Binding<PhotosPickerItem?>,
        onResult: @escaping (Result<CGImage, PhotoImportError>) -> Void
    ) {
        _selection = selection
        self.onResult = onResult
    }

    public var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            EmptyView()
        }
        .onChange(of: selection) { _, newItem in
            guard let newItem else { return }
            Task {
                await load(item: newItem)
            }
        }
    }

    private func load(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            onResult(.failure(.loadFailed))
            return
        }
        guard let image = Self.makeCGImage(from: data) else {
            onResult(.failure(.notAnImage))
            return
        }
        onResult(.success(image))
    }

    static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 12_000,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
#endif
