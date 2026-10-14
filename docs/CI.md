# Continuous integration

GitHub Actions workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull request targeting `main` and on pushes to `main`.

## What runs

| Check | Required on PRs | What it does |
| ----- | --------------- | ------------ |
| **CI / macOS** | Yes | `swift build` and `swift test` on a `macos-15` runner with **Xcode 16.4** (`/Applications/Xcode_16.4.app`). Vision end-to-end OCR tests are skipped via `ESPLITEALO_SKIP_VISION_INTEGRATION=1` (see [SCANNING.md](SCANNING.md)). |
| **CI / Vision integration** | No (`continue-on-error`) | Same toolchain; runs `ReceiptScannerVisionTests` (real Vision OCR on synthetic receipt images). May flake on hosted runners; failures do not block merge. |
| **CI / iOS Capture compile** | No (`continue-on-error`) | `xcodebuild build` for the `EsplitealoCapture` scheme with a generic iOS Simulator destination and no code signing. Informational compile check for UIKit/VisionKit capture code. |

Superseded workflow runs for the same branch are cancelled via a concurrency group.

## Run the same checks locally

Requires Xcode 16.4+ (Swift 6 toolchain; `Package.swift` uses swift-tools-version 6.0 and targets macOS 14 / iOS 17).

```bash
swift build
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test
```

Optional (Vision integration):

```bash
swift test --filter ReceiptScannerVisionTests
```

Optional (iOS Capture compile):

```bash
xcodebuild build \
  -scheme EsplitealoCapture \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

## Billing note

Jobs use **GitHub-hosted macOS** runners. On **private** repositories, macOS runner minutes are billed at **10×** the rate of Linux minutes. A typical PR run is a few minutes of macOS time (often shown as billable minutes on the workflow run summary).
