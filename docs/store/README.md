# App Store material

Everything prepared for the App Store listing. **Nothing is submitted or published**, and no Apple account exists yet; see [RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md) for what is left.

| What | Where |
| ---- | ----- |
| Listing text, Spanish (Puerto Rico) | [es.md](es.md) |
| Listing text, English | [en.md](en.md) |
| Screenshots | made by the **Store screenshots** workflow (below) |
| What Apple requires, with status | [../RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md) |

The listing files are checked by `Tests/AppResourceTests/StoreListingTests.swift` in the required `swift test` run: Apple's character and byte limits, the same fields in both languages, URLs and contact still marked `TODO`, and the wording rules (never *monto*, no named IVU, no other brands, no likeness of the television character).

## Screenshots

`App/EsplitealoUITests/StoreScreenshotTests.swift` launches the app on fixture bills (`--uitesting --fixture=… --start-at=…`, see [APP.md](../APP.md#ui-tests)) and takes a full-screen picture of the five key screens:

| File | Screen | Fixture |
| ---- | ------ | ------- |
| `…-01-home.png` | Home | none (empty bill) |
| `…-02-review.png` | Review receipt | `scanned`, at `review` |
| `…-03-mark.png` | Mark items | `midway`, at `mark` |
| `…-04-totals.png` | Totals | `complete`, at `totals` |
| `…-05-share.png` | Share summary (the preview sheet) | `complete`, at `totals`, then a tap on "Compartir espliteo" |

in three sets: `es-light-` (Spanish, Puerto Rico), `en-light-` and `es-dark-`. The tests skip themselves unless `STORE_SCREENSHOTS=1` is set, so the normal test plan never runs them. No fastlane and no other tool: the pictures are `XCTAttachment`s of the result bundle, which [`Scripts/export-store-screenshots.sh`](../../Scripts/export-store-screenshots.sh) turns into files and checks (PNG, no alpha channel, expected size).

### Run it (on GitHub, not on the Mac)

```bash
gh workflow run store-screenshots.yml -R DiazAlejo/esplitealo --ref main -f branch=main   # or any pushed branch
gh run watch -R DiazAlejo/esplitealo                                                       # pick the run to follow
Scripts/fetch-store-screenshots.sh                                                         # latest successful run -> build/store-screenshots/
```

[`store-screenshots.yml`](../../.github/workflows/store-screenshots.yml) runs on a `macos-26` runner (free, public repository) with Xcode 26.3, two jobs in parallel, one per size. Each boots its simulator with [`Scripts/boot-store-simulator.sh`](../../Scripts/boot-store-simulator.sh) (status bar fixed at 9:41, full battery and signal), builds, takes the 15 pictures, checks them and uploads one artifact per size (kept 14 days):

| Artifact | Device | Pixels (portrait) | App Store Connect display |
| -------- | ------ | ----------------- | ------------------------- |
| `store-screenshots-iphone-17-pro-max-1320x2868` | iPhone 17 Pro Max | 1320 × 2868 | 6.9-inch, iPhone with Dynamic Island (large) |
| `store-screenshots-iphone-17-pro-1206x2622` | iPhone 17 Pro | 1206 × 2622 | 6.3-inch, iPhone with Dynamic Island (medium) |

The workflow file must be on `main` before `gh workflow run` can start it. The test is exercised by running it on the pull request's branch, so the run does not need a Mac.

### What Apple asks for (checked on 2026-10-16)

From [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) in App Store Connect Help:

- At least one screenshot for **iPhone with Dynamic Island (medium display)**, up to **10 per device size**, as `.jpeg`, `.jpg` or `.png`, **without alpha channels or transparency**.
- Accepted portrait sizes with the Dynamic Island: large 1260 × 2736, 1290 × 2796 or 1320 × 2868; medium 1179 × 2556 or 1206 × 2622. A size you do not provide is scaled from the next larger one, "if your app's user interface is consistent across multiple device sizes and localizations".
- Screenshots are per localization: upload the `es-` ones to the Spanish listing and the `en-` ones to the English listing. The dark set is optional extra material (the store shows the first screenshots; put the light ones first).
- The page also lists an iPhone Duo size and says screenshots for it become required in April 2027 for apps built with the iOS 27.1 SDK or later. That does not apply to a first release built now; look again before the first update.

Apple changes these tables; compare with the page when you upload. Two sizes are produced so that either route (medium and large) has native pictures.

Optional framing (device bezels, marketing captions) is out of scope.
