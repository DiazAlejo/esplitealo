// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EsplitealoCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "EsplitealoCore", targets: ["EsplitealoCore"]),
        .library(name: "EsplitealoCapture", targets: ["EsplitealoCapture"]),
    ],
    targets: [
        .target(name: "EsplitealoCore"),
        .target(name: "EsplitealoCapture", dependencies: ["EsplitealoCore"]),
        .testTarget(name: "EsplitealoCoreTests", dependencies: ["EsplitealoCore"]),
        .testTarget(
            name: "EsplitealoCaptureTests",
            dependencies: ["EsplitealoCapture"]
        ),
    ]
)
