import CoreText
import Foundation

/// Unkempt ships inside this module (unmodified TTFs plus both licence texts) and is registered for the process at
/// launch, so neither the app's Info.plist nor package tests need `UIAppFonts`.
public enum DesignFonts {
    private static let fontNames = ["Unkempt-Regular", "Unkempt-Bold"]

    private static func resourceURLs(withExtension ext: String) -> [URL] {
        let urls = Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public static func fontURLs() -> [URL] { resourceURLs(withExtension: "ttf") }

    public static func licenseURLs() -> [URL] { resourceURLs(withExtension: "txt") }

    private static let registration: Void = {
        CTFontManagerRegisterFontURLs(fontURLs() as CFArray, .process, true, nil)
    }()

    /// Safe to call any number of times.
    public static func registerAll() {
        _ = registration
    }
}
