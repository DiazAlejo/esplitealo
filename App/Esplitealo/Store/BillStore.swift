import EsplitealoCore
import Foundation
import Observation

/// The bill in progress. SwiftUI reads `session`; screens change it with `update(_:)`, which autosaves the draft
/// through a `BillDraftStore` after a quiet period, so iOS ending a backgrounded app never loses the bill.
///
/// - A blank bill (no items, no people) is never written, and clearing a bill removes its draft.
/// - Changes are debounced (0.5 s by default); `saveNow()` writes at once (call it when the app goes to the background).
/// - `finishBill()` deletes the draft: it is gone once the bill is done (abandoned from Home or Review).
/// - `billShared()` deletes the draft when the share completes but keeps the bill in memory for the success screen and
///   Back. The bill is then not "in progress" and is not written again, until an edit makes it live again.
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
    /// The bill was shared: its draft file is gone and stays gone until the bill is edited.
    private(set) var isShared = false

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

    /// What Home shows on its "continue your bill" card: set while the bill has content and has not been shared.
    struct BillInProgress: Equatable {
        var itemCount: Int
        /// The printed total, or the items' sum when the receipt has none.
        var totalCents: Int
        /// The screens to show to put the user back at the step the bill reached.
        var resumePath: [AppRoute]
    }

    var billInProgress: BillInProgress? {
        guard let session, !isShared, Self.hasContent(session) else { return nil }
        return BillInProgress(
            itemCount: session.draft.items.count,
            totalCents: session.printedReceiptTotalCents ?? session.netItemsSubtotalCents,
            resumePath: AppRoute.path(resuming: session)
        )
    }

    var hasBillInProgress: Bool { billInProgress != nil }

    /// Starts a bill, replacing any current one. Pass the scanned (or empty) receipt. Callers ask the user first when
    /// `hasBillInProgress`. A blank replacement also removes the old bill's draft file, so it is not offered later.
    func startNewBill(draft: ReceiptDraft = ReceiptDraft()) {
        pendingSave?.cancel()
        pendingSave = nil
        let bill = BillSession(draft: draft, date: Date())
        session = bill
        isShared = false
        if Self.hasContent(bill) {
            scheduleSave()
        } else {
            try? draftStore.delete()
        }
    }

    /// Changes the bill and schedules an autosave. Nothing happens when there is no bill or nothing changed.
    func update(_ change: (inout BillSession) -> Void) {
        guard var changed = session else { return }
        change(&changed)
        guard changed != session else { return }
        session = changed
        isShared = false
        scheduleSave()
    }

    /// Writes the draft now, for example when the app moves to the background.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        writeDraft()
    }

    /// The bill is done ("Nueva cuenta") or was abandoned: forget it and delete the draft.
    func finishBill() {
        pendingSave?.cancel()
        pendingSave = nil
        session = nil
        isShared = false
        saveError = nil
        try? draftStore.delete()
    }

    /// The bill was shared: delete the draft now (R-32) so a relaunch does not offer a finished bill, but keep the
    /// bill in memory. An edit made afterwards (Back from the success screen) saves it again.
    func billShared() {
        pendingSave?.cancel()
        pendingSave = nil
        isShared = true
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
        guard !isShared else { return } // the draft was deleted when the bill was shared
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
