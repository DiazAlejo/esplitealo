import Foundation
import Testing

/// Static checks of the app's text configuration (xcconfig files, privacy manifest, Info.plist strings, icon).
struct AppConfigurationTests {
    private func settings(_ name: String) throws -> [String: String] {
        var result: [String: String] = [:]
        for line in try AppFiles.text(AppFiles.config.appendingPathComponent(name)).split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), let equals = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    private func allConfigText() throws -> String {
        try AppFiles.files(in: AppFiles.config, extensions: ["xcconfig"]).map(AppFiles.text).joined(separator: "\n")
    }

    // MARK: Build settings

    @Test func sharedSettingsRequireIOS18AndSwift6() throws {
        let shared = try settings("Shared.xcconfig")
        #expect(shared["IPHONEOS_DEPLOYMENT_TARGET"] == "18.0")
        #expect(shared["SWIFT_VERSION"] == "6.0")
        #expect(shared["SWIFT_STRICT_CONCURRENCY"] == "complete")
    }

    @Test func appTargetIsMainActorByDefaultWithApproachableConcurrency() throws {
        let app = try settings("App.xcconfig")
        #expect(app["SWIFT_DEFAULT_ACTOR_ISOLATION"] == "MainActor")
        #expect(app["SWIFT_APPROACHABLE_CONCURRENCY"] == "YES")
    }

    @Test func bundleIdentifierIsOneSettingInOneXcconfig() throws {
        let shared = try settings("Shared.xcconfig")
        #expect(shared["APP_BUNDLE_IDENTIFIER"] == "com.esplitealo.app")
        let occurrences = try allConfigText().components(separatedBy: "com.esplitealo").count - 1
        #expect(occurrences == 1)
        #expect(try settings("App.xcconfig")["PRODUCT_BUNDLE_IDENTIFIER"] == "$(APP_BUNDLE_IDENTIFIER)")
        // The project file takes every value from the xcconfig files.
        #expect(!(try AppFiles.text(AppFiles.project)).contains("com.esplitealo"))
    }

    @Test func noTeamOrPersonalIdentifierIsCommitted() throws {
        let text = try allConfigText() + (try AppFiles.text(AppFiles.project))
        #expect(text.range(of: #"DEVELOPMENT_TEAM\s*=\s*"?[A-Z0-9]{10}"#, options: .regularExpression) == nil)
        #expect(!text.contains("@"))
        // A local, git-ignored file lets the owner set their personal team.
        #expect(try AppFiles.text(AppFiles.config.appendingPathComponent("Shared.xcconfig")).contains("#include? \"Local.xcconfig\""))
        let gitignore = try AppFiles.text(AppFiles.root.appendingPathComponent(".gitignore"))
        #expect(gitignore.contains("App/Config/Local.xcconfig"))
    }

    @Test func projectUsesSynchronizedFoldersAndSpanishDevelopmentRegion() throws {
        let project = try AppFiles.text(AppFiles.project)
        #expect(project.contains("PBXFileSystemSynchronizedRootGroup"))
        #expect(project.contains("developmentRegion = es;"))
        #expect(project.contains("XCLocalSwiftPackageReference"))
    }

    // MARK: Privacy

    @Test func privacyManifestDeclaresNoTrackingAndNoCollectedData() throws {
        let data = try Data(contentsOf: AppFiles.privacyManifest)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        #expect(plist["NSPrivacyAccessedAPITypes"] is [Any])
    }

    @Test func onlyTheCameraUsageStringIsDeclared() throws {
        let shared = try allConfigText()
        #expect(shared.contains("INFOPLIST_KEY_NSCameraUsageDescription"))
        #expect(!shared.contains("NSPhotoLibrary"))
        #expect(shared.contains("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO"))

        let catalog = try StringCatalog(contentsOf: AppFiles.infoPlistStrings)
        let keys = catalog.keys
        #expect(keys.contains("NSCameraUsageDescription"))
        #expect(!keys.contains { $0.hasPrefix("NSPhotoLibrary") })
        let camera = try #require(catalog.entries.first { $0.key == "NSCameraUsageDescription" })
        #expect(camera.localizations["es"]?.values["other"]?.contains("cámara") == true)
        #expect(camera.localizations["en"]?.values["other"]?.lowercased().contains("camera") == true)
        // The processing happens on the phone and the text must say so.
        #expect(camera.localizations["es"]?.values["other"]?.contains("no sale") == true)
    }

    @Test func noSourceFileAsksForPhotoLibraryAccess() throws {
        for file in AppFiles.files(in: AppFiles.app, extensions: ["swift", "plist", "xcconfig", "pbxproj", "xcstrings", "xcprivacy"]) {
            #expect(!(try AppFiles.text(file)).contains("NSPhotoLibraryUsageDescription"), "\(file.lastPathComponent)")
        }
    }

    // MARK: App icon

    @Test func layeredIconMatchesTheBrandMaster() throws {
        let master = AppFiles.root.appendingPathComponent("design/brand/appicon/Esplitealo.icon", isDirectory: true)
        let copy = AppFiles.resources.appendingPathComponent("Esplitealo.icon", isDirectory: true)
        let masterFiles = AppFiles.files(in: master, extensions: ["json", "svg", "png"])
        #expect(masterFiles.count >= 5)
        for file in masterFiles {
            let relative = String(file.path.dropFirst(master.path.count))
            let other = URL(fileURLWithPath: copy.path + relative)
            #expect(try Data(contentsOf: file) == (try Data(contentsOf: other)), "\(relative) differs from design/brand")
        }
        #expect(try settings("App.xcconfig")["ASSETCATALOG_COMPILER_APPICON_NAME"] == "Esplitealo")
    }
}
