import ImageIO
import UniformTypeIdentifiers
import XCTest

/// Captures the App Store screenshots: the five key screens, started from fixture bills (`--uitesting`, `--fixture`,
/// `--start-at`), in Spanish (Puerto Rico) light, English light and Spanish dark. No fastlane, no extra tools.
///
/// These tests do nothing in the normal test plan: they skip themselves unless `STORE_SCREENSHOTS=1` is in the test
/// environment. The manual "Store screenshots" workflow (`.github/workflows/store-screenshots.yml`) sets it, runs
/// them on a simulator with a clean status bar, and `Scripts/export-store-screenshots.sh` turns the attachments of the
/// result bundle into `<language>-<appearance>-<number>-<screen>.png` files. See `docs/store/README.md`.
///
/// Every screenshot is the whole screen (status bar included) and is attached under its final file name.
final class StoreScreenshotTests: XCTestCase {
    private struct Shot {
        let name: String
        let fixture: String?
        let startAt: String?
        /// What to wait for before the picture is taken.
        let readyIdentifier: String
        /// Tapped (and waited on) after the screen is ready, to reach a sheet.
        let opens: (tap: String, ready: String)?
    }

    /// The five key screens. `midway` leaves two items unmarked, so the marking screen shows the progress;
    /// `complete` is the finished split the totals and the share summary are made from.
    private static let shots = [
        Shot(name: "01-home", fixture: nil, startAt: nil, readyIdentifier: "screen.home", opens: nil),
        Shot(name: "02-review", fixture: "scanned", startAt: "review", readyIdentifier: "screen.review", opens: nil),
        Shot(name: "03-mark", fixture: "midway", startAt: "mark", readyIdentifier: "screen.mark", opens: nil),
        Shot(name: "04-totals", fixture: "complete", startAt: "totals", readyIdentifier: "totals.banner", opens: nil),
        Shot(name: "05-share", fixture: "complete", startAt: "totals", readyIdentifier: "totals.share", opens: (tap: "totals.share", ready: "share.sheet")),
    ]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SCREENSHOTS"] == "1", "set STORE_SCREENSHOTS=1 to capture the App Store screenshots")
        continueAfterFailure = false
    }

    @MainActor func testSpanishLight() {
        capture(language: "es", region: "PR", dark: false)
    }

    @MainActor func testEnglishLight() {
        capture(language: "en", region: "US", dark: false)
    }

    @MainActor func testSpanishDark() {
        capture(language: "es", region: "PR", dark: true)
    }

    // MARK: Capturing

    @MainActor
    private func capture(language: String, region: String, dark: Bool) {
        let appearance = dark ? "dark" : "light"
        for shot in Self.shots {
            let app = XCUIApplication()
            var arguments = ["--uitesting"]
            if let fixture = shot.fixture { arguments.append("--fixture=\(fixture)") }
            if let startAt = shot.startAt { arguments.append("--start-at=\(startAt)") }
            arguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", "\(language)_\(region)"]
            if dark { arguments += ["-AppleInterfaceStyle", "Dark"] }
            app.launchArguments += arguments
            app.launch()

            XCTAssertTrue(element(app, shot.readyIdentifier).waitForExistence(timeout: 20), "\(shot.name): \(shot.readyIdentifier) never appeared")
            if let opens = shot.opens {
                let trigger = element(app, opens.tap)
                XCTAssertTrue(trigger.isHittable || trigger.waitForExistence(timeout: 5), "\(shot.name): \(opens.tap) is not there")
                trigger.tap()
                XCTAssertTrue(element(app, opens.ready).waitForExistence(timeout: 10), "\(shot.name): \(opens.ready) never appeared")
            }
            settle()
            attach(XCUIScreen.main.screenshot(), named: "\(language)-\(appearance)-\(shot.name)")
            app.terminate()
        }
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    /// Lets transitions, sheets and the keyboard-less layout finish before the picture.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// App Store Connect rejects images with an alpha channel, so the picture is redrawn into an opaque RGB bitmap and
    /// attached as PNG (the default attachment format for screenshots is a lossy HEIC, and the simulator's own PNG
    /// carries an alpha channel).
    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        guard let png = Self.opaquePNG(from: screenshot.pngRepresentation) else {
            XCTFail("\(name): could not make an opaque PNG")
            return
        }
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: UTType.png.identifier)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func opaquePNG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let output = NSMutableData()
        guard let flat = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, flat, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
