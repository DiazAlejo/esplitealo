# Esplitéalo

Scan a receipt, tap who had what, and share a correct breakdown of who owes what, in under a minute.

Esplitéalo is a simple iOS app for splitting a restaurant bill. It reads the receipt on the device, lets you fix anything it got wrong, and divides items, tax, and tip fairly between everyone at the table.

## Principles

- **The receipt is the source of truth.** The app never silently changes a total to make the numbers fit.
- **You stay in control.** Text recognition only suggests; you confirm every item, price, assignment, and total.
- **Private by default.** Recognition runs on the device. No accounts, no backend, no AI, no data leaves the phone.
- **Exact math.** All money is handled in integer cents, and every rounding adjustment is shown.

## How it works

1. **Start a bill.** Take a photo of the receipt or choose an existing image.
2. **Scan and review.** On-device text recognition suggests items and prices. Correct anything that is wrong.
3. **Add people and assign items.** Tap an item, then pick who had it. Shared items split equally.
4. **Settle the bill.** Choose the tip and confirm tax and totals.
5. **Share the breakdown.** Send a per-person summary through the iOS share sheet.

The flow is linear, but you can go back and edit the receipt, assignments, or tip at any point without losing your work.

## Status

In development. The calculation engine (`BillCalculator`, a Swift package with unit tests) is implemented. Next is the assignment screen, driven by a hardcoded sample receipt, before any camera or text recognition work.

## Documentation

- [Requirements](docs/REQUIREMENTS.md): MVP scope, functional requirements, and acceptance criteria.
- [Screens](docs/SCREENS.md): screen-by-screen specification.
- [Calculation rules](docs/CALCULATION_RULES.md): how items, tax, tip, and rounding are allocated.
- [Architecture](docs/ARCHITECTURE.md): technology and code layout.
- [Roadmap](docs/ROADMAP.md): milestones and what is explicitly out of scope for launch.
- [Design guide](docs/DESIGN_GUIDE.md): principles, starter palette, type scale, and screen-by-screen visual guidance.
- [HTML mockups](design/mockups/README.md): bilingual static screen designs (open offline by double-clicking).
- [Tab analysis](docs/research/TAB_ANALYSIS.md): research on an existing bill-splitting app, with candidate rules (proposals, not decisions).

## Tech stack (planned)

SwiftUI, Vision (on-device text recognition), AVFoundation and PhotosUI (capture and import), and optionally SwiftData for saved bills. No backend.
