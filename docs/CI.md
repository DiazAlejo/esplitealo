# Continuous integration

GitHub Actions workflow [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull request targeting `main` and on pushes to `main`. The repository is public, so GitHub's macOS runners are free: **CI is where the iOS simulator tests run.** Running them on the owner's Mac is optional and discouraged (it fills the disk).

## The supported workflow

1. Write the tests and the code. Run `swift test` locally (fast, no simulator): it covers Core, Design, the string catalogs and the app resources.
2. Push the branch. CI builds the app and runs the whole app test plan on a hosted iOS 18 simulator.
3. Read the result: `gh run view --log-failed -R DiazAlejo/esplitealo` or, for the latest run of the current branch, [`Scripts/ci-logs.sh`](#reading-a-failed-run). Fix, push, repeat.
4. New or intentionally changed snapshots: record them on CI with the [Record snapshots](#record-snapshots) workflow, never on a Mac.

Do not run `xcodebuild` on a simulator locally unless you have a reason; there is no step in the workflow that needs it.

## What runs

| Check | Required on PRs | What it does |
| ----- | --------------- | ------------ |
| **CI / macOS** | Yes (required status check on `main`) | `swift build` and `swift test` on a `macos-26` runner with **Xcode 26.3** (`/Applications/Xcode_26.3.app`). Vision end-to-end OCR tests are skipped via `ESPLITEALO_SKIP_VISION_INTEGRATION=1` (see [SCANNING.md](SCANNING.md)). The job id and name stay `macOS` so the required check keeps its name; do not rename it. |
| **CI / iOS Simulator tests** | No (not in branch protection; a failure still turns the run red) | `xcodebuild test` of the `EsplitealoCore-Package` scheme on an iPhone simulator running an **iOS 18.x** runtime, picked by [`Scripts/ios-simulator-udid.sh`](../Scripts/ios-simulator-udid.sh). Runs every package test target on iOS. The Vision end-to-end tests skip themselves there because the synthetic receipt images need AppKit. On failure the `.xcresult` bundle is uploaded as an artifact. |
| **CI / iOS App** | No (not in branch protection; runs only after the required macOS job passes) | The whole test plan of the `Esplitealo` scheme (`App/Esplitealo.xcodeproj`) on an iOS 18.x simulator with `CODE_SIGNING_ALLOWED=NO`: `build-for-testing`, then `EsplitealoTests` (BillStore, routes, compiled strings, design-system and screen **snapshot tests**), then `EsplitealoUITests` (the XCUITest smoke and flow tests). The UI tests run even when the unit tests failed, are retried once on failure, and **fail the job** like any other test. Each step writes an `.xcresult`, prints the failed tests at the end of its log, and the bundles are uploaded as the `ios-app-xcresults` artifact when anything fails. Snapshot references are recorded on iOS 18.6, so the job uses the iOS 18 runtime. See [APP.md](APP.md). |
| **CI / iOS Release build** | No (not in branch protection; runs only after the required macOS job passes) | `xcodebuild build` of the `Esplitealo` scheme with `-configuration Release` for `generic/platform=iOS` and `CODE_SIGNING_ALLOWED=NO`. Release is what Archive, TestFlight and the App Store use, and it type-checks code that Debug simulator builds do not (for example `#Preview` blocks that call `#if DEBUG` helpers), so this keeps it from regressing. No simulator and no tests: a few minutes. |
| **CI / Linux Core build** | No (`continue-on-error`) | `swift build --target EsplitealoCore` in a `swift:6.0` container on Linux . Proves the Foundation-only core still builds without Apple frameworks, which keeps Android possible later. Only the build runs: the package test build compiles every target, and most of them import Apple frameworks, so core tests run on macOS and the iOS simulator. |
| **CI / Reference calculator** | No (`continue-on-error`) | Runs the Python reference calculator's own tests and checks that the committed corpus `Tests/Fixtures/CalculatorProof/reference-corpus-300.json` is what its generator writes, on `ubuntu-latest` (a few seconds). The Swift comparison with that corpus runs in the required macOS job as part of `swift test`. See [CALCULATOR_PROOF.md](CALCULATOR_PROOF.md). |
| **CI / Vision integration** | No (`continue-on-error`) | Same toolchain; runs `ReceiptScannerVisionTests` (real Vision OCR on synthetic receipt images). May flake on hosted runners; failures do not block merge. |
| **CI / iOS Capture compile** | No (`continue-on-error`) | `xcodebuild build` for the `EsplitealoCapture` scheme (generic iOS Simulator destination) and for the Scanner Lab app project (generic iOS destination), both with no code signing. Informational compile check for the UIKit/VisionKit capture code and the lab app. |

The required **macOS** job also runs `Tests/AppResourceTests`, which parse the app's string catalogs, Xcode project, xcconfig files, privacy manifest and icon: a missing Spanish or English translation, a committed team id, or a photo-library permission fails the required check in seconds, without a simulator.

Superseded workflow runs for the same branch are cancelled via a concurrency group.

The macOS, iOS Simulator tests and iOS App jobs together run every test in the repository: `swift test` (Core, Design, resources, scanning logic), the package tests on the iOS simulator, and the app's unit, snapshot and UI tests. Vision integration and the iOS Capture compile are extra, informational jobs. A new test target in the Xcode project is not picked up by the iOS App job by itself: add it to the job's `-only-testing` steps.

## Reading a failed run

Every `xcodebuild` step goes through [`Scripts/ci-xcodebuild.sh`](../Scripts/ci-xcodebuild.sh), which writes a result bundle and, after the raw xcodebuild output, prints a short summary built by [`Scripts/xcresult-summary.sh`](../Scripts/xcresult-summary.sh):

```text
== Test result summary (app-ui.xcresult)
Result: Failed  (passed 12, failed 1, skipped 0, expected failures 0, total 13)
Device: iPhone 16 (iOS Simulator 18.6)

Failed tests (1):
- SmokeTests/testLaunchesToHome() [EsplitealoUITests]
    Failed to find element "home.scan" ...
```

The same text is on the run's summary page. To read it from a terminal:

```bash
Scripts/ci-logs.sh                 # latest CI run of the current branch: job states, then the failed steps' logs (last 300 lines)
Scripts/ci-logs.sh --wait          # wait for a run that is still going
Scripts/ci-logs.sh -n 0            # the whole failed log
gh run view --log-failed -R DiazAlejo/esplitealo        # the plain gh command (run id optional)
```

The script exits 0 when the run passed, 1 when it failed, 2 when it has not finished or there is no run. If the summary is not enough (a UI test screenshot, a snapshot diff), download the bundle and open it on a Mac with Xcode:

```bash
gh run download <run-id> -R DiazAlejo/esplitealo -n ios-app-xcresults
open ios-app-xcresults/app-ui.xcresult
```

The scripts are tested without a runner or Xcode by `Scripts/tests/ci-scripts-test.sh` (stub `gh`, `xcrun` and `xcodebuild`).

## Record snapshots

Snapshot references are PNGs in `App/SnapshotReferences`. They only match CI when CI's own runner and simulator rendered them, so **always record them on CI, never on a Mac**. The [Record snapshots](../.github/workflows/record-snapshots.yml) workflow does that on the same Xcode, iOS 18 runtime and iPhone model as the iOS App job (both use [`.github/actions/setup-ios-simulator`](../.github/actions/setup-ios-simulator/action.yml)).

Start it from a pushed branch (not `main`; the workflow itself always comes from `main`, so it exists only after this change has been merged):

```bash
gh workflow run record-snapshots.yml -R DiazAlejo/esplitealo --ref main -f branch=<your-branch>                # artifact only
gh workflow run record-snapshots.yml -R DiazAlejo/esplitealo --ref main -f branch=<your-branch> -f commit=true # also commit to the branch
gh run watch -R DiazAlejo/esplitealo                                                                          # pick the run to follow
```

| Input | Meaning |
| ----- | ------- |
| `branch` (required) | Branch to check out and record on. |
| `mode` | `missing` (default): record only references that do not exist yet, for new snapshot tests. `failed`: re-record the references that differ, for an intended visual change. `all`: re-record everything. |
| `commit` | `false` (default): only upload the artifact. `true`: push the references to the branch as a commit authored by `DiazAlejo` (the GitHub noreply address). |

The run builds the app tests, records, then **runs the snapshot tests again in compare mode**; the workflow fails if the recorded references do not pass, so what it uploads or commits is proven to match this simulator. The step summary lists the new and changed PNGs. To use them without `commit`:

```bash
gh run download <run-id> -R DiazAlejo/esplitealo -n snapshot-references -D App/SnapshotReferences
git status App/SnapshotReferences    # look at the new images before committing them
```

With `commit=true` the commit lands on the branch: `git pull` it. Commits pushed with the built-in token do not trigger other workflows, so CI does not start on that commit by itself and a pull request would show no checks for it. Push any follow-up commit, or close and reopen the pull request, to run CI. Always look at the recorded images: a verified reference proves the app renders that way, not that it renders correctly.

Security: the workflow has no secrets and no `pull_request_target`. The job that builds and runs the branch's code has a read-only token. A second job, which runs nothing from the branch, is the only one with `contents: write`, and it refuses the default branch and a branch that moved while recording.

## Caching and cleanup

- **Cached**: SwiftPM for the package jobs (keyed by the sources, as before) and the app's downloaded package checkouts (`.spm`, keyed by `Package.resolved`, so a hit holds exactly the pinned versions). Package downloads are the only thing that is cached for the app.
- **Never cached**: DerivedData and build output. Every app build starts from scratch, so a stale cache can never make a test pass or fail. The `xcodebuild` steps build into `$RUNNER_TEMP/DerivedData`.
- **Cleanup**: each simulator job ends with a step that always runs and deletes DerivedData and the result bundles (and shuts the simulators down), after the bundles were uploaded.
- **Artifacts** are kept for 7 days (snapshot references: 14) and only uploaded when something failed or, for Record snapshots, when something changed.

## Run the same checks locally

Requires Xcode 26.3 (Swift 6.2; `Package.swift` uses swift-tools-version 6.0). CI pins Xcode 26.3 because it is the last Xcode that runs on macOS 15, and App Store uploads need Xcode 26 or later.

```bash
swift build
ESPLITEALO_SKIP_VISION_INTEGRATION=1 swift test
```

Optional (full calculator proof: reference tests, then 5,000 generated bills against the Swift engine; needs Python 3):

```bash
Scripts/prove-calculator.sh
```

Optional (Vision integration):

```bash
swift test --filter ReceiptScannerVisionTests
```

Optional and discouraged, because simulators and DerivedData fill the Mac's disk (CI runs all of the following for you; see [the supported workflow](#the-supported-workflow)). The package tests on an iOS 18 simulator need an iOS 18.x simulator runtime installed:

```bash
xcodebuild test \
  -scheme EsplitealoCore-Package \
  -destination "platform=iOS Simulator,id=$(Scripts/ios-simulator-udid.sh 18)" \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO
```

Optional and discouraged (the app: build, unit and snapshot tests, UI smoke tests; see [APP.md](APP.md); never record snapshot references this way):

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

## Security and supply chain

- The workflows set `permissions: contents: read` at the top (only the commit job of Record snapshots has `contents: write`), use no secrets, and never use `pull_request_target`, so pull requests from forks run with a read-only token.
- Third-party actions are pinned to full commit SHAs (with the tag in a trailing comment). [Dependabot](../.github/dependabot.yml) proposes weekly updates for GitHub Actions and Swift packages.

## Billing note

The repository is public, so GitHub-hosted standard runners (macOS and Linux) are free and unmetered for it. Keep jobs short anyway: the iOS App job takes roughly 8 to 15 minutes per run (build, tests, and the first run's iOS 18 runtime download), which is why it stays optional and runs only after the required job passes. If the repository ever becomes private again, hosted macOS minutes are billed at a much higher rate than Linux minutes, so keep optional jobs optional.
