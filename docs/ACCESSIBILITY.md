# Accessibility

What Esplitéalo does for people who use VoiceOver, large text, Switch Control, Full Keyboard Access, Reduce Motion, Increase Contrast or no colour vision; what is checked by a test; and the few things only a person with a real iPhone can check. Written for the owner and for coding assistants.

The rule for every new screen: build it with the design system (it already handles most of this), then run through the checklist below.

## Checklist for a screen

| # | Check | How it is done | Checked by |
| - | ----- | -------------- | ---------- |
| 1 | Text scales with Dynamic Type up to AX5, never clipped, never overlapping; content scrolls | `espText` styles map to system text styles; rows switch from side by side to stacked (`ViewThatFits`, `AnyLayout`) when the text is large; every screen body is a `ScrollView` | Snapshots at xxxLarge, AX3, AX5; `performAccessibilityAudit` (`.dynamicType`, `.textClipped`) at AX5 |
| 2 | Pinned bars never cover the content | `ChromePolicy`: a header and the secondary buttons are pinned only up to xxLarge in portrait; the main button up to AX3; at larger sizes, and in landscape, they scroll with the page | `ChromePolicyTests`; small-phone and landscape snapshots |
| 3 | VoiceOver: every control has a label, value and hint; reading order follows the layout; headings are marked | Labels and hints in the catalog (both languages); `EspTitle`, `EspSectionHeader`, `SheetTitle` are headers; decorative pictures are hidden | `performAccessibilityAudit` (`.sufficientElementDescription`, `.trait`, `.parentChild`) on every screen |
| 4 | Amounts are spoken as words ("12 dólares con 50 centavos") | `MoneyText` and `MoneyFormatter.spokenString`; announcements use the same | `MoneyFormatterTests`, `AccessibilityAnnouncementTests` |
| 5 | Mark items needs no drag and no precise tap | Every row is one button that opens a sheet with a 60 pt row per person; each row also has VoiceOver actions: *Marcar para Ana*, *Quitar a Ana*, *Marcar para todos*, *Dejar sin marcar* | `AssignViewModelTests` (the actions), `AssignFlowUITests` |
| 6 | Changes that do not move anything on screen are announced | `AccessibilityAnnouncements`: the reconciliation result after a Review edit (with the difference in words), the new total after a tip change, the stray-cents card appearing, the reading progress, a failed scan, a blocked camera, the rows marked with an action, items still unmarked, the people errors | `AccessibilityAnnouncementTests` |
| 7 | The reason sharing is blocked is available without seeing | Share button hint, the banner, and the line under the button | `TotalsFlowTests` |
| 8 | Hit targets are at least 44 x 44 pt | `TapTarget.minimum`; the quantity stepper is two 44 pt buttons, not the 32 pt system stepper | `AccessibilityAuditUITests.assertTapTargets` on every button of every screen; `performAccessibilityAudit` (`.hitRegion`) |
| 9 | Reduce Motion | Chavito's blink, bob and tilt stop (`ChavitoMotion`), the reading bar holds still, the confetti is not drawn, the shake of a blocked button, the scroll animations and the row expansion are skipped | `ChavitoMotionTests` (loops stop); the rest by reading the code |
| 10 | Reduce Transparency | The app draws no materials or translucent fills: every surface is an opaque token | Nothing to test (grep finds no `Material`) |
| 11 | Increase Contrast | `DesignPalette.palette(for:contrast: .increased)`: text 7:1, graphics 4.5:1, solid borders and rules; `Color.esp` follows the system setting | `AccessibilityContrastTests` |
| 12 | Bold Text | Every text uses system fonts (they follow the setting). Unkempt, used for titles only, has a regular and a bold file and does not change | Nothing to test |
| 13 | Colour contrast, light and dark: text 4.5:1, controls and graphics 3:1 | `ContrastTests` (the colour plan) and `AccessibilityContrastTests` (every pair the screens draw, person colours on every surface, field outlines) | `swift test` |
| 14 | Colour is never the only signal | A person is a colour, an initial and the name (`PersonAvatar`, also in the share-bar legend). Warn is always an icon and words. Unassigned is a dashed icon, the words "Sin marcar" and an outline. A selected choice has a shape (raised segment with underline, check mark, rail) and the *selected* trait | Snapshots (grey the image to check); `PersonColorTests` |
| 15 | Differentiate Without Color | Follows from 14: no state is carried by colour alone, so nothing changes with the setting | as 14 |
| 16 | Text fields are visible and have a keyboard way out | A 1 pt outline at 3:1 on every field (the fill alone is 1.1:1); the decimal pad has a *Listo* button; return keys go *next* then *done*; the placeholder is secondary ink (4.5:1) | `AccessibilityContrastTests`; the order by `AccessibilityAuditUITests` |
| 17 | Full Keyboard Access and Switch Control order | Reading order is the focus order; the name field comes before its button; no custom focus tricks | By reading; see "Needs a person" |
| 18 | Small phone (iPhone SE, 375 x 667 pt) and landscape | Snapshots of Home, Review, People, Mark items and Totals at xxxLarge on 375 x 667, and in landscape | `AccessibilitySnapshotTests` |
| 19 | Spanish (Puerto Rico) and English | Every string is in the catalog in both languages; the audits and snapshots run in both | `AppResourceTests`, snapshots, audits |

## What the tests cover

- **`swift test`** (no simulator): contrast of every pair in both appearances and with Increase Contrast, the pinned-bar policy, spoken money in Spanish and English, the person colours.
- **App unit tests** (CI simulator): the announcements, the VoiceOver reading of rows and chips, the launch arguments that start a test from a saved bill.
- **`AccessibilityAuditUITests`** (CI simulator): `performAccessibilityAudit()` on Home, How it works, the camera-blocked screens, Reading, Scan failed, the resume prompt, Review (and its item, amount and mismatch sheets), People (empty, filled, rename, remove), Mark items (and its warning and the assign sheet), Totals in four states, the share sheet and the success moment, each in two situations: Spanish, light, default text; and English, dark, AX5. Long screens are audited again after scrolling to the bottom. Every button on every screen must be 44 x 44 pt or more.
- **`AccessibilitySnapshotTests`** (CI simulator): every screen and sheet at xxxLarge (light Spanish, dark English), AX3 (light English, dark Spanish, dark English; light Spanish is in the screen's own snapshot) and AX5 on a canvas twice as tall; plus iPhone SE at xxxLarge and landscape. The images are in `App/SnapshotReferences/AccessibilitySnapshotTests`; the ones named `xxxl` in the other folders are AX3.

The audit ignores only issues in views the system draws (navigation bar, status bar, keyboard). Anything else fails the test.

## Needs a person with VoiceOver on a real iPhone

The simulator cannot tell you how it *sounds*. Spend ten minutes with VoiceOver on (triple-click the side button), once in Spanish and once in English:

1. **Home**: swipe right through the screen. Order should be: the name, *Cómo funciona*, Chavito, his line, the title, the subtitle, *Escanear recibo*, *Elegir foto*, the privacy line.
2. **Reading**: while the receipt is read, VoiceOver should say "Leyendo el recibo", then "Buscando los precios", then "Cuadrando el total", and nothing else. If it chatters, the announcements are too many.
3. **Review**: edit a price so the receipt stops adding up. You should hear "Los números como quiera no cuadran. Diferencia: N dólares." Fix it: "Todo quedó nítido".
4. **Mark items** (the important one): without touching the list rows by tapping, swipe to a row, then swipe up or down: you should hear the actions *Marcar para …* and *Marcar para todos*. Do one; you should hear "Marcado para …". Then open the sheet by double-tapping a row, mark two people, and check each row says its person, the amount and *seleccionado*.
5. **Totals**: change the tip with the segments; you should hear the new total, in words. Make the receipt not add up and check the Share button says why it is dimmed.
6. **Share and the success moment**: the focus should land on "¡Wepa! Cuentas claras." and not on Chavito.
7. **Text sizes**: in Settings > Accessibility > Display & Text Size > Larger Text, switch on *Larger Accessibility Sizes* and move the slider to the end. Walk the five screens: nothing should be cut off and the main button should always be reachable.
8. **Increase Contrast** (Display & Text Size) and **Bold Text**: look at Review and Totals. Borders and grey text should be visibly darker, and the pink should still be a decoration.
9. **Reduce Motion** (Motion): Chavito stands still on Home and on the success screen.
10. **Full Keyboard Access** or **Switch Control** (optional): *Añadir persona* should be reachable from the name field in one step, and the keyboard's *Listo* button should close the number pad.

Report what sounded wrong in words ("on Mark items the second action said …"); each of these is a one-line fix.

## Known choices

- A text field's fill is almost the colour of the page (1.1:1), as in the mockups. It has a 1 pt outline so it can be seen (WCAG 1.4.11). Remove `espFieldOutline` to go back to the mockup, at the cost of that rule.
- Amounts written inside a sentence (the banners, the breakdown line of a person) are read by VoiceOver in its own way ("$12.50"). Amounts that stand alone (`MoneyText`) and announcements are spoken as words. Check item 3 and 5 above.
- The decorative pink is 3.15:1 on the cream paper, enough for a graphic (3:1) and never used for text.
