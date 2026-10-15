import Foundation

/// Keeps the bill in progress across app launches, so iOS ending a backgrounded app does not lose it.
/// There is at most one draft. The app saves after edits, and deletes the draft when the bill is finished.
public protocol BillDraftStore: Sendable {
    /// The saved bill, or nil when there is none. Throws when a draft exists but cannot be read
    /// (corrupt, or written by a newer app); the caller decides whether to `delete()` it.
    func load() throws -> BillSession?
    func save(_ session: BillSession) throws
    /// Removes the draft. Not an error when there is none.
    func delete() throws
}

/// Stores the draft as one JSON file (`draft.json`) in a directory the app owns, such as
/// `Application Support/Draft`. Writes are atomic: a crash mid-save leaves the previous draft intact.
public struct FileBillDraftStore: BillDraftStore {
    public static let fileName = "draft.json"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var fileURL: URL {
        directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    public func load() throws -> BillSession? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return nil
        }
        return try BillSessionCoding.decoder().decode(BillSession.self, from: data)
    }

    public func save(_ session: BillSession) throws {
        let data = try BillSessionCoding.encoder().encode(session)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    public func delete() throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            return
        }
    }
}
