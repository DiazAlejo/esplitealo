// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EsplitealoCore",
    products: [
        .library(name: "EsplitealoCore", targets: ["EsplitealoCore"]),
    ],
    targets: [
        .target(name: "EsplitealoCore"),
        .testTarget(name: "EsplitealoCoreTests", dependencies: ["EsplitealoCore"]),
    ]
)
