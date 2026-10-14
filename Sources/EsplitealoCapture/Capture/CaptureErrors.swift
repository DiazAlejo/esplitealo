import Foundation

public enum DocumentCameraError: Error, Equatable, Sendable {
    case cancelled
    case noImage
    case failed(String)
}

public enum PhotoImportError: Error, Equatable, Sendable {
    case loadFailed
    case notAnImage
}
