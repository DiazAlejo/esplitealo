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
- **`BillStore`** (`@MainActor @Observable`) owns the `BillSession` of the bill in progress. Read `store.session`; change it only through `store.update { $0.addParticipant(name: "Ana") }`. Every change is autosaved through the `BillDraftStore` after 0.5 s of quiet (and at once when the app goes to the background). A blank bill is never written. `store.finishBill()` deletes the draft and clears the session: call it when the bill is done. On launch `RootView` calls `loadSavedDraft()` and, if a draft exists, asks "¿Seguimos con tu cuenta?"; `AppRoute.path(resuming:)` puts the user back at the right screen. A draft that cannot be read is deleted, not offered. The draft file lives in `Application Support/Draft`, excluded from backups. The receipt image is not stored yet.
- Inject with `@Environment(BillStore.self)` and `@Environment(AppRouter.self)`.
- **`ScanFlow`** (`@Observable`, `@Environment(ScanFlow.self)`) runs the capture flow behind Home's two buttons and the capture route: camera permission, the VisionKit document camera or `PhotosPicker`, reading on the device, typed failures (`ScanFailure`), then `store.startNewBill(draft:)` and Review. Going back from Review to the capture route starts a new capture.

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

## Signing and the bundle identifier

- The bundle identifier `com.esplitealo.app` is a placeholder, set once as `APP_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig`. The test targets derive theirs from it.
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

Requires Xcode 26.3 and an **iOS 18.x simulator runtime** (this Mac has iOS 18.6, 26.0 and 26.3). Pick the simulator with the script CI uses:

```bash
UDID=$(Scripts/ios-simulator-udid.sh 18)          # an iPhone on an iOS 18.x runtime

# Fast, no simulator: Core, Design, resources (string catalogs, xcconfig, manifest), scanning logic
swift test

# Build the app for the simulator, no signing
xcodebuild build -project App/Esplitealo.xcodeproj -scheme Esplitealo \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO

# Unit and snapshot tests of the app (BillStore, routes, strings, design components)
xcodebuild test -project App/Esplitealo.xcodeproj -scheme Esplitealo \
  -only-testing:EsplitealoTests \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO

# UI smoke tests (launch to Home in Spanish and English, walk the six screens)
xcodebuild test -project App/Esplitealo.xcodeproj -scheme Esplitealo \
  -only-testing:EsplitealoUITests \
  -destination "platform=iOS Simulator,id=$UDID" CODE_SIGNING_ALLOWED=NO
```

The first `xcodebuild` run resolves swift-snapshot-testing (network). Use `-derivedDataPath <dir>` to keep build output outside the repository.

### Snapshot tests

`assertDesignSnapshot(view, named:)` renders a SwiftUI view in four variants (light/Spanish, dark/Spanish, light/English, light/Spanish at the largest accessibility Dynamic Type size) and compares it with a PNG in `App/SnapshotReferences/<test file>/`. A missing reference is recorded on the first run and that run fails: run again to compare. After an intended visual change, delete the matching PNGs, run once, **look at the new images**, and commit them. References are recorded on **iPhone 16, iOS 18.6** (`Scripts/ios-simulator-udid.sh 18`); comparisons use `precision: 0.99, perceptualPrecision: 0.97`, so rendering noise passes and a changed colour, string or layout fails. Record on that same runtime.

Pass `fixedHeight:` (for example a full phone height, 844) for screens and for content that wraps over several lines: the default `.sizeThatFits` layout measures wrapped text at the default size and clips it in the large-text variant.

Every new screen ships with a snapshot of its states: build the screen view with `SampleBill`, an in-memory `BillStore` and a router, then call `assertDesignSnapshot`.

### UI tests

`--uitesting` as a launch argument makes the app keep its draft in a throwaway directory, so a saved bill never interrupts a test. Use accessibility identifiers (`screen.home`, `home.scan`, `screen.next`), not labels, except where the test is about the language. The simulator has no camera, so Debug builds take launch arguments that replace the system camera and photo picker (`App/Esplitealo/Features/Capture/ScanLaunchConfiguration.swift`, compiled out of Release): `--uitesting-recognized-text <path>` reads a committed `RecognizedText` fixture (for example `Tests/Fixtures/Receipts/pr-ivu-bistro.recognized.json`) through the real parser and opens Review; `--uitesting-camera authorized|denied|restricted|notDetermined|unsupported` sets the permission state; `--uitesting-scan-failure unreadable|tooManyPages|tooLong|photoNotLoaded|cameraFailed` fails the first attempt; `--uitesting-scan-delay <seconds>` slows reading so the processing screen can be seen. `CaptureFlowUITests` shows how to use them.

### Where things are tested

| What | Where | Runs in |
| ---- | ----- | ------- |
| Bill logic, parsing, calculator, draft storage | `Tests/EsplitealoCoreTests` | `swift test` |
| Colour tokens, contrast, type scale, money, person colours | `Tests/EsplitealoDesignTests` | `swift test` |
| String catalogs (es/en parity), xcconfig, privacy manifest, icon | `Tests/AppResourceTests` | `swift test` (required CI check) |
| `BillStore`, routes, compiled strings | `App/EsplitealoTests` | simulator |
| Component snapshots | `App/EsplitealoTests/Snapshots` | simulator |
| Launch and flow smoke | `App/EsplitealoUITests` | simulator |

CI: see [CI.md](CI.md).
