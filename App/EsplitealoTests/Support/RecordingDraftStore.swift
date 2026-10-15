import EsplitealoCore
import Foundation
import Synchronization

/// A draft store that remembers what happened to it, and can be told to fail.
final class RecordingDraftStore: BillDraftStore, Sendable {
    struct Failure: Error, Equatable {}

    private struct State {
        var draft: BillSession?
        var saves: [BillSession] = []
        var deletes = 0
        var failSaves = false
        var corrupt = false
    }

    private let state = Mutex(State())

    init(draft: BillSession? = nil, corrupt: Bool = false) {
        state.withLock {
            $0.draft = draft
            $0.corrupt = corrupt
        }
    }

    var saves: [BillSession] { state.withLock { $0.saves } }
    var saveCount: Int { state.withLock { $0.saves.count } }
    var deleteCount: Int { state.withLock { $0.deletes } }
    var stored: BillSession? { state.withLock { $0.draft } }

    func failSaves(_ value: Bool) { state.withLock { $0.failSaves = value } }

    func load() throws -> BillSession? {
        try state.withLock { state in
            if state.corrupt { throw BillSessionDecodingError.unsupportedSchemaVersion(found: 99) }
            return state.draft
        }
    }

    func save(_ session: BillSession) throws {
        try state.withLock { state in
            if state.failSaves { throw Failure() }
            state.draft = session
            state.saves.append(session)
        }
    }

    func delete() throws {
        state.withLock {
            $0.draft = nil
            $0.corrupt = false
            $0.deletes += 1
        }
    }
}
