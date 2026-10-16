# Bill session

Pure-Foundation state between receipt parsing/scanning and `BillCalculator`. SwiftUI screens will bind to this layer later; there is no UI here.

## `ReceiptDraft` editing

`ReceiptDraftEditing` mutates the parser’s `ReceiptDraft` in place:

- Add, update, and delete items (description, unit price, quantity → line total in cents).
- Edit subtotal, tax, tip printed on the receipt, and total.
- Parser flags on items are preserved across edits.
- After every change, `ReceiptDraftEditing.reconcile` recomputes `reconciles` and `issues` using the same rules as [receipt parsing](RECEIPT_PARSING.md). The printed total is never auto-adjusted to match items (R-14).

`ReceiptDraft.reconciliation` exposes structured `ReceiptReconciliation` for the review UI.

`ReceiptDraft.warnings` carries what the parser was unsure about into the session. `reconcile` recomputes `issues` but never touches `warnings`. `dismissWarning(in:id:)` retires one (kept in the draft, `isDismissed`), `dismissWarnings(in:forItem:)` retires those about one item, and `deleteItem` retires the deleted item's. `ReceiptDraft.activeWarnings` is what is still open. See [receipt parsing](RECEIPT_PARSING.md#warnings-what-the-scan-was-unsure-about).

## `BillSession`

Holds:

| Field | Role |
| ----- | ---- |
| `draft` | Editable receipt |
| `participants` | Named people (order index for tie-breaks) |
| `assignments` | Per-unit `ItemAssignment` rows |
| `tip` | Session tip (`TipConfiguration`) |
| `serviceChargeCents` | Gratuity printed on the receipt (allocated like the HTML mockup, outside `BillCalculator`) |
| `mismatchAcknowledged` | User chose to continue past a receipt mismatch |
| `merchantName`, `date` | Share header metadata. `date` is a `Date?`; `ShareSummaryBuilder` formats it per language ("13 oct" / "Oct 13") with a caller-supplied `Calendar` |

### Participants

- Add, rename, remove (at least one required).
- Removing someone with assignments returns `requiresConfirmation` unless `forceRemoveParticipant` is used after UI confirmation.

### Assignments

- Item-first, per unit index for quantity lines.
- Equal split when multiple people share a unit.
- `unassignedUnits`, `preTaxSubtotalCents`, `splitRestEvenly()` (delegates to `BillCalculator.splitRestEvenly`).

### Totals

- Default session tip is 20% pre-tax; tip starts at 0% when `serviceChargeCents` or a receipt tip line is present.
- `splitResult` and `personBreakdowns` call `BillCalculator`; service shares use the same largest-remainder rule via `SessionPoolAllocator`.
- `confirmedBillTotalCents` is always **derived** from allocated components: items + tax + `serviceChargeCents` + `receiptTipOnBillCents` (from `draft.tip` when there is no service charge) + session tip. Person totals must equal that sum exactly.
- `printedReceiptTotalCents` is optional (`nil` when the draft has no printed total). A missing total is never treated as zero; `phase` is `.missingPrintedTotal` and sharing is blocked with `shareBlockReason == .missingPrintedTotal`.
- `canShare` additionally requires reconciliation, full assignment, person totals matching the derived total, and `derivedBillTotalCents == printedReceiptTotal + sessionTipCents` when a printed total exists.

### Phase (`BillSessionPhase`)

| Phase | Meaning |
| ----- | ------- |
| `draft` | No participants yet |
| `missingPrintedTotal` | No printed receipt total to reconcile against |
| `mismatch` | Receipt numbers do not reconcile and the user has not acknowledged |
| `needsAssignment` | Unclaimed units remain |
| `totals` | Assigned; user can review totals but not share yet |
| `ready` | `canShare` is true |

After `acknowledgeMismatch()`, the session is no longer stuck in `.mismatch`; it moves through assignment and `.totals` as usual while `canShare` stays false until the receipt reconciles. `shareBlockReason` exposes why sharing is blocked (`missingPrintedTotal`, `receiptMismatch`, `unassignedItems`, `discountNeedsManualAdjustment`).

### Parser adjustments (discounts)

`ReceiptDraft.adjustments` (for example parser discount lines) are included in `netItemsSubtotalCents`, the session tip basis, and `derivedBillTotalCents`, matching `ReceiptReconciliationEngine`. v1 does **not** allocate discounts across people ([R-29](REQUIREMENTS.md), [calculation rules](CALCULATION_RULES.md), [roadmap](ROADMAP.md)). While any adjustment rows remain, `hasUnallocatedAdjustments` is true, `canShare` is false, and `shareBlockReason` is `discountNeedsManualAdjustment` even when the receipt reconciles. The user must net discounts into item prices or remove adjustment rows; sharing unblocks automatically once adjustments are empty and totals still reconcile. Proportional discount allocation is a future product decision.

## Saving the bill in progress

iOS can end a backgrounded app without warning (for example while someone checks WhatsApp or ATH Móvil at the table), so the bill in progress is autosaved as a draft and deleted when the bill is finished. This layer is in `EsplitealoCore` and has no UI.

- `BillSession` is `Codable`. `BillSessionCoding.encoder()` / `decoder()` are the one JSON dialect (ISO 8601 dates, sorted keys).
- The JSON carries `schemaVersion` (`BillSession.currentSchemaVersion`, currently 2). Decoding accepts versions 1 and 2 and throws `BillSessionDecodingError.unsupportedSchemaVersion` for a newer or missing version. A restored bill equals the one that was saved: the draft is not re-reconciled on decode.
- **Version 2** added `ReceiptDraft.warnings` (what the parser was unsure about, with `isDismissed` per warning). A version 1 file has no `warnings` key and decodes with none; it is written back as version 2 the next time the bill is saved. Version 1 drafts cannot have lost anything on the way: `ReceiptDraftEditing.reconcile` used to replace the parser's `issues` with the reconciliation's, which is why nothing was stored. Fixtures: `v1-in-progress.json`, `v1-minimal.json` (the old format, kept to prove migration) and `v2-with-warnings.json`.
- The stored shape is a contract once drafts exist on phones. Changing it means bumping the version, adding a migration, and committing a fixture such as `Tests/Fixtures/BillSessions/v1-in-progress.json` that proves the old file still decodes.
- `BillDraftStore` is the protocol (`load`, `save`, `delete`; at most one draft). `FileBillDraftStore(directory:)` writes one `draft.json` atomically (no temporary files left behind) and creates the directory if needed. `load()` returns `nil` when there is no draft and throws when the file is unreadable, so the app decides whether to delete it.
- Still the app's job: debounce saves (about 0.5 s) and save on `scenePhase == .background`; choose the directory (`Application Support/Draft`) and mark it excluded from backup; offer to continue a recent draft and delete it when the bill is shared or abandoned; store any receipt image next to the draft file, never in the photo library.

## Share text

`ShareSummaryBuilder.build(for:language:calendar:)` produces per-person text for `es` or `en`. Wording follows the bilingual HTML mockups (`share` strings): neutral Spanish, Puerto Rican closing line in Spanish, “total” not “monto”, no IVU label, no payment copy. Strings live in `ShareSummaryStrings` for a future localization catalog.

A tip printed on the receipt (`draft.tip`, with no `serviceChargeCents`) is shared like a service charge and appears in each person's lines as `service`, so a person's lines always add up to what they owe; the header still reads `Bill <printed total> + <tip> = <total>`. The Totals screen shows the same amount in its Servicio column.
