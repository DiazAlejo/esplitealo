# Bill session

Pure-Foundation state between receipt parsing/scanning and `BillCalculator`. SwiftUI screens will bind to this layer later; there is no UI here.

## `ReceiptDraft` editing

`ReceiptDraftEditing` mutates the parser’s `ReceiptDraft` in place:

- Add, update, and delete items (description, unit price, quantity → line total in cents).
- Edit subtotal, tax, tip printed on the receipt, and total.
- Parser flags on items are preserved across edits.
- After every change, `ReceiptDraftEditing.reconcile` recomputes `reconciles` and `issues` using the same rules as [receipt parsing](RECEIPT_PARSING.md). The printed total is never auto-adjusted to match items (R-14).

`ReceiptDraft.reconciliation` exposes structured `ReceiptReconciliation` for the review UI.

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
| `merchantName`, `dateLabel`, `dateLabelEnglish` | Share header metadata |

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
- `canShare` requires reconciliation, full assignment, and person totals summing to `confirmedBillTotalCents` (printed receipt total + session tip).

### Phase (`BillSessionPhase`)

| Phase | Meaning |
| ----- | ------- |
| `draft` | No participants yet |
| `mismatch` | Receipt numbers do not reconcile and the user has not acknowledged |
| `needsAssignment` | Unclaimed units remain |
| `ready` | `canShare` is true |

Mismatch blocks sharing but may be acknowledged to continue; sharing stays blocked until the receipt reconciles.

## Share text

`ShareSummaryBuilder.build(for:language:)` produces per-person text for `es` or `en`. Wording follows the bilingual HTML mockups (`share` strings): neutral Spanish, Puerto Rican closing line in Spanish, “total” not “monto”, no IVU label, no payment copy. Strings live in `ShareSummaryStrings` for a future localization catalog.
