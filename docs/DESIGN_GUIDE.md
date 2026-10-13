# Design guide

Visual and interaction guidance for Esplitéalo's screens. It draws on a review of the UI of Study Bunny, a study-timer app, and turns the useful mechanisms into starter values for a native iOS receipt-splitting app.

This guide is an input to design, not a product decision. It does not change scope, the data model, or the screen flow in [Screens](SCREENS.md).

## Purpose and principles

Study Bunny is a game-feel app that rewards time spent. Esplitéalo is a trust-feel utility that should save time and be correct. The guide keeps the warmth and the mechanisms of the first, and leaves behind its density, low contrast, tiny type, and economy.

- **Warm, not childish.** Rounded forms, friendly spacing, and at most one mild moment of delight. No mascot is needed.
- **Numbers first.** Money is always large, tabular, and high contrast. It is never outlined and never auto-shrunk.
- **One person, one color, one initial, one name.** Color reinforces identity but is never the only signal.
- **Native and accessible by default.** SwiftUI, Dynamic Type, VoiceOver, light and dark appearance, Reduce Motion, and 44 pt tap targets.

## What was learned from Study Bunny

Study Bunny is a Unity game that draws its whole interface itself. It has no system controls, no Dynamic Type, no VoiceOver tree, no dark mode, and no haptics. Its layouts are placed by hand on a fixed canvas, with no consistent spacing grid. Its look is a hand-drawn, pastel, "cozy room" style with one rounded typeface in one weight.

The findings come mainly from the shipped app bundle. Screens were reconstructed from that data and public screenshots, and the app was never run, so motion timing and live screen composition were not observed. Public reviews mostly praise the art and complain about ads.

Several of its mechanisms transfer well to a bill-splitting app. Its weaknesses are mostly accessibility ones.

| Borrow (adapted) | Avoid |
| --- | --- |
| One color per subject, as a chip per person (capped at eight) | Fifteen pastel swatches at roughly 1.1 to 1.6:1 contrast, and color as the only identifier |
| A three-layer meter (background, border, fill) for "items assigned" | A decorative meter with particle effects over it |
| Tile anatomy with an explicit state strip, for item rows that are assigned, shared, or unassigned | Best-fit text that shrinks and makes sizes inconsistent |
| Stacked proportional bars with a legend, for a per-person share bar | Icon-only navigation with unlabeled buttons |
| A press tint on buttons (to about 80%, 0.1 s) | Hand-placed layouts with no safe-area handling |
| An asymmetric confirm where the safe action is wider, for destructive confirmations | Ads, trackers, forced prompts at launch, game currency, manual cloud save |
| Reward motion where a value flies to a counter, as an amount flying into a person's chip | Particle effects, loops, and sounds that run constantly |
| A dim scrim behind a rounded card sheet that dismisses on tap outside | Tiny hit targets (30 pt controls, a 16 pt help button) |
| A one-time tutorial that can be replayed | A multi-step modal tutorial before first use, which [Screens](SCREENS.md) rules out for Home |

## Starter palette

These values are Esplitéalo's own original starter palette. They are not Study Bunny's values. The idea is warm "receipt paper and ink" neutrals with a basil-green primary, so money feels calm and the person colors carry the identity.

The contrast ratios are WCAG ratios computed for the key pairs. They are starting points: verify every pair in the running app with the Accessibility Inspector before relying on them.

### Light

| Token | Hex | Notes |
| --- | --- | --- |
| `paper` | #FBF7EF | Screen background, warm off-white |
| `surface` | #FFFFFF | Cards |
| `well` | #F1EADB | Inset fields and rows |
| `ink` | #1E2933 | 13.8:1 on `paper` |
| `inkSecondary` | #5B6670 | 5.5:1 on `paper` |
| `line` | #DDD3BE | Hairlines, 1.4:1, decorative only |
| `primary` | #1F7A5A | Basil green. White on it is 5.3:1, and on `paper` 4.9:1 |
| `onPrimary` | #FFFFFF | |
| `accent` | #F2B84B | Highlights only, never text |
| `warn` | #C23A1D | Unassigned or mismatch, 5.0:1 on `paper` |

### Dark

| Token | Hex | Notes |
| --- | --- | --- |
| `paper` | #14181C | |
| `surface` | #1E252B | |
| `well` | #28313A | |
| `ink` | #F2EEE6 | 15.4:1 on `paper` |
| `inkSecondary` | #A5AEB6 | 7.9:1 on `paper` |
| `line` | #36414B | |
| `primary` | #4CC59A | 8.3:1 on `paper`. Dark text on it is 8.0:1 |
| `accent` | #F5C766 | |
| `warn` | #FF8466 | 7.4:1 on `paper` |

### Person colors

There are eight slots. In light mode a chip uses the fill with white text. In dark mode it uses the lighter tinted fill with dark text (`paper`, 6.8 to 10.9:1). Every chip also shows an initial and the name.

| Slot | Light fill | White-text contrast | Dark-mode fill |
| --- | --- | --- | --- |
| 1 Blue | #2F6FA8 | 5.3 | #6FA8DC |
| 2 Clay | #A85A14 | 5.1 | #E39B52 |
| 3 Violet | #7A4FB5 | 5.8 | #B79AE0 |
| 4 Teal | #1B7F72 | 4.9 | #55C2B2 |
| 5 Rose | #C23D7B | 4.9 | #E67FB0 |
| 6 Olive | #58781C | 5.1 | #A5C55A |
| 7 Mustard | #8A6D00 | 4.9 | #E8C85A |
| 8 Slate | #5B6B80 | 5.4 | #9AA8BA |

If any slot changes, re-run the contrast checks.

`warn` and Clay are close in hue. So an unassigned item always uses a dashed outline plus an icon, never color alone.

## Type scale

Use system fonts so Dynamic Type, localization, and VoiceOver come for free. SF Pro Rounded on the money styles gives a friendly feel without copying another app's typeface.

| Style | Font | Size (pt) | Weight | Use |
| --- | --- | --- | --- | --- |
| Display amount | SF Pro Rounded, monospaced digits | 40 | Semibold | Per-person final amount, bill total |
| Title | SF Pro Rounded | 28 | Semibold | Screen titles |
| Amount | SF Pro Rounded, monospaced digits | 22 | Medium | Item prices, subtotals |
| Headline | SF Pro | 17 | Semibold | Names, section headers |
| Body | SF Pro | 17 | Regular | Item descriptions |
| Subhead | SF Pro | 15 | Regular | Secondary information |
| Footnote | SF Pro | 13 | Regular | Explanations, rounding notes |
| Caption | SF Pro | 12 | Medium | Secondary text on chips. Never smaller |

Map each style to a Dynamic Type text style with `relativeTo:`. Text wraps at large sizes. Only the display amount may use `minimumScaleFactor`, and only at the accessibility sizes.

Study Bunny uses a single weight with text as small as 7 pt and shrink-to-fit labels. This scale replaces that with a 12 pt floor, six distinct sizes, and no shrink-to-fit.

## Spacing, shape, and motion

**Spacing.** Use a 4 pt base with steps of 4, 8, 12, 16, 24, and 32. Side margins are 16 pt. The minimum tap target is 44×44 pt.

**Shape.**

- Cards use a 16 pt corner radius and sheets use 24 pt.
- Chips are fully rounded.
- Strokes are 1 pt in `line`.
- A slightly raised "lip" (a 2 pt darker bottom edge) appears only on the one primary button per screen.

**Press feedback.** Darken to about 80% over 0.1 s and scale to 0.97, as a SwiftUI `ButtonStyle`.

**Motion.**

- Chip selection and count changes use a spring of about 0.25 to 0.35 s.
- An amount flying into a chip takes about 0.4 s.
- With Reduce Motion on, crossfade instead.
- There is at most one celebratory moment, on Totals after sharing.

**Haptics.** Study Bunny has none, so these are Esplitéalo's own additions:

- a selection tick when toggling a person on an item
- a success haptic when the totals reconcile
- a warning haptic when an item is still unassigned at **Review split**

**Illustration.** Use at most one friendly spot illustration on Home and in empty states, drawn in Esplitéalo's own style. Nothing depends on a mascot.

## Screen mapping

Each entry applies the principles above to a screen in [Screens](SCREENS.md). It adds visual treatment only and does not change what a screen does.

### 1. Home

A calm paper-colored screen with the wordmark and one large **Scan receipt** button, 48 to 56 pt tall. It is the single lip-style button. **Choose photo** is a plain bordered button. There are only two actions, so there is no icon grid.

Recent bills, if present, are a simple list. There is no tutorial carousel. A one-line "how it works" sits under the buttons, or behind a small "?" that opens a replayable sheet.

### 2. Capture

Use the system camera UI. Overlay guidance such as "Fit the whole receipt" as a pill in `surface` at 85% opacity, at least 15 pt. **Retake** and **Use photo** are full-width buttons.

If permission is denied, show an explanatory card with an **Open Settings** button, and keep **Choose photo** visible.

### 3. Processing

Show a thin primary-green indeterminate bar, status text at body size ("Reading receipt"), and no sparkles. Offer **Enter items manually** as a secondary button after about 8 seconds or on failure. VoiceOver announces progress changes sparingly.

### 4. Review receipt

Each row has the description on the left (Body) and the price on the right (Amount, monospaced digits). Suspicious rows get `warn`, an icon, and the word "Check", never color alone.

A collapsible original-receipt thumbnail stays pinned above. Subtotal, tax, and total fields sit in a `well` card at the bottom with a visible mismatch state. The primary button is **Continue to people**.

### 5. Add people

Each added name takes the next free color slot automatically, so v1 needs no color picker. It appears as a chip with initial and name. Tap to rename, and use a swipe or button to remove.

Removing a person who has assignments uses an asymmetric confirm, with **Keep person** wider than **Remove**. Beyond eight people, a second ring style (for example dotted) is used instead of silently reusing colors.

### 6. Assign items

This is the most important screen. The layout follows [Screens](SCREENS.md): chips on top, the list in the middle, progress and the button at the bottom.

```
┌────────────────────────────────────────┐
│ Assign items                  3 of 7 ● │  title 28, meter label 15
│ ▓▓▓▓▓▓░░░░░░░░░░  (assigned meter)     │  16–20 pt tall, 3 layers, 4 pt inset
├────────────────────────────────────────┤
│ (A) Ana $14.20  (B) Ben $9.00  (C) Cy…│  sticky chips, horizontal scroll,
│                                        │  amount = pre-tax subtotal (Amount 22)
├────────────────────────────────────────┤
│ ▌ Nachos                      $12.00  │  rows ≥ 56 pt; left bar = assigned
│    (A)(B)(C)  ⅓ each            ← shared│  person chips 28 pt, initials
│ ┌ ┄ Cola ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  $3.50 ┄┐ │  dashed + "Unassigned" = flagged
│ ▌ Burger                       $15.00 │
│    (B)                                 │
├────────────────────────────────────────┤
│        [ Review split (2 left) ]      │  primary; enabled, warns on tap
└────────────────────────────────────────┘
```

- **Chips.** Person chips carry a live pre-tax subtotal.
- **Meter.** A three-layer "items assigned" meter, 16 to 20 pt tall with a 4 pt inset.
- **Row states.** An assigned row has a person-colored leading bar. A shared row shows the stacked person chips and "equal split". An unassigned row has a dashed `warn` outline and the word "Unassigned". Rows are at least 56 pt tall, and long names wrap to two lines.
- **Press feedback.** Rows use the press tint.
- **Assigning.** The chip's subtotal does a quick count change, plus a small flying amount only when Reduce Motion is off.
- **Selection sheet.** A bottom sheet with a scrim, dismissible by tapping outside. Each person is a large tappable row (checkmark, color dot, name), and **Done** is the primary button.
- **Review split.** The button stays enabled and warns on tap if items are unassigned, rather than looking disabled.
- **Avoid.** Multi-column tiny tiles, icon-only controls, color alone (chips always carry initials and names), and shrinking text.

An optional quick-assign "painter" mode (tap a person chip, then tap rows) is Esplitéalo's own idea, not from Study Bunny. Validate it in testing before committing.

### 7. Totals and share

This is the second most important screen.

```
┌────────────────────────────────────────┐
│ Totals                                  │
│ Tip  [15%] [18%] [20%] [Custom]         │  segmented, ≥44 pt
│ Subtotal  $82.40   Tax  $7.12  Tip $14.83│  Amount 22
│ ▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒░░░░  (share bar by person)│  proportional segments + legend
│ ┌ Ana ─────────────────────────  $38.15┐ │  Display 40 for the amount
│ │ items $31.20 · tax $2.70 · tip $4.25 │ │
│ └──────────────────────────────────────┘ │
│  … Ben, Cy …                             │
│  Rounding: +1¢ to Ana (shown)            │  footnote 13, never hidden
│ [ Share breakdown ]   Edit assignments   │
└────────────────────────────────────────┘
```

- **Share bar.** A single proportional bar above the person cards, colored by person slot. Initials appear inside segments that are wide enough and in the legend otherwise.
- **Person cards.** Each has the person color as a left edge, the final amount in Display, and a line of items, tax share, and tip share.
- **Tip.** A segmented selector with at least 44 pt targets.
- **Rounding.** A persistent footnote names any cent adjustment.
- **Reconcile banner.** When the amounts match, a `primary` banner reads "Adds up to $104.35". When they do not, a `warn` banner shows the difference and **Share breakdown** is disabled. This builds confidence, where Study Bunny's loss mechanics build tension.
- **Celebration.** One optional small check or sparkle that fades when the totals reconcile and the share sheet opens. It must be skippable and respect Reduce Motion.
- **Avoid.** Outlined or best-fit numbers, particle effects over numbers, tiny share buttons, and confirm dialogs that default to the destructive action.

## Suggested order of work

1. Tokens: the palette, type scale, and spacing as SwiftUI constants, checked in light and dark.
2. Assign items (chips, meter, row states, selection sheet) with the hardcoded sample receipt, as the [Roadmap](ROADMAP.md) says.
3. Totals (share bar, person cards, rounding and reconcile states).
4. The remaining five screens, using the same tokens.

## Open questions

- **Person-color cap.** Is a cap of eight colors acceptable? A bill with more than eight people needs an extra differentiator. This guide defaults to ring and dotted variants, to be confirmed in usability testing.
- **Celebration.** Should there be one subtle celebratory moment on Totals at all? This is a product taste call. The guide defaults to one subtle, skippable moment.
- **Quick-assign mode.** Is the optional "painter" mode worth building, or is the selection sheet enough?
- **Live behavior.** Study Bunny's live motion timing and screen transitions were not observed. Treat the motion values here as starting points to tune on a device.
- **Palette verification.** All colors and sizes are starter values. They need checking with the Accessibility Inspector, in both appearances and at the larger Dynamic Type sizes.
