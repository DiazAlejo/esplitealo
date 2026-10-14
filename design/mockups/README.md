# Esplitéalo HTML mockups

Static, offline HTML design references for the Esplitéalo iOS app. They are **not** app code: no Swift package, no build step required to view them.

## How to open

1. In Finder, open this folder (`design/mockups/`).
2. Double-click **`index.html`** to choose Spanish or English, or open **`es/index.html`** or **`en/index.html`** directly.

Everything works over `file://` with no server and no network. Each screen mockup includes an **Español / English** switch in the toolbar; keep `es/`, `en/` and `_src/fonts/` side by side so those links and the fonts work.

## Contents

| Path | Purpose |
| --- | --- |
| `index.html` | Landing page linking both languages |
| `es/`, `en/` | Per-language galleries (`index.html`), full-flow `prototype.html`, and 23 per-screen HTML files |
| `_src/` | Sources used to regenerate pages (`strings.js`, `style.css`, `build.py`, etc.) |

Rebuild (optional): from this directory, run `python3 _src/build.py .`

## Languages

- **Spanish (`es/`)** — Puerto Rico vocabulary and sample receipt used in the approved mockups.
- **English (`en/`)** — Same screens and flow in English.

## Typography

Screen titles and the **Esplitéalo** wordmark use **[Unkempt](https://fonts.google.com/specimen/Unkempt)** (Regular 400 for titles, Bold 700 for the wordmark), by Sideshow / Font Diner, Inc., under the **Apache License 2.0**. Font files live in `_src/fonts/`; the full license text is in `_src/fonts/Unkempt-LICENSE-Apache-2.0.txt`.

Body text and UI chrome use the system font stack defined in `_src/style.css`.
