# Esplitéalo brand assets (Dos paredes)

Final logo and app-icon package for **Dos paredes**: the hand-drawn Un trazo **e** in green, a coral-pink division bar that meets both inner walls (clean butt joint carried by shape), two pink dots, on cream ground. Dark appearance keeps the **same pink**, a cream **e**, and ground `#0F2A21`.

## What to use where

| Need | File |
| --- | --- |
| **iOS app icon (layered, Liquid Glass)** | `appicon/Esplitealo.icon` — add to the Xcode app target’s asset catalog or build input; set `ASSETCATALOG_COMPILER_APPICON_NAME` to `Esplitealo` |
| **Asset-catalog fallback (flat 1024 masters)** | `appicon/AppIcon.appiconset/` — light, dark, and tinted single-size set |
| **App Store marketing (1024, no alpha, square)** | `png/icon/appstore-marketing-1024.png` |
| **Flat icon masters** | `png/icon/icon-*-1024.png` and matching `svg/icon/icon-*.svg` (`light`, `dark`, `inverted`, `tinted-source`, `one-colour-ink`, `one-colour-white`, `light-basil`) |
| **All raster sizes** | `png/ladder/icon-{light,dark}-*.png` |
| **Symbol only** | `svg/symbol/symbol.svg` (colour); `symbol-on-dark.svg`, `symbol-mono-ink.svg`, `symbol-mono-white.svg` |
| **Splash / launch lockup** | `svg/lockups/lockup-stacked.svg` (colour); `lockup-stacked-on-dark.svg` for dark |
| **Settings / in-app header lockup** | `svg/lockups/lockup-horizontal.svg` (colour); mono and on-dark variants alongside it |
| **Wordmark alone** | `svg/wordmark/wordmark.svg` |
| **Web favicon** | `png/favicon/` and `svg/icon/favicon-rounded.svg` |
| **Separated layers (design handoff)** | `layers/svg/`, `layers/png/`, duplicate bundle at `layers/Esplitealo.icon` |
| **Wordmark font** | `fonts/Unkempt-Bold.ttf`, `fonts/Unkempt-Regular.ttf` — Apache 2.0 (`fonts/LICENSE-Unkempt-Apache-2.0.txt`) |

## Colours

| Role | Hex | Notes |
| --- | --- | --- |
| Cream (paper / icon ground) | `#FBF7EF` | Light UI paper matches `design/mockups/_src/tokens.css` |
| Primary green (e body) | `#1F7A5A` | Primary actions and logo green |
| Coral pink (accent) | `#EA5A78` | Division bar, dots, wordmark accents; **shapes and large elements only** in UI (see [Design guide](../../docs/DESIGN_GUIDE.md)) |
| Basil (documented alternative green) | `#145A42` | Optional deeper green (`icon-light-basil`); not the shipped default |
| Dark icon ground | `#0F2A21` | Dark appearance background |

**Pink on green at the logo edge** is about **1.56:1** measured contrast (hue edge; Liquid Glass can lift pink slightly in renders). The joint is a **butt** meeting of fills, not an overlap; readability comes from shape, not from treating pink as small text on green.

**Dark appearance rule:** same pink `#EA5A78`, cream e `#FBF7EF`, dark ground `#0F2A21`. Do not use a lighter “dark-only” pink for the mark.

## Wordmark

- **Unkempt Bold**, all capitals: **ESPLITÉALO**
- The acute on **É** and the **÷** division sign are **pink**; remaining letters use ink or primary green depending on lockup variant
- Outlines are baked into the SVG paths (no live text in production assets)

## Chavito

Marketing mockups use **Chavito**, the friendly raccoon illustration (`design/mockups/_src/mascot.js`). Chavito is not part of this logo package; blush and coin accents in mocks use the same pink tokens as the brand.

## Layered icon (inside `Esplitealo.icon`)

Layers back to front: background → division (bar + dots) → **e body in front** so an 8-unit pink strip sits under the green and hides anti-aliasing seams. Liquid Glass is on for e, bar, and dots.

## Limits

- Appearance behaviour on device (wallpaper, increased contrast, reduced transparency) was validated with **Icon Composer renders**, not on hardware.
- The hand-drawn e is a generated outline; a designer may redraw for final print.
- **Tinted dark** can show a weaker bar (known ~1.44:1); shape still carries the mark.
- The e’s stroke start was moved ~10° so the right wall sits under the bar (see generator notes in `_src/`).

## Regenerating assets

From `design/brand/`:

```bash
DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib python3 _src/build_assets.py
```

Optional seam study (needs Xcode 26 **Icon Composer** `ictool`):

```bash
python3 _src/joint_study.py
```

Python packages: **fonttools**, **brotli**, **cairosvg**, **pillow**, **skia-pathops**, **numpy**. On Apple Silicon Homebrew Python you may need `DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib` for Cairo.

## Building the app icon

Tested on **Xcode 26.3** with full iOS SDK installed.

### `actool` — compile `.icon` to `Assets.car` (works)

Create an output directory first. Pass the **`.icon` bundle path directly** (not only inside an `.xcassets` folder):

```bash
mkdir -p /tmp/esplitealo-icon-out
xcrun actool --compile /tmp/esplitealo-icon-out \
  --platform iphoneos \
  --minimum-deployment-target 17.0 \
  --app-icon Esplitealo \
  --output-partial-info-plist /tmp/esplitealo-icon-partial.plist \
  design/brand/appicon/Esplitealo.icon
```

Produces `/tmp/esplitealo-icon-out/Assets.car` plus generated `Esplitealo60x60@2x.png` and iPad sizes. Inspect entries:

```bash
xcrun assetutil --info /tmp/esplitealo-icon-out/Assets.car
```

**Failure (do not use for layered icons):** placing `Esplitealo.icon` inside `Assets.xcassets` alone and running `actool` on the catalog returned: *None of the input catalogs contained a matching … icon stack named "Esplitealo".*

### `actool` — flat `AppIcon.appiconset` fallback

Wrap the appiconset in a catalog:

```bash
mkdir -p /tmp/AppAssets.xcassets/AppIcon.appiconset
cp design/brand/appicon/AppIcon.appiconset/* /tmp/AppAssets.xcassets/AppIcon.appiconset/
printf '%s\n' '{"info":{"author":"xcode","version":1}}' > /tmp/AppAssets.xcassets/Contents.json
mkdir -p /tmp/esplitealo-flat-out
xcrun actool --compile /tmp/esplitealo-flat-out \
  --platform iphoneos \
  --minimum-deployment-target 17.0 \
  --app-icon AppIcon \
  --output-partial-info-plist /tmp/esplitealo-flat-partial.plist \
  /tmp/AppAssets.xcassets
```

### `ictool` — preview renders (Icon Composer)

```bash
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
"$ICTOOL" design/brand/appicon/Esplitealo.icon \
  --export-image --output-file /tmp/esplitealo-default.png \
  --platform iOS --rendition Default \
  --width 1024 --height 1024 --scale 1
```

Renditions: `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, `ClearDark`.

### Xcode app target

Add `Esplitealo.icon` to the app target, set **Asset Catalog Compiler – App Icon Set Name** (`ASSETCATALOG_COMPILER_APPICON_NAME`) to `Esplitealo`, then build:

```bash
xcodebuild -scheme YourApp -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

The built `.app` should contain `Assets.car` with the layered icon stack; use `xcrun assetutil --info` on that car file to verify.
