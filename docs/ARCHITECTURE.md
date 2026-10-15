# Architecture

Keep the code organized around the core domain logic so the calculation engine can be tested independently of the interface.

## Swift package (SwiftPM)

The logic lives in a Swift package at the repository root, so `swift test` runs on the Mac without the Xcode app target. The package minimum is **iOS 18 / macOS 15**. The package is split by what each part may import:

| Target | Imports | Holds |
| ------ | ------- | ----- |
| `EsplitealoCore` | **Foundation only** | Models, receipt parsing, `BillSession` and its JSON/draft storage, `BillCalculator`. Portable: it must keep building without Apple frameworks (Linux today, Android later). `CorePortabilityTests` fails the build if a Core source imports anything but Foundation. |
| `EsplitealoScanning` | Vision, CoreGraphics, ImageIO | `ReceiptScanner`, `VisionTextRecognizer` (async `RecognizeTextRequest`), `ReceiptScanPipeline`, `ReceiptImageValidator`, `ReceiptScanError`. |
| `EsplitealoCapture` | UIKit, VisionKit, PhotosUI, AVFoundation | Document camera, photo import, camera permission bridges (iOS only). |
| `OCRBenchmarkKit` + `EsplitealoOCRBenchmark` | CoreGraphics, AppKit (synthetic images) | Developer-only OCR benchmark library and its command-line executable. The app never links them. |
| `ScannerLabKit` | Core, Scanning | Logic for the Scanner Lab developer app. |
| `EsplitealoDesign` | SwiftUI, CoreText | The design system: colour tokens, person colours, type scale, money formatter, buttons, cards, avatars, headers, the bundled Unkempt font; and the Chavito mascot (`ChavitoView`, expressions, pink disc, motion, accessibility labels) with its SVG/PDF export code. Depends on no other target; reference exports live in `design/brand/chavito/`. See [APP.md](APP.md). |
| `EsplitealoTestSupport` | Core | Test helpers shared by test targets (not a product). |

Dependencies point one way: `EsplitealoCore` ← `EsplitealoScanning` ← `OCRBenchmarkKit` / `ScannerLabKit`. Nothing in `EsplitealoCore` may import a scanning, capture or benchmark target.

```
.
├── Package.swift
├── Sources/
│   ├── EsplitealoCore/            # Foundation only
│   │   ├── Models/                # Receipt, ReceiptItem, Participant, ItemAssignment, RecognizedText, ReceiptDraft
│   │   ├── ReceiptParsing/        # RowBuilder, AmountToken, ReceiptParser
│   │   ├── BillSession/           # BillSession (+ Codable), BillDraftStore, ShareSummaryBuilder, ...
│   │   └── Services/              # BillCalculator
│   ├── EsplitealoScanning/        # Vision and image handling
│   ├── EsplitealoCapture/         # UIKit / VisionKit / PhotosUI bridges
│   ├── OCRBenchmarkKit/           # benchmark library
│   ├── EsplitealoOCRBenchmark/    # benchmark executable (EsplitealoOCRBenchmarkCLI.swift)
│   ├── EsplitealoDesign/          # design system and Chavito in SwiftUI (no dependencies); exports in design/brand/chavito
│   └── ScannerLabKit/
├── Tests/
│   ├── EsplitealoCoreTests/  EsplitealoScanningTests/  EsplitealoCaptureTests/  EsplitealoDesignTests/  AppResourceTests/
│   ├── OCRBenchmarkKitTests/  ScannerLabKitTests/  EsplitealoTestSupport/
│   └── Fixtures/                  # Receipts/ (parser) and BillSessions/ (stored JSON format)
└── Tools/ScannerLab/              # Scanner Lab Xcode project; see its README
```

Tests run with `swift test` on the Mac and with `xcodebuild test -scheme EsplitealoCore-Package` on an iOS 18 simulator (see [CI](CI.md)). The executable's entry file is named `EsplitealoOCRBenchmarkCLI.swift`, not `main.swift`: a file called `main.swift` that also uses `@main` breaks `xcodebuild` for iOS destinations.

The Xcode app embeds `EsplitealoCore`, `EsplitealoDesign`, `EsplitealoScanning` and `EsplitealoCapture`.

## The app

The app is a thin hand-kept Xcode project (`App/Esplitealo.xcodeproj`, synchronized folders, all build settings in `App/Config/*.xcconfig`) that depends on the package above and keeps all screens and glue code in the app target:

```
App/
├── Esplitealo.xcodeproj          # app, unit/snapshot test and UI test targets
├── Config/*.xcconfig             # build settings as text (bundle id, iOS 18, Swift 6, actor isolation)
├── Esplitealo/
│   ├── EsplitealoApp.swift       # entry point
│   ├── Navigation/               # AppRoute (six screens), AppRouter, RootView
│   ├── Store/                    # BillStore (autosaves via BillDraftStore), DraftLocation
│   ├── Features/                 # Home, Capture, ReceiptReview, Participants, Assignment, Summary
│   ├── Support/                  # SampleBill for previews and tests
│   └── Resources/                # string catalogs, assets, privacy manifest, layered icon
├── EsplitealoTests/              # unit and snapshot tests (Swift Testing, swift-snapshot-testing)
├── EsplitealoUITests/            # XCUITest smoke tests
└── SnapshotReferences/           # recorded snapshot PNGs
```

[APP.md](APP.md) is the guide for building a screen: design system, state, strings, tests, signing.

## Technology

| Concern | Choice |
| ------- | ------ |
| UI and navigation | SwiftUI |
| Minimum OS | iOS 18 (async Vision API; same iPhones as iOS 17) |
| Text recognition | Vision `RecognizeTextRequest`, on-device |
| Capture and import | AVFoundation and PhotosUI |
| Calculation | `BillCalculator`, pure logic, integer cents, unit-tested |
| State | Active bill kept in memory and autosaved as a Codable JSON draft (`BillDraftStore`), deleted when the bill is finished. No database; "recent bills", if added, are JSON files |
| Backend | None for the MVP |

## Notes

- Vision recognizes text, but it does not understand the structure of every receipt. `ReceiptParser` makes conservative guesses, and the review screen handles uncertainty.
- `BillCalculator` has no UI or framework dependencies beyond Foundation, so it can be tested in isolation.
- `ReceiptScanner` (in `EsplitealoScanning`) wraps Vision and `ReceiptParser` (in `EsplitealoCore`) turns its output into a draft `Receipt`, so parsing can be tested against recorded text without the camera.
- `BillSession` sits on an editable `ReceiptDraft`, participants, and assignments, then calls `BillCalculator` and builds share text. See [Bill session](BILL_SESSION.md).
- The module is named `Esplitealo` (no accent) for tooling compatibility. The user-facing app name is Esplitéalo.
