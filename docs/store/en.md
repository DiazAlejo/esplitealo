# App Store listing: English

Draft of the text for App Store Connect, English. Nothing here is submitted or published. Each `### Field` below has one `text` block: that block is exactly what gets pasted, and `Tests/AppResourceTests/StoreListingTests.swift` counts it against Apple's limits on every `swift test` (and checks the tone rules: never *monto*, no named IVU, no other brands, placeholders still marked TODO). The Spanish listing, which is the primary one, is [es.md](es.md); both files must have the same fields.

Apple's limits (App Store Connect Help, "Platform version information" and "App information"): name 2 to 30 characters, subtitle 30, promotional text 170, description 4,000, what's new 4,000, keywords 100 bytes, App Review notes 4,000 bytes.

Use this text for the *English (U.S.)* localization. The Puerto Rico audience is on the United States storefront, so English-speaking readers there see it too.

## Text for App Store Connect

### App name

```text
Esplitéalo
```

### Subtitle

```text
Split the check, skip the math
```

Subtitle limit is 30 characters; the line above is exactly at the limit, which the test enforces. Shorter fallback: `Split the check, no math`.

### Promotional text

Editable at any time without a new review. Good place for seasonal copy.

```text
Scan the receipt, tap who had what, and share what everyone owes. Works on any iPhone, no account needed, with the math in plain sight.
```

### Description

```text
Split a restaurant check without pulling out the calculator or starting an argument.

Snap the receipt, tap who had what, and share what everyone owes. Esplitéalo reads the receipt on your iPhone and does the math for you, in plain sight.

HOW IT WORKS
1. Scan the receipt with the camera, or pick a photo you already took.
2. Check what the app read. You can fix, add or remove items.
3. Add the people at the table, just by name.
4. Tap who had each item. When several people share a dish, it is split equally.
5. Pick the tip and share the breakdown with the group.

THE MATH, IN PLAIN SIGHT
• Tax and tip are shared in proportion to what each person ordered.
• You see each person's breakdown: items, tax, tip and total.
• If cents are left over, the app shows who got each one and why. Same inputs, same result.
• If the numbers do not match the receipt, the app tells you and will not let you share until you fix it. Nothing changes behind your back.

WORKS ON ANY iPHONE
You do not need an account or a payment app. Esplitéalo works out what each person owes and you share it as text in Messages, Notes or any app you like.

PRIVATE BY DESIGN
• No accounts and no sign-in.
• The receipt is read on your iPhone. The photo never leaves the device and is not kept.
• No ads, no analytics and no tracking.
• The camera is used only to scan receipts. Picking a photo from your library needs no permission.

IN ENGLISH AND SPANISH
Esplitéalo speaks English and Puerto Rican Spanish. Switch languages in your iPhone's Settings.

Note: Esplitéalo calculates and shows what each person owes. It does not process payments or move money; everyone pays however the group agrees.
```

### Keywords

```text
receipt,restaurant,tip,tax,expenses,group,friends,calculator,scanner,dinner,roommates,share,tab,bill
```

### What's new

```text
First version of Esplitéalo. Scan the receipt, tap who had what, pick the tip and share what everyone owes.
```

### Primary category

```text
Finance
```

### Secondary category

```text
Utilities
```

### Age rating

```text
4+. Every question in Apple's age rating questionnaire is answered "None". Details in docs/RELEASE_CHECKLIST.md.
```

### Support URL

```text
TODO: support URL (pending; a project domain, not a personal email)
```

### Marketing URL

```text
TODO: marketing URL (optional; pending, to be set up with the project domain)
```

### Privacy policy URL

```text
TODO: public URL of the privacy policy (docs/PRIVACY_POLICY.md is not published yet)
```

### Contact

```text
TODO: support contact; it is the same contact still pending in the privacy policy (docs/PRIVACY_POLICY.md)
```

### Copyright

```text
TODO: year and legal name of the rights holder (to be set when enrolling in the Apple Developer Program)
```

### Review notes

This is the text to paste into App Review Information > Notes. It is not localized in App Store Connect.

```text
Esplitéalo splits a restaurant check. It has no accounts, no sign-in, no purchases and no server. No demo account is needed.

Camera: used only to scan the receipt. The permission is requested the first time "Scan receipt" is tapped, never before. "Choose photo" uses the system photo picker and needs no permission. The receipt is read on the device with Vision and VisionKit; the photo is not sent anywhere and is not kept. The app does not use the network.

How to test with a sample receipt:
1. Save the attached image "sample-receipt.jpg" (a photo of a restaurant receipt) to Photos.
2. Open the app and tap "Choose photo", then pick that image. You can also tap "Scan receipt" and point the camera at any printed restaurant receipt.
3. On "Check the receipt", review the items, tax and total.
4. Add two or three people, just by name.
5. On "Assign items", tap each item and choose who had it.
6. On "Totals", pick the tip and tap "Share breakdown" to see the text summary and the iOS share sheet.

The app does not process payments and does not connect to any payment app: it only prepares a text with what each person owes.
```

## Positioning notes (not pasted into App Store Connect)

Context: iOS 27 adds Apple Cash "Split Bill". Esplitéalo does not compete on payments; it competes on **working for any check on any iPhone**. The points we can state, all true today:

- Works on any iPhone running iOS 18 or later; no Apple Cash, no balance, no account.
- Shows its math: a per-person breakdown, where every stray cent went, and a refusal to share when the numbers do not match the receipt.
- Real Puerto Rican Spanish (tone and vocabulary), not a generic translation.
- Reads the receipt on the phone and does not keep the photo.

Rules for the public text: no other brand in the keywords or anywhere else in the listing (the test guards the payment and bill-splitting brands); no claim of integration with any payment app (ATH Móvil is out of scope); no claim about Apple Cash we cannot verify. Apple often objects to third-party marks in metadata (Guideline 2.3.7), so the listing says "you do not need a payment app", not "you do not need Apple Cash".

**Open owner decision**: to name Apple Cash explicitly, the only reasonable place is the promotional text (it changes without a new review), for example: "Works on any iPhone, no Apple Cash needed." Confirm the feature's name and behaviour in Apple's published documentation once iOS 27 ships, and accept the review risk.
