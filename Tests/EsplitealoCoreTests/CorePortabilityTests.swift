import Foundation
import XCTest

/// EsplitealoCore must stay Foundation-only so it can build on Linux and, later, Android.
/// Apple-only frameworks belong in EsplitealoScanning, EsplitealoCapture or the app.
final class CorePortabilityTests: XCTestCase {
    private let coreSources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/EsplitealoCore", isDirectory: true)

    func testCoreSourcesImportOnlyFoundation() throws {
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(at: coreSources, includingPropertiesForKeys: nil)
        )
        var checked = 0
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            checked += 1
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") {
                let words = line.split(separator: " ")
                guard let importIndex = words.firstIndex(of: "import"), words.prefix(importIndex).allSatisfy({ $0.hasPrefix("@") }) else { continue }
                guard importIndex + 1 < words.count else { continue }
                XCTAssertEqual(
                    words[importIndex + 1],
                    "Foundation",
                    "\(file.lastPathComponent) imports \(words[importIndex + 1]); Core must be Foundation-only"
                )
            }
        }
        XCTAssertGreaterThan(checked, 10, "expected to find the Core sources at \(coreSources.path)")
    }
}
