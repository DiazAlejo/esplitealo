import Foundation

/// Where the bill in progress lives on disk.
enum DraftLocation {
    /// `Application Support/Draft`, created on demand and excluded from iCloud and device backups, because a draft
    /// can hold receipt data that should not leave the phone. `base` replaces Application Support in tests.
    static func defaultDirectory(base: URL? = nil) throws -> URL {
        let root = try base ?? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        var directory = root.appendingPathComponent("Draft", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }

    /// A throwaway directory, so UI tests never see or touch a real draft.
    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("esplitealo-uitest-\(UUID().uuidString)", isDirectory: true)
    }
}
