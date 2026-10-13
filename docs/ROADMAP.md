# Roadmap

## Milestones

### 1. Core split (first milestone)

Build the assignment screen and calculation engine before the camera. Use a hardcoded sample receipt to test the complete experience, from item selection through the final share summary.

This ordering reduces risk: recognizing a receipt is a messy input problem, while the splitting math and assignment behavior are the product's core value.

- `BillCalculator` with integer cents and unit tests covering the invariants in [calculation rules](CALCULATION_RULES.md).
- People and assignment screens.
- Totals screen and share sheet summary.

### 2. Receipt review and manual entry

- Review receipt screen: edit, add, and delete items; edit subtotal, tax, and total; flag suspicious values.
- Full manual entry path, so the app works without any scanning.

### 3. Capture and recognition

- Camera capture and photo import, including denied-permission handling.
- On-device Vision text recognition and a conservative `ReceiptParser`.
- Graceful failure: retry or fall back to manual entry.

### 4. Polish and release

- Visual identity, accessibility, and edge cases.
- Test on a physical iPhone.
- App Store listing and submission.

### Optional

- Saved recent bills with SwiftData, if the schedule allows.

## Out of scope for launch

Do not add these unless early testing reveals a compelling need:

- AI receipt interpretation.
- User accounts or cloud sync.
- Venmo, PayPal, or other payment integrations.
- Group histories across multiple outings.
- Restaurant-specific integrations.
- Unequal custom shares for individual items.
- Automatic discount allocation and complex service-charge rules.
