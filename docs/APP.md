# The iOS app

How the Esplitéalo app is put together, how to add a screen, and how to run its tests. Read this before you build a screen. It is written for people and for coding assistants: every rule here is checked by a test or a build, not by trust.

## Layout

```text
Package.swift                     the local Swift package (logic, scanning, capture, design system)
Sources/EsplitealoDesign/         the SwiftUI design system (tokens, type, money, components, Unkempt)
App/
├── Esplitealo.xcodeproj          thin, hand-kept project; synchronized folders; no build settings of its own
├── Config/*.xcconfig             every build setting (bundle id, iOS 18, Swift 6, actor isolation, Info.plist keys)
├── Esplitealo/                   the app target (a synchronized folder: add a file and it is in the target)
│   ├── EsplitealoApp.swift       entry point, builds the BillStore and the router
│   ├── Navigation/               AppRoute (the six screens), AppRouter, RootView (stack and resume prompt)
│   ├── Store/                    BillStore (autosaved bill in progress), DraftLocation
│   ├── Features/<Screen>/        Home, Capture, ReceiptReview, Participants, Assignment, Summary, Shared
│   ├── Support/SampleBill.swift  the mockups' Fonda Doña Lola bill, for previews and tests
│   └── Resources/                Localizable.xcstrings, InfoPlist.xcstrings, PrivacyInfo.xcprivacy,
│                                 Assets.xcassets (AccentColor), Esplitealo.icon (layered app icon)
├── EsplitealoTests/              unit and snapshot tests, hosted in the app (Swift Testing)
├── EsplitealoUITests/            XCUITest smoke tests
└── SnapshotReferences/           recorded snapshot PNGs (outside the synchronized folders on purpose)
Tests/AppResourceTests/           `swift test` checks of the string catalogs, xcconfig files, manifest and icon
```

The package has zero runtime dependencies, and so has the app. The only third-party code is [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing), linked into the **test target only** and pinned to an exact version in the Xcode project (not in `Package.swift`, so `swift build`, `swift test` and the Linux job never fetch it).

### What may import what

| Module | May import | Notes |
| ------ | ---------- | ----- |
| `EsplitealoCore` | Foundation only | Bill logic. `BillSession` is a value type; money is integer cents. |
| `EsplitealoDesign` | SwiftUI, CoreText | Tokens, type scale, money, components. No bill logic: it takes cents, names and strings. |
| `EsplitealoScanning`, `EsplitealoCapture` | Vision, VisionKit, PhotosUI, AVFoundation | Already linked into the app for the capture screen. |
| The app (`Esplitealo`) | All of the above | Screens, navigation, the `BillStore`. |

### Concurrency

The app target is **Swift 6** with **MainActor default isolation** and **Approachable Concurrency** (`SWIFT_DEFAULT_ACTOR_ISOLATION`, `SWIFT_APPROACHABLE_CONCURRENCY` in `Config/App.xcconfig`). Types and functions in the app are main-actor isolated unless you write `nonisolated` or `@concurrent`, so UI code needs no annotations. Package targets keep the nonisolated default. Do not turn Swift 6 mode or strict concurrency down.

## The design system

`import EsplitealoDesign`. Everything adapts to light and dark and scales with Dynamic Type.

- **Colour**: `Color.esp.paper`, `.surface`, `.well`, `.ink`, `.inkSecondary`, `.primary`, `.warn`, `.pink`, ... The values come from `design/mockups/_src/tokens.css` (`DesignPalette`). Rules: pink is a shape, never small text (text uses `pinkInk`); warn always comes with an icon or words; person colours only on avatars. Put `.espScreenBackground()` on a screen's root view (paper background, ink text, green tint).
- **Type**: `Text("key").espText(.body)`. Styles: `displayAmount`, `title`, `wordmark`, `amount`, `headline`, `body`, `subhead`, `footnote`, `caption` (nothing under 12 pt). **Unkempt is for screen titles and the wordmark only** (`EspTitle`, `EspWordmark`). **Money is never Unkempt**: use `MoneyText(cents:style:)` or `AmountRow`, which use SF Pro Rounded with monospaced digits (Unkempt digits are proportional). Text wraps; only `displayAmount` may shrink, and only at accessibility sizes.
- **Money**: `MoneyFormatter(locale:).string(cents:)` gives `$1,234.56` for `es_PR` and `en_US` (and `−$1.00` for negatives); `spokenString(cents:)` is for VoiceOver.
- **Components**: `.buttonStyle(.espPrimary(showsDivisionCoin: true))` (one per screen), `.espSecondary`, `.espQuiet`, `.espWarn`; `EspCard { rows }` (each child is a row, hairlines between); `AmountRow`; `PersonAvatar` and `PersonChip` (person colour from the participant's index, dotted ring after eight people); `EspTitle`, `EspSectionHeader`, `EspWordmark`, `DivisionMark`.
- **Spacing and shape**: `Spacing` (4, 8, 12, 16, 24, 32), `Radius`, `Stroke`, `TapTarget` (44 pt minimum).
- **Fonts**: the Unkempt TTFs and both licence texts (Apache 2.0 and the OFL 1.1 that the Bold file declares) are bundled in `EsplitealoDesign` and registered at launch by `DesignFonts.registerAll()`. Do not subset, edit or rename them. The in-app acknowledgements screen is still to be built.

The contrast tests (`ContrastTests`) check every documented pair of the colour plan page in both appearances. Changing a token means changing `tokens.css`, `DesignPalette` and the tests together.

## State and navigation

- **`AppRoute`** is the typed list of the six screens: `home`, `capture` (capture and processing in one), `review`, `people`, `mark`, `totals`. Home is the root of the `NavigationStack`; the others are pushed in order. Each route knows its step ("Paso n de 5"), neighbours, title key and UI-test identifier.
- **`AppRouter`** (`@Observable`) owns the path: `push`, `advance`, `back`, `popToRoot`, `show`.
- **`BillStore`** (`@MainActor @Observable`) owns the `BillSession` of the bill in progress. Read `store.session`; change it only through `store.update { $0.addParticipant(name: "Ana") }`. Every change is autosaved through the `BillDraftStore` after 0.5 s of quiet (and at once when the app goes to the background). A blank bill is never written. `store.finishBill()` deletes the draft and clears the session: call it when the bill is done ("Nueva cuenta" on the success screen) or abandoned on purpose ("Abandonar cuenta", from Home's card or from Review, always after a confirmation). `store.billShared()` runs when the share completes (R-32): it deletes the draft file but keeps the bill in memory for the success screen and Back; the shared bill is no longer "in progress", is not written again (not even when the app goes to the background) until an edit makes it live again, and a relaunch does not offer it. `store.billInProgress` / `hasBillInProgress` (a bill with items or people that has not been shared) drive Home's "Continuar con tu cuenta" card (item count, total, and `resumePath`, the same path a relaunch resume uses). `startNewBill` also removes the old draft file when the new bill is blank. On launch `RootView` calls `loadSavedDraft()` and, if a draft exists, asks "¿Seguimos con tu cuenta?"; `AppRoute.path(resuming:)` puts the user back at the right screen. A draft that cannot be read is deleted, not offered. The draft file lives in `Application Support/Draft`, excluded from backups. The receipt image is not stored yet.
- Inject with `@Environment(BillStore.self)` and `@Environment(AppRouter.self)`.
- **`ScanFlow`** (`@Observable`, `@Environment(ScanFlow.self)`) runs the capture flow behind Home's two buttons and the capture route: camera permission, the VisionKit document camera or `PhotosPicker`, reading on the device, typed failures (`ScanFailure`), then `store.startNewBill(draft:)` and Review. Review replaces Capture in the navigation path (`router.show([.review])`), so Back from Review is Home and never reopens the camera; `captureScreenAppeared()` only starts a capture from `.idle`. A bill is never replaced silently: `open(_:)` with a bill in progress sets `pendingReplacement` instead of opening, and Home asks "¿Empezar una cuenta nueva?"; `keepCurrentBill()` opens the existing bill at its step, `confirmReplacement()` goes on with the scan. The old bill is replaced only when the new scan is handed over, so cancelling the camera or the reading keeps it.

## Strings

All user-facing text goes through `Localizable.xcstrings`: **Spanish (Puerto Rico) is the development language, English the second**. Never write UI text in code.

- Keys are lowercase dotted names (`home.scan`, `assign.warn.title`). Static text: `Text("home.scan")`, `Button("home.scan") { }`.
- Add the key with both an `es` and an `en` value in the catalog (the catalog file is plain JSON; Xcode's editor also works). `Tests/AppResourceTests` fails the required `swift test` run when a key is missing in either language, has different arguments in the two, is not marked translated, or is used in code but not defined.
- Spanish wording rules: tú register; *marcar* for assigning; never *monto* (say *cantidad* or *total*); *compartir espliteo*, *añadir persona*, *comenzar*, *escoger*, *arreglar*, *chequear*. The test forbids `monto`, `asign…`, `agreg…`, `usted`.
- Arguments are positional (`%1$@`, `%2$lld`). Use the typed symbols Xcode generates from the catalog (`STRING_CATALOG_GENERATE_SYMBOLS`): `Text(.navStep(2))`, `Text(.assignProgress(done, total))`, `Text(.peopleAssigned(count))`. The key `people.assigned` becomes `.peopleAssigned`; arguments are typed and in order. Plurals (`variations.plural`, with `one` and `other`) are chosen by the integer argument. Do not use `String(format:)`. `LocalizationRuntimeTests` shows the symbols resolving in both languages, with plurals.
- Bold in a catalog string is Markdown (`**%@**`) and works in `Text("key")`.
- Do not use the word `monto`, do not hard-code `$`: amounts come from `MoneyFormatter`.
- The share text (what the user sends) is built by `ShareSummaryBuilder` in Core with its own `es`/`en` tables, because sharing in Spanish while the UI is English is a separate choice.
- `InfoPlist.xcstrings` localizes the app name and the camera permission text.

## Privacy and permissions

- `Resources/PrivacyInfo.xcprivacy` declares no tracking and no collected data ("Data Not Collected"); no required-reason APIs are used. Add an entry only if a new API needs one (for example `UserDefaults`: reason `CA92.1`).
- The only permission is the **camera**, with a Spanish and English usage text. There is no photo-library key: `PhotosPicker` needs none. `ITSAppUsesNonExemptEncryption` is `NO`.
- `AppResourceTests` checks all of this.
- The privacy policy is [PRIVACY_POLICY.md](PRIVACY_POLICY.md) (Spanish and English); the App Store questionnaire answers are in [APP_STORE_PRIVACY.md](APP_STORE_PRIVACY.md).

## Signing and the bundle identifier

- The bundle identifier `com.esplitealo.app` is final, set once as `APP_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig`. It cannot change once the app is published on the App Store. The test targets derive theirs from it (`.tests`, `.uitests`). `Tools/ScannerLab` keeps its own separate id. A paid Apple Developer enrollment, needed to register the id and upload builds, comes near launch.
- No team id is committed. Simulator builds need none. To run on a device with a free personal Apple ID, create `App/Config/Local.xcconfig` (git-ignored) containing `DEVELOPMENT_TEAM = <your team id>`; `Shared.xcconfig` includes it when present.

## App icon

`Resources/Esplitealo.icon` is a copy of `design/brand/appicon/Esplitealo.icon` (the layered Icon Composer bundle). It is compiled by `actool` as part of the normal build: `ASSETCATALOG_COMPILER_APPICON_NAME = Esplitealo`, and the built app contains the layered icon stack (`Assets.car`, `CFBundleIconName = Esplitealo`). When the brand icon changes, copy the bundle again; `AppResourceTests` fails while the two differ. See [design/brand/README.md](../design/brand/README.md).

## How to add or build a screen

1. The screen already exists as a placeholder in `App/Esplitealo/Features/<Screen>/<Screen>View.swift`, wired into `AppRoute` and `RootView`. Replace its body. Keep the root view's accessibility identifier (`route.accessibilityIdentifier`).
2. Build it from design-system components and `Color.esp` / `espText`. No raw hex values, no fixed font sizes, no UI text in code.
3. Read and change the bill through `@Environment(BillStore.self)`. Move with `@Environment(AppRouter.self)`.
4. Add its strings to `Localizable.xcstrings` in both languages (`Tests/AppResourceTests` will tell you what is missing).
5. Add a `#Preview` fed by `SampleBill` (`scanned()`, `midway()`, `complete()`), in Spanish and English, light and dark.
6. Add tests first for the logic (`App/EsplitealoTests`, Swift Testing) and a snapshot (see below). Check VoiceOver labels, 44 pt targets and the largest Dynamic Type size.
7. A new screen that is not one of the six needs a new `AppRoute` case, its title key, a `RootView` destination and a test.

Files added under `App/Esplitealo` join the app target by themselves; do not edit `project.pbxproj` for them. Targets, packages and capabilities are the only reasons to touch the project file.

## Running the tests

**The supported workflow is: write the tests, run `swift test` locally, push, and read CI.** CI runs the whole app test plan (unit, snapshot, UI smoke and flow tests) on a GitHub-hosted iOS 18 simulator, free because the repository is public; see [CI.md](CI.md#the-supported-workflow).

```bash
swift test                                              # fast, no simulator: Core, Design, resources (string catalogs, xcconfig, manifest), scanning logic
git push                                                # CI builds the app and runs EsplitealoTests and EsplitealoUITests
Scripts/ci-logs.sh                                      # why the latest CI run of this branch failed (or: gh run view --log-failed -R DiazAlejo/esplitealo)
gh workflow run record-snapshots.yml -R DiazAlejo/esplitealo --ref main -f branch=<branch> -f commit=true   # record snapshots on CI
```

Running the app's tests on a **local simulator is optional and discouraged**: simulators and DerivedData fill the owner's Mac disk. If you must (for example to watch a UI test), pick the simulator with the script CI uses and keep the build output outside the repository, then delete it:

```bash
UDID=$(Scripts/ios-simulator-udid.sh 18)          # an iPhone on an iOS 18.x runtime (this Mac has 18.6, 26.0 and 26.3)

# Unit and snapshot tests of the app (BillStore, routes, strings, design components)
xcodebuild test -project App/Esplitealo.xcodeproj -scheme Esplitealo \
  -only-testing:EsplitealoTests -derivedDataPath /tmp/esplitealo-dd \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO

# UI smoke and flow tests (launch to Home in Spanish and English, walk the screens)
xcodebuild test -project App/Esplitealo.xcodeproj -scheme Esplitealo \
  -only-testing:EsplitealoUITests -derivedDataPath /tmp/esplitealo-dd \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO

rm -rf /tmp/esplitealo-dd
```

The first `xcodebuild` run resolves swift-snapshot-testing (network).

### Snapshot tests

`assertDesignSnapshot(view, named:)` renders a SwiftUI view in four variants (light/Spanish, dark/Spanish, light/English, light/Spanish at the largest accessibility Dynamic Type size) and compares it with a PNG in `App/SnapshotReferences/<test file>/`. A missing reference fails the test. **Record references on CI, never on a Mac**: they only match CI's rendering if CI rendered them. Run the [Record snapshots](CI.md#record-snapshots) workflow (`gh workflow run record-snapshots.yml -R DiazAlejo/esplitealo --ref main -f branch=<branch> -f commit=true`): it records on the runner and simulator CI uses (**iPhone 16, iOS 18.6**), checks that the recorded images pass, and commits them to the branch (or uploads them as an artifact). Use `mode=missing` for new tests and `mode=failed` after an intended visual change, then **look at the new images** before you merge. Comparisons use `precision: 0.99, perceptualPrecision: 0.97`, so rendering noise passes and a changed colour, string or layout fails.

Pass `fixedHeight:` (for example a full phone height, 844) for screens and for content that wraps over several lines: the default `.sizeThatFits` layout measures wrapped text at the default size and clips it in the large-text variant.

Every new screen ships with a snapshot of its states: build the screen view with `SampleBill`, an in-memory `BillStore` and a router, then call `assertDesignSnapshot`.

### UI tests

`--uitesting` as a launch argument makes the app keep its draft in a throwaway directory, so a saved bill never interrupts a test. Use accessibility identifiers (`screen.home`, `home.scan`, `screen.next`), not labels, except where the test is about the language. The simulator has no camera, so Debug builds take launch arguments that replace the system camera and photo picker (`App/Esplitealo/Features/Capture/ScanLaunchConfiguration.swift`, compiled out of Release): `--uitesting-recognized-text <path>` reads a committed `RecognizedText` fixture (for example `Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json`) through the real parser and opens Review; `--uitesting-camera authorized|denied|restricted|notDetermined|unsupported` sets the permission state; `--uitesting-scan-failure unreadable|tooManyPages|tooLong|photoNotLoaded|cameraFailed` fails the first attempt; `--uitesting-scan-delay <seconds>` slows reading so the processing screen can be seen. `--uitesting-draft-dir <path>` (Debug only) keeps the draft in that directory instead of a throwaway one, so a test can quit and relaunch the app (`BillSafetyUITests`). `CaptureFlowUITests` shows how to use them. Other tests start from a fixture bill instead: `--fixture=<name>` (`parsed`: a scan with a row the parser flagged and a receipt that does not add up; `unsure`: a scan with two prices the parser could not read, so two warnings on Review and a receipt that does not add up; `scanned`: the same receipt fixed; `table`: the fixed receipt with four people and nothing marked; `quantities`: lines of several units and three people, nothing marked; `midway`: four people with items marked; `complete`: everything marked and ready to share; `mismatch`: everything marked but a receipt that does not add up, confirmed on Review; `service`: everything marked, the receipt has a service charge; `empty`) and `--start-at=<screen>` (`review`, `people`, `mark`, `totals`), both honoured only together with `--uitesting` (`UITestFixture`). `--uitesting-resume-prompt` leaves a saved bill behind so the "¿Seguimos con tu cuenta?" prompt shows (`AccessibilityAuditUITests`); `--uitesting-share complete|cancel` (Debug only) answers for the system share sheet, which a test cannot drive (`TotalsFlowTests`). Rows of a long screen can sit under the bottom bar, so scroll before you tap them, or start from a shorter fixture.

### Where things are tested

| What | Where | Runs in |
| ---- | ----- | ------- |
| Bill logic, parsing, calculator, draft storage | `Tests/EsplitealoCoreTests` | `swift test` |
| Colour tokens, contrast, type scale, money, person colours | `Tests/EsplitealoDesignTests` | `swift test` |
| String catalogs (es/en parity), xcconfig, privacy manifest, icon | `Tests/AppResourceTests` | `swift test` (required CI check) |
| `BillStore`, routes, compiled strings | `App/EsplitealoTests` | CI simulator (`iOS App`) |
| Component and screen snapshots | `App/EsplitealoTests/Snapshots` | CI simulator (`iOS App`) |
| Launch and flow smoke | `App/EsplitealoUITests` | CI simulator (`iOS App`) |
| Accessibility audits (`performAccessibilityAudit`, 44 pt targets) | `App/EsplitealoUITests/AccessibilityAuditUITests.swift` | CI simulator (`iOS App`) |
| Accessibility snapshots (xxxLarge, AX3, AX5, small phone, landscape) | `App/EsplitealoTests/Snapshots/AccessibilitySnapshotTests.swift` | CI simulator (`iOS App`) |
| Increase Contrast palette, pinned-bar policy | `Tests/EsplitealoDesignTests` | `swift test` |

CI: see [CI.md](CI.md).
