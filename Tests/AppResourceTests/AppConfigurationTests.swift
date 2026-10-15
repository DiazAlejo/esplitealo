import Foundation
import Testing

/// Checks of the app's configuration, read as parsed meaning (xcconfig settings, the project's object graph, plists) (xcconfig files, privacy manifest, Info.plist strings, icon).
struct AppConfigurationTests {
    private func settings(_ name: String) throws -> [String: String] {
        try XCConfig(contentsOf: AppFiles.config.appendingPathComponent(name)).settings
    }

    private func project() throws -> XcodeProject {
        try XcodeProject(contentsOf: AppFiles.project)
    }

    private let targetNames = ["Esplitealo", "EsplitealoTests", "EsplitealoUITests"]
    private let configurationNames = ["Debug", "Release"]

    /// The effective settings of every target in every configuration.
    private func allEffectiveSettings() throws -> [(String, [String: String])] {
        let project = try project()
        return try targetNames.flatMap { name in
            let target = try #require(project.target(named: name))
            return configurationNames.map { ("\(name) \($0)", project.effectiveSettings(target: target, configuration: $0)) }
        }
    }

    // MARK: Build settings

    @Test func sharedSettingsRequireIOS18AndSwift6() throws {
        for (label, effective) in try allEffectiveSettings() {
            #expect(effective["IPHONEOS_DEPLOYMENT_TARGET"] == "18.0", "\(label)")
            #expect(effective["SWIFT_VERSION"] == "6.0", "\(label)")
            #expect(effective["SWIFT_STRICT_CONCURRENCY"] == "complete", "\(label)")
        }
    }

    @Test func appTargetIsMainActorByDefaultWithApproachableConcurrency() throws {
        let project = try project()
        for name in ["Esplitealo", "EsplitealoTests"] {
            let target = try #require(project.target(named: name))
            for configuration in configurationNames {
                let effective = project.effectiveSettings(target: target, configuration: configuration)
                #expect(effective["SWIFT_DEFAULT_ACTOR_ISOLATION"] == "MainActor", "\(name) \(configuration)")
                #expect(effective["SWIFT_APPROACHABLE_CONCURRENCY"] == "YES", "\(name) \(configuration)")
            }
        }
    }

    @Test func bundleIdentifierIsOneSettingInOneXcconfig() throws {
        #expect(try settings("Shared.xcconfig")["APP_BUNDLE_IDENTIFIER"] == "com.esplitealo.app")
        let definitions = try AppFiles.files(in: AppFiles.config, extensions: ["xcconfig"])
            .filter { try XCConfig(contentsOf: $0).settings["APP_BUNDLE_IDENTIFIER"] != nil && $0.lastPathComponent != "Debug.xcconfig" && $0.lastPathComponent != "Release.xcconfig" }
        #expect(definitions.map(\.lastPathComponent) == ["Shared.xcconfig"])

        let project = try project()
        let expected = ["Esplitealo": "com.esplitealo.app", "EsplitealoTests": "com.esplitealo.app.tests", "EsplitealoUITests": "com.esplitealo.app.uitests"]
        for (name, identifier) in expected {
            let target = try #require(project.target(named: name))
            for configuration in configurationNames {
                #expect(project.effectiveSettings(target: target, configuration: configuration)["PRODUCT_BUNDLE_IDENTIFIER"] == identifier, "\(name) \(configuration)")
            }
        }
        // The project file takes every value from the xcconfig files.
        for settings in project.inlineBuildSettings {
            #expect(settings["PRODUCT_BUNDLE_IDENTIFIER"] == nil)
            #expect(!settings.values.contains { "\($0)".contains("com.esplitealo") })
        }
    }

    @Test func noTeamIsCommittedAndLocalXcconfigIsIgnored() throws {
        for (label, effective) in try allEffectiveSettings() {
            #expect((effective["DEVELOPMENT_TEAM"] ?? "").isEmpty, "\(label)")
        }
        for settings in try project().inlineBuildSettings {
            #expect(((settings["DEVELOPMENT_TEAM"] as? String) ?? "").isEmpty)
        }
        // A local, git-ignored file lets the owner set their personal team.
        let committed = try XCConfig(contentsOf: AppFiles.config.appendingPathComponent("Shared.xcconfig"))
        #expect(committed.optionalIncludes == ["Local.xcconfig"])
        #expect(committed.settings["DEVELOPMENT_TEAM"] == "")
        let local = AppFiles.config.appendingPathComponent("Local.xcconfig")
        #expect(try gitCheckIgnore(local) == true)
        #expect(try gitCheckIgnore(AppFiles.config.appendingPathComponent("Shared.xcconfig")) == false)
    }

    @Test func localXcconfigOverridesTheTeamWhenPresent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["Shared.xcconfig"] {
            try FileManager.default.copyItem(at: AppFiles.config.appendingPathComponent(name), to: directory.appendingPathComponent(name))
        }
        try "DEVELOPMENT_TEAM = ABCDE12345\n".write(to: directory.appendingPathComponent("Local.xcconfig"), atomically: true, encoding: .utf8)
        let shared = directory.appendingPathComponent("Shared.xcconfig")
        #expect(try XCConfig(contentsOf: shared, followOptionalIncludes: true).settings["DEVELOPMENT_TEAM"] == "ABCDE12345")
        #expect(try XCConfig(contentsOf: shared).settings["DEVELOPMENT_TEAM"] == "")
    }

    /// Runs `git check-ignore` and returns whether git ignores the path.
    private func gitCheckIgnore(_ url: URL) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "check-ignore", "--quiet", url.path]
        process.currentDirectoryURL = AppFiles.root
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    @Test func projectUsesSynchronizedFoldersAndSpanishDevelopmentRegion() throws {
        let project = try project()
        #expect(project.project["developmentRegion"] as? String == "es")
        #expect(project.project["knownRegions"] as? [String] == ["es", "en", "Base"])
        for name in targetNames {
            let target = try #require(project.target(named: name))
            #expect(project.synchronizedFolders(of: target) == [name], "\(name)")
        }
        for group in project.objects(ofType: "PBXFileSystemSynchronizedRootGroup") {
            #expect(targetNames.contains(group["path"] as? String ?? ""))
        }
        #expect(!project.objects(ofType: "XCLocalSwiftPackageReference").isEmpty)
        let packageReferences = (project.project["packageReferences"] as? [String]) ?? []
        #expect(packageReferences.contains { project.objects[$0]?["isa"] as? String == "XCLocalSwiftPackageReference" })
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
        let project = try project()
        let app = try #require(project.target(named: "Esplitealo"))
        for configuration in configurationNames {
            let effective = project.effectiveSettings(target: app, configuration: configuration)
            #expect(effective["INFOPLIST_KEY_NSCameraUsageDescription"]?.isEmpty == false)
            #expect(effective["INFOPLIST_KEY_ITSAppUsesNonExemptEncryption"] == "NO")
        }
        for (label, effective) in try allEffectiveSettings() {
            #expect(!effective.keys.contains { $0.contains("NSPhotoLibrary") }, "\(label)")
        }

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
