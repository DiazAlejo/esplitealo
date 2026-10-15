import Foundation

/// Locates the app's text resources (string catalogs, privacy manifest, xcconfig files) from the repository root,
/// so `swift test` can check them without building the Xcode project.
enum AppFiles {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AppResourceTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repository root

    static let app = root.appendingPathComponent("App", isDirectory: true)
    static let sources = app.appendingPathComponent("Esplitealo", isDirectory: true)
    static let resources = sources.appendingPathComponent("Resources", isDirectory: true)
    static let config = app.appendingPathComponent("Config", isDirectory: true)

    static var localizable: URL { resources.appendingPathComponent("Localizable.xcstrings") }
    static var infoPlistStrings: URL { resources.appendingPathComponent("InfoPlist.xcstrings") }
    static var privacyManifest: URL { resources.appendingPathComponent("PrivacyInfo.xcprivacy") }
    static var project: URL { app.appendingPathComponent("Esplitealo.xcodeproj/project.pbxproj") }

    static func text(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Every file below `directory` whose name ends with one of the extensions.
    static func files(in directory: URL, extensions: Set<String>) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { $0 as? URL }
            .filter { extensions.contains($0.pathExtension) }
            .sorted { $0.path < $1.path }
    }
}
