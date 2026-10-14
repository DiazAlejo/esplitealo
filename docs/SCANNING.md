# Receipt scanning

On-device path from a receipt photo to the parser’s `RecognizedText` and a reconciliation-bearing `ReceiptDraft`. SwiftUI capture screens are out of scope; this module supplies the service and a thin capture bridge for later UI.

## Pipeline

```
CGImage (+ orientation)
    → ReceiptScanner (Vision VNRecognizeTextRequest, .accurate)
    → RecognizedText (pixel boxes, top-left origin)
    → ReceiptParser
    → ReceiptDraft (items, totals, reconciles)
```

`ReceiptScanPipeline.scan` performs the full chain and returns `ReceiptScanResult` (`recognizedText` + `draft`).

## OCR (`EsplitealoCore`)

| Setting | Value |
| ------- | ----- |
| Request | `VNRecognizeTextRequest`, revision 3 |
| Level | `.accurate` |
| Language correction | on (default) |
| Languages | `["es-ES", "en-US"]` (Spanish first, English second) |

On macOS 15 / iOS 17-class SDKs, `.accurate` supports `es-ES` and `en-US` among others; Puerto Rican Spanish uses `es-ES` (there is no separate `es-MX` or `es-PR` code in Vision’s supported list). `ReceiptScanner.defaultRecognitionLanguages` documents the default.

No image preprocessing is applied. Word boxes come from each top candidate’s per-word `boundingBox(for:)`. Line baseline angle is derived from observation corners.

## Errors (`ReceiptScanError`)

| Case | When |
| ---- | ---- |
| `noTextFound` | No observations / empty lines after OCR |
| `imageTooSmallOrUnreadable` | Image under 64×64 px, or median word height below ~12 px (accuracy breaks near 13 px; quality degrades below ~20 px per OCR research) |
| `receiptTooLongForSinglePhoto` | Height ÷ width exceeds 4 (one-photo MVP; very tall receipts need multiple captures later) |

Inject `TextRecognizing` stubs in unit tests for error paths.

## Capture bridge (`EsplitealoCapture`, iOS only)

| Piece | Role |
| ----- | ---- |
| `DocumentCameraBridge` | `VNDocumentCameraViewController` wrapper; multi-page scans rejected with `DocumentCameraError.tooManyPages`; cancel / failure as `DocumentCameraError` |
| `PhotoImportBridge` | `PhotosPicker` + EXIF-upright `CGImage` via ImageIO thumbnail transform |
| `CameraPermission` | Maps `AVCaptureDevice` video authorization without prompting until `requestAccessIfNeeded()` |

Compiled only on iOS (`#if canImport(UIKit)` / VisionKit / PhotosUI). macOS `swift test` does not link camera UI.

## Verification

| Checked here | Device-only |
| ------------ | ----------- |
| `swift test` on Mac: policy stubs, Vision E2E on synthetic receipts (PR IVU, English diner, comma-decimal café, skewed PR) | Real `VNDocumentCameraViewController` quality, torch, auto-shutter |
| `ReceiptScannerVisionTests` (set `ESPLITEALO_SKIP_VISION_INTEGRATION=1` to skip flaky CI hosts) | Physical iPhone camera |
| iOS simulator compile of `EsplitealoCapture` (see task notes) | PhotosPicker on device |

Parser and calculator behavior are unchanged; tests replay JSON fixtures under `Tests/Fixtures/Receipts/` without Vision.
