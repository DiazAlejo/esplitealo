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

In development. The calculation engine, receipt parser, scanning pipeline, bill session with autosaved draft, and the design system (tokens, components, Chavito) are implemented and tested. The app skeleton (Xcode project, navigation shell with placeholder screens, string catalogs in Spanish and English) is in place; the Review receipt and Add people screens are built, and the other screens are being built one by one.

## Build and test

Requires Xcode 26.3 or later (the Swift package uses swift-tools-version 6.0). The app targets iOS 18 or later.

```bash
swift build
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test
```

To build the app and run its unit, snapshot and UI tests on an iOS simulator, see [The iOS app](docs/APP.md); [Continuous integration](docs/CI.md) lists every check and the exact commands.

## Documentation

- [Requirements](docs/REQUIREMENTS.md): MVP scope, functional requirements, and acceptance criteria.
- [Screens](docs/SCREENS.md): screen-by-screen specification.
- [Calculation rules](docs/CALCULATION_RULES.md): how items, tax, tip, and rounding are allocated.
- [Calculator proof](docs/CALCULATOR_PROOF.md): property tests and an independent reference calculator that check every split to the cent.
- [Architecture](docs/ARCHITECTURE.md): technology and code layout.
- [The iOS app](docs/APP.md): app structure, design system, strings, how to add a screen, how to run the tests.
- [Continuous integration](docs/CI.md): what runs on every pull request and how to run it locally.
- [Roadmap](docs/ROADMAP.md): milestones and what is explicitly out of scope for launch.
- [Design guide](docs/DESIGN_GUIDE.md): principles, starter palette, type scale, and screen-by-screen visual guidance.
- [Brand assets](design/brand/README.md): Dos paredes logo, app icon package, and terminal icon build notes.
- [HTML mockups](design/mockups/README.md): bilingual static screen designs (open offline by double-clicking).
- [Tab analysis](docs/research/TAB_ANALYSIS.md): research on an existing bill-splitting app, with candidate rules (proposals, not decisions).

## Tech stack

Native Swift 6 and SwiftUI, **iOS 18 or later**. Vision (on-device text recognition), VisionKit, AVFoundation and PhotosUI (capture and import). The bill in progress is autosaved on the phone as a small JSON draft and deleted when the bill is finished; no database. No backend and no third-party dependencies.

## License

Copyright (c) 2026 DiazAlejo. All rights reserved. The source is published for viewing and review only; copying, modifying, redistributing, or publishing apps derived from it requires written permission. See [LICENSE](LICENSE). The Esplitealo and Chavito names, logo, wordmark and mascot artwork are not licensed.

## Third-party notices

Third-party components (the Unkempt font, the agent skills under `.claude/skills`, and test-only Swift packages) keep their own licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
