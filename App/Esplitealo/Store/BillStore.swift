import EsplitealoCore
import Foundation
import Observation

/// The bill in progress. SwiftUI reads `session`; screens change it with `update(_:)`, which autosaves the draft
/// through a `BillDraftStore` after a quiet period, so iOS ending a backgrounded app never loses the bill.
///
/// - A blank bill (no items, no people) is never written, and clearing a bill removes its draft.
/// - Changes are debounced (0.5 s by default); `saveNow()` writes at once (call it when the app goes to the background).
/// - `finishBill()` deletes the draft: it is gone once the bill is done.
/// - On launch, `loadSavedDraft()` exposes the saved bill as `resumeCandidate`; the UI asks, then calls
///   `resumeSavedDraft()` or `discardSavedDraft()`. A draft that cannot be read is deleted, not offered.
///
/// Time comes from an injected `Clock`, so tests use a clock they advance by hand.
@MainActor @Observable
final class BillStore {
    private(set) var session: BillSession?
    private(set) var resumeCandidate: BillSession?
    /// The error of the last draft write, nil after a successful one. Not shown to the user: the bill stays in memory.
    private(set) var saveError: (any Error)?

    @ObservationIgnored private let draftStore: any BillDraftStore
    @ObservationIgnored private let clock: any Clock<Duration>
    @ObservationIgnored private let debounce: Duration
    /// The save waiting for the quiet period. Exposed so tests can wait for it.
    @ObservationIgnored private(set) var pendingSave: Task<Void, Never>?

    init(draftStore: any BillDraftStore, clock: any Clock<Duration> = ContinuousClock(), debounce: Duration = .milliseconds(500)) {
        self.draftStore = draftStore
        self.clock = clock
        self.debounce = debounce
    }

    // MARK: Launch

    func loadSavedDraft() {
        do {
            if let saved = try draftStore.load(), Self.hasContent(saved) {
                resumeCandidate = saved
            } else {
                resumeCandidate = nil
                try draftStore.delete()
            }
        } catch {
            resumeCandidate = nil
            try? draftStore.delete()
        }
    }

    func resumeSavedDraft() {
        session = resumeCandidate
        resumeCandidate = nil
    }

    func discardSavedDraft() {
        resumeCandidate = nil
        try? draftStore.delete()
    }

    // MARK: The bill

    /// Starts a bill, replacing any current one. Pass the scanned (or empty) receipt.
    func startNewBill(draft: ReceiptDraft = ReceiptDraft()) {
        pendingSave?.cancel()
        pendingSave = nil
        let bill = BillSession(draft: draft)
        session = bill
        if Self.hasContent(bill) { scheduleSave() }
    }

    /// Changes the bill and schedules an autosave. Nothing happens when there is no bill or nothing changed.
    func update(_ change: (inout BillSession) -> Void) {
        guard var changed = session else { return }
        change(&changed)
        guard changed != session else { return }
        session = changed
        scheduleSave()
    }

    /// Writes the draft now, for example when the app moves to the background.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        writeDraft()
    }

    /// The bill is done (shared, or abandoned): forget it and delete the draft.
    func finishBill() {
        pendingSave?.cancel()
        pendingSave = nil
        session = nil
        saveError = nil
        try? draftStore.delete()
    }

    // MARK: Saving

    private static func hasContent(_ bill: BillSession) -> Bool {
        !bill.draft.items.isEmpty || !bill.participants.isEmpty
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [clock, debounce] in
            do {
                try await clock.sleep(for: debounce)
            } catch {
                return // a newer edit, saveNow() or finishBill() took over
            }
            writeDraft()
        }
    }

    /// Small JSON file, so it is written on the main actor; the write is atomic.
    private func writeDraft() {
        do {
            if let session, Self.hasContent(session) {
                try draftStore.save(session)
            } else {
                try draftStore.delete()
            }
            saveError = nil
        } catch {
            saveError = error
        }
    }
}
