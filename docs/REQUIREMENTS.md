# Requirements

MVP requirements for Esplitéalo. The product must make splitting a restaurant bill accurate and fast, without accounts, a backend, or AI.

Design principle: the receipt is the source of truth, and the user stays in control of every assignment and total.

The core question the first release must answer: can a group turn a receipt into a correct, shareable breakdown of who owes what in under a minute?

## Functional requirements

### Receipt capture

- **R-1.** The user can take a photo of a receipt with the camera.
- **R-2.** The user can import an existing image from the photo library.
- **R-3.** If camera permission is denied, the app explains how to enable it in Settings and keeps photo import available.
- **R-4.** No permission is requested until the user chooses an action that needs it.
- **R-5.** Capture shows guidance to include all items, tax, and the total, and offers retake and use-photo controls.

### Recognition and parsing

- **R-6.** Text is recognized on the device with Apple Vision. Nothing is sent to a server.
- **R-7.** The parser suggests item descriptions, prices, subtotal, tax, tip, and total. Its guesses are conservative.
- **R-8.** Recognized text is only a suggestion. The app never assumes every detected number is an item price.
- **R-9.** If recognition fails, the user can retry or enter items manually.

### Receipt review

- **R-10.** The user can edit, add, and delete items, and edit each item's description and price.
- **R-11.** The user can edit the subtotal, tax, and receipt total.
- **R-12.** The original receipt image stays available for reference.
- **R-13.** Missing or suspicious values are flagged.
- **R-14.** The app never silently changes the receipt total to match the extracted items.

### People

- **R-15.** The user can add, rename, and remove participants by typing names. No accounts and no contacts access.
- **R-16.** At least one participant is required to continue.
- **R-17.** Removing a participant who has assignments prompts for reassignment or confirmation. Assignments are never silently erased.

### Assignment

- **R-18.** The user taps an item and selects one or more participants for it.
- **R-19.** One selected person gets 100% of the item. Multiple selected people split it equally.
- **R-20.** Unassigned items are visibly flagged.
- **R-21.** Each participant's pre-tax subtotal updates immediately as assignments change.
- **R-22.** The user can edit names, prices, people, and assignments at any time without restarting.
- **R-23.** An assignment progress indicator shows how many items are assigned.

### Totals and sharing

- **R-24.** The user picks a tip as a percentage or a custom amount.
- **R-25.** Tax and tip are allocated proportionally to each person's assigned item subtotal (see [calculation rules](CALCULATION_RULES.md)).
- **R-26.** The summary shows, per person, item subtotal, tax share, tip share, and final amount.
- **R-27.** Rounding adjustments are shown transparently.
- **R-28.** The sum of amounts owed equals the confirmed bill total. If the calculated total and the confirmed receipt total differ, the discrepancy is flagged and sharing is blocked until the user corrects the inputs.
- **R-29.** Discounts and service charges are manual adjustments in version one.
- **R-30.** The user can share a readable text summary through the native iOS share sheet. No payment integration.

### Flow

- **R-31.** The flow is linear, but the user can go back to edit the receipt, assignments, or tip without losing work.
- **R-32.** An active bill is kept in memory. Saved bills (SwiftData) are optional and only added if the schedule allows.

## Non-functional requirements

- **N-1.** Platform: iOS, built with SwiftUI.
- **N-2.** Privacy: no backend, no accounts, no analytics that transmit receipt data, no AI services.
- **N-3.** All monetary calculations use integer cents, never floating point.
- **N-4.** The calculation engine is pure logic, independent of the UI, and fully unit-tested.
- **N-5.** The app never claims OCR is perfect and never produces a final split when the numbers do not reconcile.

## Acceptance criteria (release checklist)

The app is ready for release when all of these pass.

### Receipt capture

- [ ] Take a receipt photo and import an existing photo.
- [ ] Recognize receipt text without sending it to a server.
- [ ] Edit recognition results and manually add missing items.

### People and assignments

- [ ] Add, rename, and remove participants safely.
- [ ] Assign an item to one or multiple people.
- [ ] See unassigned items and participant subtotals immediately.

### Calculations

- [ ] Allocate tax and tip proportionally.
- [ ] Handle shared items and currency rounding correctly.
- [ ] Final amounts add up to the confirmed receipt total.

### Release quality

- [ ] Share a readable per-person breakdown.
- [ ] Handle denied permissions and failed recognition gracefully.
- [ ] Test on a physical iPhone and submit the App Store listing.

## Out of scope for launch

See [Roadmap](ROADMAP.md#out-of-scope-for-launch).
