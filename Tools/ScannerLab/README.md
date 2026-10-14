# Scanner Lab

Developer-only iOS utility to exercise Esplitealo’s on-device receipt OCR and parsing on a physical iPhone. It is not the production SwiftUI app and uses plain system styling.

## Open and run on your iPhone

1. Open `Tools/ScannerLab/ScannerLab.xcodeproj` in Xcode 16.4 or newer.
2. Select the **ScannerLab** scheme and your connected iPhone (or a simulator).
3. In the **ScannerLab** target → **Signing & Capabilities**:
   - Choose your **Team** (leave the repository without a team ID).
   - Change **Bundle Identifier** from `com.esplitealo.ScannerLab` to something unique under your Apple ID (for example `com.yourname.esplitealo.ScannerLab`).
4. Build and run (⌘R). On first install, on the device go to **Settings → General → VPN & Device Management** and trust your developer certificate.
5. When prompted, allow **Camera** and **Photos** access (usage strings are localized in English and Spanish via `Info.plist` and `InfoPlist.strings`).

## What it does

- **Scan with document camera** — `VNDocumentCameraViewController` via `EsplitealoCapture`.
- **Choose photo** — photo library import with EXIF orientation applied.
- Shows a thumbnail and pipeline output: OCR lines, rebuilt rows, parsed items, totals, reconciliation, issues, OCR timing, copy full JSON, share recognized-text JSON for fixtures.

All processing stays on device; no network or analytics.

## Command-line build (simulator, no signing)

From the repository root:

```bash
xcodebuild build \
  -project Tools/ScannerLab/ScannerLab.xcodeproj \
  -scheme ScannerLab \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

## Unit tests (logic without camera UI)

The formatting, JSON export, error messages, and pipeline runner live in the **ScannerLabKit** Swift package target and are covered by `ScannerLabKitTests` on macOS:

```bash
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test --filter ScannerLabKitTests
```

**Verified in CI / on Mac:** package tests including ScannerLabKit; optional iOS Capture compile job for `EsplitealoCapture` only.

**Not verified here (owner on device):** document camera quality, real Vision OCR on paper receipts, Photos picker edge cases, and share sheet delivery to other apps.

## CI note

The GitHub **macOS** job runs `swift test` and does not build the Xcode app target. The Scanner Lab project is intentionally outside the required CI path so the main package check stays fast.
