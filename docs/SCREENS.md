# Screens

Screen-by-screen specification for the MVP. The flow is linear, and users can go back to edit earlier steps without losing work.

```
Home -> Capture -> Processing -> Review receipt -> Add people -> Assign items -> Totals and share
```

## 1. Home

**Purpose:** start a bill with minimal friction.

- App name and a simple visual identity.
- Primary button: **Scan receipt**.
- Secondary action: **Choose photo**.
- Optional recent bills list, only if local saving is implemented early.

**Behavior:** starts a new bill immediately. No account creation, onboarding carousel, or permission request until the user chooses an action that needs it.

## 2. Capture receipt

**Purpose:** obtain a legible image.

- Camera preview and capture button.
- Guidance to include all receipt items, tax, and total.
- Retake and use-photo controls.
- Photo-library import.

**Behavior:** uses Apple's camera and photo APIs. If camera permission is denied, explain how to enable it in Settings and keep photo import available.

## 3. Scan processing

**Purpose:** recognize text on the device.

- Progress indicator.
- Brief status such as "Reading receipt".
- Retry, or enter items manually, if recognition fails.

**Behavior:** uses Apple Vision text recognition on the device. Parses likely item descriptions, prices, subtotal, tax, tip, and total. Recognized text is only a suggestion; never assume every detected number is an item price.

## 4. Review receipt

**Purpose:** turn recognition output into correct structured data.

- Editable item description and price rows.
- Add, edit, and delete item controls.
- Subtotal, tax, and receipt total fields.
- Original receipt image available for reference.
- Button: **Continue to people**.

**Behavior:** the user confirms or corrects every item and the receipt amounts. Missing or suspicious values are flagged. The receipt total is never silently changed to match the extracted items.

**What the scan could not read well:** whatever the parser was unsure about is listed in a card under the banner, "Lo que no pude leer bien · N" / "What I couldn't read well · N", in plain words and never as an error code. A price it could not read says which row and what was printed ("No pude leer el precio de **Flan para compartir**: «9,00»." with a hint to add the item); a guessed number format says the numbers may be off and to check the prices. Each entry has a **Entendido** / **Got it** button that retires it; saving or deleting the row it names retires it too. A retired warning leaves the screen but stays in the saved bill. Warnings only inform: they never disable editing or **Continue**, and a mismatch is still the banner's job. See [receipt parsing](RECEIPT_PARSING.md#warnings-what-the-scan-was-unsure-about).

Receipt layouts vary and recognition can confuse quantities, item prices, and totals, so this screen is essential, not an optional advanced feature.

## 5. Add people

**Purpose:** define who is sharing the bill.

- Name field and **Add person** button.
- Participant chips or cards.
- Edit and remove actions.
- Button: **Assign items**.

**Behavior:** names are typed in, with no accounts and no contacts access. At least one participant is required. Removing a participant who has assignments triggers reassignment or confirmation, never silent erasure.

## 6. Assign items (core screen)

**Purpose:** make splitting the bill fast and intuitive.

**Layout**

- Top: participant chips, each showing that person's current pre-tax assigned subtotal.
- Middle: item list with description, price, and assigned people.
- Bottom: assignment progress and **Review split** button.

**Interaction**

1. Tap an item.
2. Select one or more participants.
3. Confirm or close the selection.
4. See the item's assignment update immediately.

**Rules**

- One person gets 100% of an item by default.
- Multiple selected people split that item equally by default.
- Unequal splits are a later version.
- Unassigned items remain visibly flagged.
- The user can edit names, prices, people, and assignments without restarting.

**Example:** a $12 appetizer assigned to three people contributes $4 to each person's item subtotal before tax and tip.

## 7. Review totals and share

**Purpose:** deliver a trustworthy final answer.

- Tip selector: percentage or custom amount.
- Receipt subtotal, tax, tip, and total.
- Per-person item subtotal, tax share, tip share, and final amount.
- **Share breakdown** button.
- **Edit assignments** and **Edit receipt** actions.

**Behavior:** tax and tip are allocated proportionally to each person's assigned item subtotal. Any rounding adjustment is shown transparently, whichever pool it comes from (items, tax, tip, service charge, printed tip). A bill whose items are all free but that has tax, tip or a service charge cannot be shared, and the screen says nobody has items to carry the tax or tip. The custom tip field does not accept a negative amount. The sum of amounts owed must equal the confirmed bill total. Sharing opens the native iOS share sheet with a readable text summary. No payment integration.
