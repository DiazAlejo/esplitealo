import Foundation

public enum DocumentCameraError: Error, Equatable, Sendable {
    case cancelled
    case noImage
    case tooManyPages
    case failed(String)

    static func validatePageCount(_ pageCount: Int) -> DocumentCameraError? {
        if pageCount < 1 { return .noImage }
        if pageCount > 1 { return .tooManyPages }
        return nil
    }
}

public enum PhotoImportError: Error, Equatable, Sendable {
    case loadFailed
    case notAnImage
}
