# Continuous integration

GitHub Actions workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull request targeting `main` and on pushes to `main`.

## What runs

| Check | Required on PRs | What it does |
| ----- | --------------- | ------------ |
| **CI / macOS** | Yes | `swift build` and `swift test` on a `macos-26` runner with **Xcode 26.3** (`/Applications/Xcode_26.3.app`). Vision end-to-end OCR tests are skipped via `ESPLITEALO_SKIP_VISION_INTEGRATION=1` (see [SCANNING.md](SCANNING.md)). The job id and name stay `macOS` so the required check keeps its name. |
| **CI / iOS Simulator tests** | No (not in branch protection; a failure still turns the run red) | `xcodebuild test` of the `EsplitealoCore-Package` scheme on an iPhone simulator running an **iOS 18.x** runtime, picked by [`Scripts/ios-simulator-udid.sh`](../Scripts/ios-simulator-udid.sh). Runs every package test target on iOS. The Vision end-to-end tests skip themselves there because the synthetic receipt images need AppKit. |
| **CI / Vision integration** | No (`continue-on-error`) | Same toolchain; runs `ReceiptScannerVisionTests` (real Vision OCR on synthetic receipt images). May flake on hosted runners; failures do not block merge. |
| **CI / iOS Capture compile** | No (`continue-on-error`) | `xcodebuild build` for the `EsplitealoCapture` scheme (generic iOS Simulator destination) and for the Scanner Lab app project (generic iOS destination), both with no code signing. Informational compile check for the UIKit/VisionKit capture code and the lab app. |

Superseded workflow runs for the same branch are cancelled via a concurrency group.

## Run the same checks locally

Requires Xcode 26.3 (Swift 6.2; `Package.swift` uses swift-tools-version 6.0). CI pins Xcode 26.3 because it is the last Xcode that runs on macOS 15, and App Store uploads need Xcode 26 or later.

```bash
swift build
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test
```

Optional (Vision integration):

```bash
swift test --filter ReceiptScannerVisionTests
```

Optional (package tests on an iOS 18 simulator; needs an iOS 18.x simulator runtime installed):

```bash
xcodebuild test \
  -scheme EsplitealoCore-Package \
  -destination "platform=iOS Simulator,id=$(Scripts/ios-simulator-udid.sh 18)" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
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

Jobs use **GitHub-hosted macOS** runners. On **private** repositories, hosted macOS minutes cost far more than Linux minutes (about $0.062 against $0.006 per minute in 2026), and each job is rounded up to whole minutes. Keep jobs short and keep optional jobs optional.
