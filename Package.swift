// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EsplitealoCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "EsplitealoCore", targets: ["EsplitealoCore"]),
        .library(name: "EsplitealoScanning", targets: ["EsplitealoScanning"]),
        .library(name: "EsplitealoCapture", targets: ["EsplitealoCapture"]),
        .library(name: "OCRBenchmarkKit", targets: ["OCRBenchmarkKit"]),
        .executable(name: "EsplitealoOCRBenchmark", targets: ["EsplitealoOCRBenchmark"]),
        .library(name: "ScannerLabKit", targets: ["ScannerLabKit"]),
        .library(name: "EsplitealoDesign", targets: ["EsplitealoDesign"]),
    ],
    targets: [
        // Pure bill logic: models, receipt parsing, bill session, calculator.
        // Foundation only, so it stays portable (Linux, and Android later).
        .target(name: "EsplitealoCore"),
        // Apple-only scanning: Vision OCR, CoreGraphics and ImageIO image handling.
        .target(name: "EsplitealoScanning", dependencies: ["EsplitealoCore"]),
        .target(name: "EsplitealoCapture", dependencies: ["EsplitealoCore"]),
        // Developer-only OCR benchmark; the app never links it.
        .target(
            name: "OCRBenchmarkKit",
            dependencies: ["EsplitealoCore", "EsplitealoScanning"]
        ),
        .executableTarget(
            name: "EsplitealoOCRBenchmark",
            dependencies: ["EsplitealoCore", "EsplitealoScanning", "OCRBenchmarkKit"]
        ),
        .target(
            name: "ScannerLabKit",
            dependencies: ["EsplitealoCore", "EsplitealoScanning"]
        ),
        // Chavito mascot artwork (SwiftUI, Apple-only); depends on nothing else in the package.
        .target(name: "EsplitealoDesign"),
        // Shared helpers for test targets (not a product).
        .target(
            name: "EsplitealoTestSupport",
            dependencies: ["EsplitealoCore"],
            path: "Tests/EsplitealoTestSupport"
        ),
        .testTarget(
            name: "EsplitealoCoreTests",
            dependencies: ["EsplitealoCore", "EsplitealoTestSupport"]
        ),
        .testTarget(
            name: "EsplitealoScanningTests",
            dependencies: ["EsplitealoCore", "EsplitealoScanning"]
        ),
        .testTarget(
            name: "OCRBenchmarkKitTests",
            dependencies: ["EsplitealoCore", "OCRBenchmarkKit", "EsplitealoTestSupport"]
        ),
        .testTarget(
            name: "EsplitealoCaptureTests",
            dependencies: ["EsplitealoCapture"]
        ),
        .testTarget(
            name: "ScannerLabKitTests",
            dependencies: ["ScannerLabKit"]
        ),
        .testTarget(
            name: "EsplitealoDesignTests",
            dependencies: ["EsplitealoDesign"]
        ),
    ]
)
