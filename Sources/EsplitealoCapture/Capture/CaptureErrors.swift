import Foundation

public enum DocumentCameraError: Error, Equatable, Sendable {
    case cancelled
    case noImage
    case tooManyPages
    case failed(String)

    public var labMessage: String {
        switch self {
        case .cancelled:
            return "Document scan cancelled."
        case .noImage:
            return "No image was captured."
        case .tooManyPages:
            return "Only one receipt page is supported; scan was rejected."
        case .failed(let detail):
            return "Document camera failed: \(detail)"
        }
    }

    static func validatePageCount(_ pageCount: Int) -> DocumentCameraError? {
        if pageCount < 1 { return .noImage }
        if pageCount > 1 { return .tooManyPages }
        return nil
    }
}

public enum PhotoImportError: Error, Equatable, Sendable {
    case loadFailed
    case notAnImage

    public var labMessage: String {
        switch self {
        case .loadFailed:
            return "Could not load the selected photo."
        case .notAnImage:
            return "The selected file is not a supported image."
        }
    }
}
