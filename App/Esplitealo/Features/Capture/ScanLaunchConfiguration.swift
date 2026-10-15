#if DEBUG
import CoreGraphics
import EsplitealoCapture
import EsplitealoCore
import Foundation

/// Debug-only launch arguments that let UI tests run the capture flow on a simulator without a camera. They are
/// compiled out of release builds, so a shipped app never reads a file named on its command line.
///
/// - `--uitesting-recognized-text <path>`: JSON of a `RecognizedText` (the committed real-receipt fixtures). Instead
///   of the camera or photo picker, the flow reads a blank image and parses this text with the real `ReceiptParser`.
/// - `--uitesting-camera authorized|denied|restricted|notDetermined|unsupported`: the camera permission to act on.
/// - `--uitesting-scan-failure unreadable|tooManyPages|tooLong|photoNotLoaded|cameraFailed`: the first attempt fails
///   with it; "try again" then works.
/// - `--uitesting-scan-delay <seconds>`: how long reading takes, to see the processing screen.
struct ScanLaunchConfiguration {
    struct FixtureFileError: Error { let path: String }

    private var recognizedTextPath: String?
    private var camera: CameraBehavior?
    private var failure: ScanFailure?
    private var delay: Duration = .zero

    private enum CameraBehavior {
        case status(CameraPermissionStatus)
        case unsupported
    }

    /// `nil` when none of the arguments is present (or its word is not one we know).
    init?(arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        recognizedTextPath = value(after: "--uitesting-recognized-text")
        camera = value(after: "--uitesting-camera").flatMap(Self.cameraBehavior)
        failure = value(after: "--uitesting-scan-failure").flatMap(Self.scanFailure)
        if let seconds = value(after: "--uitesting-scan-delay").flatMap(Double.init) {
            delay = .milliseconds(Int(seconds * 1000))
        }
        guard recognizedTextPath != nil || camera != nil || failure != nil || delay > .zero else { return nil }
    }

    private static func cameraBehavior(_ word: String) -> CameraBehavior? {
        switch word {
        case "authorized": .status(.authorized)
        case "denied": .status(.denied)
        case "restricted": .status(.restricted)
        case "notDetermined": .status(.notDetermined)
        case "unsupported": .unsupported
        default: nil
        }
    }

    private static func scanFailure(_ word: String) -> ScanFailure? {
        switch word {
        case "unreadable": .unreadable
        case "tooManyPages": .tooManyPages
        case "tooLong": .tooLong
        case "photoNotLoaded": .photoNotLoaded
        case "cameraFailed": .cameraFailed
        default: nil
        }
    }

    /// The services to run with. Throws when the fixture file cannot be read, so a typo fails loudly.
    func services() throws -> ScanFlow.Services {
        var services = ScanFlow.Services.live
        let delay = delay

        if let recognizedTextPath {
            guard let data = FileManager.default.contents(atPath: recognizedTextPath) else {
                throw FixtureFileError(path: recognizedTextPath)
            }
            let recognized = try JSONDecoder().decode(RecognizedText.self, from: data)
            services.scan = { _ in
                try await Task.sleep(for: delay)
                return ReceiptParser().parse(recognized)
            }
        } else if delay > .zero {
            let live = services.scan
            services.scan = { image in
                try await Task.sleep(for: delay)
                return try await live(image)
            }
        }

        switch camera {
        case .status(let status):
            services.cameraStatus = { status }
            // A user who is asked says yes, so "notDetermined" walks the grant path.
            services.requestCameraAccess = { .authorized }
        case .unsupported:
            services.isCameraSupported = { false }
        case nil:
            // The simulator has no camera; with a fixture the camera is assumed to work.
            if recognizedTextPath != nil || failure != nil {
                services.cameraStatus = { .authorized }
                services.isCameraSupported = { true }
            }
        }

        if recognizedTextPath != nil || failure != nil {
            services.fixture = .init(image: Self.blankImage, failsFirstWith: failure)
        }
        return services
    }

    /// The fixture never looks at pixels; the scan closure ignores the image.
    private static var blankImage: CGImage {
        let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }
}
#endif
