# Chavito reference artwork

Reference exports of Chavito, the Esplitealo raccoon, generated from the SwiftUI source in
[`Sources/EsplitealoDesign/Mascot`](../../../Sources/EsplitealoDesign/Mascot) (geometry ported from
`design/mockups/_src/mascot.js`). Original artwork. Do not edit these files by hand.

| Folder | Contents |
| --- | --- |
| `svg/` | One SVG per expression and variant. Path data is copied verbatim from the mockup. |
| `pdf/` | The same variants as vector PDFs, rendered by the SwiftUI view (`ChavitoPDF`). |

Variants, for each of `neutral`, `happy`, `thinking`, `worried`:

- `chavito-<expression>`: the bare head on transparent ground. Identical in light and dark (illustration colours are constant; pink stays `#EA5A78`, the muzzle stays cream `#F5EEDF`).
- `chavito-<expression>-disc`: Chavito on the soft pink disc, (`#FCE8EC`, the light `--pink-soft`).
- `chavito-<expression>-disc-on-dark`: the same pink disc (`#FCE8EC`; pink does not shift in dark mode) on the dark ground `#0F2A21`.

Regenerate after changing the artwork (the SVGs are also checked against the generator by `swift test`):

```bash
ESPLITEALO_EXPORT_CHAVITO=1 swift test --filter ChavitoExportTests
```

In the app, use `ChavitoView(expression:size:disc:)` from the `EsplitealoDesign` library.
