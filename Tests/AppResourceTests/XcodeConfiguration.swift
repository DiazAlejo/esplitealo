import Foundation
import Testing

/// An xcconfig file read into key/value settings. `#include` is followed and later assignments override earlier
/// ones, as in Xcode. `#include?` is recorded in `optionalIncludes` and followed only when `followOptionalIncludes`
/// is set and the file exists, so reading the committed files does not depend on a machine's local overrides.
struct XCConfig {
    private(set) var settings: [String: String] = [:]
    private(set) var optionalIncludes: [String] = []
    private let followOptionalIncludes: Bool

    init(contentsOf url: URL, followOptionalIncludes: Bool = false) throws {
        self.followOptionalIncludes = followOptionalIncludes
        try load(url)
    }

    private mutating func load(_ url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            if line.hasPrefix("#include") {
                let optional = line.hasPrefix("#include?")
                let parts = line.split(separator: "\"")
                guard parts.count >= 2 else { continue }
                let included = url.deletingLastPathComponent().appendingPathComponent(String(parts[1]))
                if optional {
                    optionalIncludes.append(String(parts[1]))
                    if !followOptionalIncludes || !FileManager.default.fileExists(atPath: included.path) { continue }
                }
                try load(included)
                continue
            }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            settings[key] = value
        }
    }
}

/// The object graph of `project.pbxproj`, parsed as a property list.
struct XcodeProject {
    typealias Object = [String: Any]

    let root: Object
    let objects: [String: Object]
    private let directory: URL

    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? Object)
        root = plist
        objects = (plist["objects"] as? [String: Object]) ?? [:]
        // `…/Esplitealo.xcodeproj/project.pbxproj` → the folder that holds the .xcodeproj.
        directory = url.deletingLastPathComponent().deletingLastPathComponent()
    }

    func objects(ofType isa: String) -> [Object] {
        objects.values.filter { $0["isa"] as? String == isa }
    }

    var project: Object { objects(ofType: "PBXProject")[0] }

    var targets: [Object] { objects(ofType: "PBXNativeTarget") }

    func target(named name: String) -> Object? { targets.first { $0["name"] as? String == name } }

    /// The folders a target synchronizes with the file system.
    func synchronizedFolders(of target: Object) -> [String] {
        ((target["fileSystemSynchronizedGroups"] as? [String]) ?? []).compactMap { objects[$0]?["path"] as? String }
    }

    /// Project-level and target-level build configurations for a configuration name, as `(xcconfig, inline settings)`.
    private func configurations(of owner: Object, named name: String) -> [(XCConfig?, [String: Any])] {
        guard let listID = owner["buildConfigurationList"] as? String,
              let list = objects[listID],
              let ids = list["buildConfigurations"] as? [String] else { return [] }
        return ids.compactMap { id -> (XCConfig?, [String: Any])? in
            guard let configuration = objects[id], configuration["name"] as? String == name else { return nil }
            var xcconfig: XCConfig?
            if let reference = configuration["baseConfigurationReference"] as? String,
               let path = objects[reference]?["path"] as? String {
                xcconfig = try? XCConfig(contentsOf: directory.appendingPathComponent("Config").appendingPathComponent(path))
            }
            return (xcconfig, (configuration["buildSettings"] as? [String: Any]) ?? [:])
        }
    }

    /// The settings that apply to a target in a configuration: project xcconfig, project inline settings, then the
    /// target's xcconfig and inline settings. Values are returned with `$(…)` references resolved.
    func effectiveSettings(target: Object, configuration: String) -> [String: String] {
        var combined = XCConfigMerge()
        for (xcconfig, inline) in configurations(of: project, named: configuration) + configurations(of: target, named: configuration) {
            combined.apply(xcconfig, inline: inline)
        }
        return combined.values.mapValues { combined.resolve($0) }
    }

    /// Every inline `buildSettings` dictionary in the project, project-level and target-level.
    var inlineBuildSettings: [[String: Any]] {
        objects(ofType: "XCBuildConfiguration").map { ($0["buildSettings"] as? [String: Any]) ?? [:] }
    }
}

private struct XCConfigMerge {
    var values: [String: String] = [:]

    mutating func apply(_ xcconfig: XCConfig?, inline: [String: Any]) {
        if let xcconfig { values.merge(xcconfig.settings) { _, new in new } }
        for (key, value) in inline { values[key] = value as? String ?? "\(value)" }
    }

    func resolve(_ value: String) -> String {
        var result = value
        for _ in 0..<8 {
            guard let open = result.range(of: "$("), let close = result.range(of: ")", range: open.upperBound..<result.endIndex) else { break }
            let name = String(result[open.upperBound..<close.lowerBound])
            result.replaceSubrange(open.lowerBound..<close.upperBound, with: values[name] ?? "")
        }
        return result
    }
}
