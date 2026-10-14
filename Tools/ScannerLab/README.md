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

## Command-line build (no signing)

From the repository root, compile-check for a physical device (matches CI):

```bash
Tools/ScannerLab/build-generic-ios.sh
```

Simulator (no signing):

```bash
xcodebuild build \
  -project Tools/ScannerLab/ScannerLab.xcodeproj \
  -scheme ScannerLab \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

For a **connected iPhone** with your team (does not commit any team ID):

```bash
Tools/ScannerLab/build-device.sh YOUR_TEAM_ID
```

Optional second argument is the device name as shown in Xcode’s device menu.

## Troubleshooting

### Swift compile error in `ContentView.swift` (`missing argument label 'amount:'`)

**Symptom:** Xcode or `xcodebuild` fails while compiling `ContentView.swift` with:

```text
error: missing argument label 'amount:' in call
```

**Fix:** Use a current `main` branch (fixed in repo). Locally, `totalRow` calls must pass the second argument as `amount:`, for example `totalRow("Subtotal", amount: display.subtotal)`.

**Verify without signing:**

```bash
Tools/ScannerLab/build-generic-ios.sh
```

### Signing and provisioning (owner-only)

The repository intentionally has **no** development team. You must set these in Xcode for the **ScannerLab** target:

1. **Signing & Capabilities** → **Team** → your Apple ID team.
2. **Bundle Identifier** → unique under your account (for example `com.yourname.esplitealo.ScannerLab`).

**Developer Mode (iOS 16+):** On the iPhone, **Settings → Privacy & Security → Developer Mode** → on, then restart when prompted. Without this, device installs from Xcode often fail.

**Trust the developer certificate:** After first install, **Settings → General → VPN & Device Management** → your developer app → **Trust**.

**Free Apple ID:** Provisioning profiles expire after about **7 days**; rebuild and reinstall when Xcode reports an expired profile.

**Command-line device build** (paste failures back to the team):

```bash
Tools/ScannerLab/build-device.sh YOUR_TEAM_ID "Your iPhone Name"
```

If signing still fails, copy the **full** `xcodebuild` output from the first `error:` line through the final `** BUILD FAILED **` block (include any `Provisioning profile` / `Signing for` lines).

### Deployment target

The app target uses **iOS 18.0** (`IPHONEOS_DEPLOYMENT_TARGET`), the same minimum as the package. Your phone must run iOS 18 or newer (every iPhone that runs iOS 17 can run iOS 18).

### Package plugins

If SwiftPM asks about plugin trust, the project build uses `-skipPackagePluginValidation` (same as the scripts above).

## Unit tests (logic without camera UI)

The formatting, JSON export, error messages, and pipeline runner live in the **ScannerLabKit** Swift package target and are covered by `ScannerLabKitTests` on macOS:

```bash
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test --filter ScannerLabKitTests
```

**Verified in CI / on Mac:** package tests including ScannerLabKit; optional iOS Capture compile job for `EsplitealoCapture` only.

**Not verified here (owner on device):** document camera quality, real Vision OCR on paper receipts, Photos picker edge cases, and share sheet delivery to other apps.

## CI note

The required **macOS** job runs `swift test` only. The optional **iOS Capture compile** job (non-blocking) also runs `Tools/ScannerLab/build-generic-ios.sh` logic so Scanner Lab compile errors are caught without slowing the main check.
