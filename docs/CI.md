# Continuous integration

GitHub Actions workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull request targeting `main` and on pushes to `main`.

## What runs

| Check | Required on PRs | What it does |
| ----- | --------------- | ------------ |
| **CI / macOS** | Yes | `swift build` and `swift test` on a `macos-26` runner with **Xcode 26.3** (`/Applications/Xcode_26.3.app`). Vision end-to-end OCR tests are skipped via `ESPLITEALO_SKIP_VISION_INTEGRATION=1` (see [SCANNING.md](SCANNING.md)). The job id and name stay `macOS` so the required check keeps its name. |
| **CI / iOS Simulator tests** | No (not in branch protection; a failure still turns the run red) | `xcodebuild test` of the `EsplitealoCore-Package` scheme on an iPhone simulator running an **iOS 18.x** runtime, picked by [`Scripts/ios-simulator-udid.sh`](../Scripts/ios-simulator-udid.sh). Runs every package test target on iOS. The Vision end-to-end tests skip themselves there because the synthetic receipt images need AppKit. |
| **CI / iOS App** | No (not in branch protection; runs only after the required macOS job passes) | `xcodebuild build` of `App/Esplitealo.xcodeproj` (scheme `Esplitealo`) for an iOS 18.x simulator with `CODE_SIGNING_ALLOWED=NO`, then `xcodebuild test -only-testing:EsplitealoTests` (BillStore, routes, compiled strings, design-system **snapshot tests**), then the XCUITest smoke tests (`EsplitealoUITests`) as a `continue-on-error` step, since launching an app in a simulator is the flakiest part. swift-snapshot-testing (test-only) is cached between runs. Snapshot references are recorded on iOS 18.6, so the job uses the iOS 18 runtime like the job above. See [APP.md](APP.md). |
| **CI / Linux Core build** | No (`continue-on-error`) | `swift build --target EsplitealoCore` in a `swift:6.0` container on Linux (about $0.006 per minute). Proves the Foundation-only core still builds without Apple frameworks, which keeps Android possible later. Only the build runs: the package test build compiles every target, and most of them import Apple frameworks, so core tests run on macOS and the iOS simulator. |
| **CI / Vision integration** | No (`continue-on-error`) | Same toolchain; runs `ReceiptScannerVisionTests` (real Vision OCR on synthetic receipt images). May flake on hosted runners; failures do not block merge. |
| **CI / iOS Capture compile** | No (`continue-on-error`) | `xcodebuild build` for the `EsplitealoCapture` scheme (generic iOS Simulator destination) and for the Scanner Lab app project (generic iOS destination), both with no code signing. Informational compile check for the UIKit/VisionKit capture code and the lab app. |

The required **macOS** job also runs `Tests/AppResourceTests`, which read the app's string catalogs, xcconfig files, privacy manifest and icon as text: a missing Spanish or English translation, a committed team id, or a photo-library permission fails the required check in seconds, without a simulator.

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

Optional (the app: build, unit and snapshot tests, UI smoke tests; see [APP.md](APP.md)):

```bash
UDID=$(Scripts/ios-simulator-udid.sh 18)
xcodebuild test -project App/Esplitealo.xcodeproj -scheme Esplitealo \
  -only-testing:EsplitealoTests \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO
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

The iOS App job adds roughly 8 to 15 billable macOS minutes per run (build, tests, and the first run's iOS 18 runtime download), so it stays optional and runs only after the required job passes. Jobs use **GitHub-hosted macOS** runners. On **private** repositories, hosted macOS minutes cost far more than Linux minutes (about $0.062 against $0.006 per minute in 2026), and each job is rounded up to whole minutes. Keep jobs short and keep optional jobs optional.
