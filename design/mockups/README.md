# Esplitéalo HTML mockups

Static, offline HTML design references for the Esplitéalo iOS app (v4 bilingual recolor). They are **not** app code: no Swift package, no server required to view them.

## How to open

1. In Finder, open this folder (`design/mockups/`).
2. Double-click **`index.html`** to pick Spanish or English, or open **`es/index.html`** or **`en/index.html`** for a language gallery.
3. Open **`colors.html`** for the brand colour plan (tokens, contrast notes, screen demos).

Everything works over `file://` with no network. Each screen mockup has an **Español / English** switch and a light/dark theme toggle in the toolbar. Keep `es/`, `en/`, and `_src/fonts/` together so links and fonts resolve.

## Brand colours (v4)

| Role | Token / value | Use |
| --- | --- | --- |
| Cream paper | `--brand-cream` (#FBF7EF light) | Backgrounds, receipt feel |
| Green primary | `--brand-green` (#1F7A5A light) | Buttons, success, selection |
| Pink accent | `--brand-pink` (#EA5A78) | Shapes, decoration, soft discs behind Chavito |

Full roles and dark-mode values live in `_src/tokens.css` and on `colors.html`.

## Person colours

Default mockups use the **proposed** eight person colours. Append **`?people=old`** to any screen URL (or use the gallery control) to switch to the previous v2 palette (Blue, Clay, Violet, Teal, Rose, Olive, Mustard, Slate; defined in `_src/tokens.css`, no longer in the design guide). Share-sheet styling follows the same switch unless overridden with `?share=old|new`.

## Regenerate pages

Sources are under `_src/`. After editing `tokens.css`, `style.css`, `strings.js`, `mascot.js`, `app.js`, or `screens.json`:

```bash
python3 _src/build.py .
```

Run from this directory (`design/mockups/`). The script writes `es/`, `en/`, the landing `index.html`, and `colors.html`. Fonts are embedded once in the generated CSS (shared woff2 files in `_src/fonts/`).

Optional: `node _src/test_calc.js` checks bill-splitting invariants in `calc.js`.

## Languages

- **Spanish (`es/`)** — Puerto Rico vocabulary and sample receipt.
- **English (`en/`)** — Same flow and screens in English.

## Typography

Screen titles and the **Esplitéalo** wordmark use **[Unkempt](https://fonts.google.com/specimen/Unkempt)** (Regular 400 for titles, Bold 700 for the wordmark), by Sideshow / Font Diner, Inc., under the **Apache License 2.0**. Font files are in `_src/fonts/`; the full license text is `_src/fonts/Unkempt-LICENSE-Apache-2.0.txt`.

Body text and UI chrome use the system font stack in `_src/style.css`.
