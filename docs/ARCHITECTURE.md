# Architecture

Keep the code organized around the core domain logic so the calculation engine can be tested independently of the interface.

## Calculation package (SwiftPM)

The calculation engine lives in a Swift package at the repository root so `swift test` can run on the Mac without the Xcode app target:

```
EsplitealoCore/                    # Swift package root (Package.swift)
├── Sources/EsplitealoCore/
│   ├── Models/
│   │   ├── Receipt.swift
│   │   ├── ReceiptItem.swift
│   │   ├── Participant.swift
│   │   ├── ItemAssignment.swift
│   │   ├── RecognizedText.swift
│   │   └── ReceiptDraft.swift
│   ├── ReceiptParsing/
│   │   ├── RowBuilder.swift
│   │   ├── AmountToken.swift
│   │   └── ReceiptParser.swift
│   ├── Scanning/
│   │   ├── ReceiptScanner.swift
│   │   ├── VisionTextRecognizer.swift
│   │   └── ReceiptScanPipeline.swift
│   └── Services/
│       └── BillCalculator.swift
├── Sources/EsplitealoCapture/       # iOS capture bridge (VisionKit, PhotosUI)
│   └── Capture/
└── Tests/EsplitealoCoreTests/
    ├── BillCalculatorTests.swift
    ├── ReceiptParsing/
    └── Fixtures/Receipts/
```

The Xcode app will embed this library later. File names match the planned app layout below.

## Planned layout

```
Esplitealo/
├── App/
│   └── EsplitealoApp.swift
├── Models/
│   ├── Receipt.swift
│   ├── ReceiptItem.swift
│   ├── Participant.swift
│   └── ItemAssignment.swift
├── Services/
│   ├── ReceiptScanner.swift
│   ├── ReceiptParser.swift
│   └── BillCalculator.swift
├── Features/
│   ├── Home/
│   ├── Capture/
│   ├── ReceiptReview/
│   ├── Participants/
│   ├── Assignment/
│   └── Summary/
└── Tests/
    ├── BillCalculatorTests.swift
    └── ReceiptParserTests.swift
```

## Technology

| Concern | Choice |
| ------- | ------ |
| UI and navigation | SwiftUI |
| Text recognition | Vision, on-device |
| Capture and import | AVFoundation and PhotosUI |
| Calculation | `BillCalculator`, pure logic, integer cents, unit-tested |
| State | Active bill in memory at first; SwiftData for saved bills if the schedule allows |
| Backend | None for the MVP |

## Notes

- Vision recognizes text, but it does not understand the structure of every receipt. `ReceiptParser` makes conservative guesses, and the review screen handles uncertainty.
- `BillCalculator` has no UI or framework dependencies beyond Foundation, so it can be tested in isolation.
- `ReceiptScanner` wraps Vision and `ReceiptParser` turns its output into a draft `Receipt`, so parsing can be tested against recorded text without the camera.
- The module is named `Esplitealo` (no accent) for tooling compatibility. The user-facing app name is Esplitéalo.
