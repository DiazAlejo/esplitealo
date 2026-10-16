# App Store privacy answers

What to answer in App Store Connect › App Privacy, and why. The policy text is [PRIVACY_POLICY.md](PRIVACY_POLICY.md). The app's privacy manifest (`App/Esplitealo/Resources/PrivacyInfo.xcprivacy`) says the same: no tracking, no collected data, no required-reason APIs.

## Questionnaire

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **No** → the label reads **Data Not Collected** |
| Does the app track users (App Tracking Transparency)? | **No**. No `NSUserTrackingUsageDescription`, no tracking domains |
| Privacy Policy URL | Required for every app (Guideline 5.1.1(i)). Use the published URL of the policy; see below |
| Age rating | Answer Apple's questionnaire separately; expect 4+ |

## Why "Data Not Collected"

Apple counts data as collected only when it leaves the device and is kept longer than needed to serve the request. Nothing leaves the device:

- **No network code.** The app has no `URLSession`, web view, SDK, analytics, crash reporter or ad library, and no third-party dependencies.
- **Receipt photo and text.** Recognized on device by Apple's Vision and VisionKit; not stored.
- **Bill in progress.** One JSON file in `Application Support/Draft`, excluded from backups, deleted when the bill is finished or discarded.
- **Camera.** Used only to scan receipts. The photo picker needs no permission.
- **Sharing.** The system share sheet receives only the summary text the user chooses to send; the app does not transmit it.
- **No identifiers.** No account, device ID, advertising ID, location, contacts or purchases.

If any of this changes (a backend, analytics, crash reports, iCloud sync), update this page, the policy and the privacy manifest before shipping.

## Publishing the policy later

Nothing is published yet; the URL is needed only at App Store submission. Options:

1. **GitHub Pages from `docs/`** (needs a public repository or a plan that allows Pages on private ones): repository Settings › Pages › Deploy from branch › `main` / `/docs`. The page would be `https://diazalejo.github.io/esplitealo/PRIVACY_POLICY` (Jekyll renders the Markdown). Check the exact URL after enabling.
2. **A simple HTML copy**: convert `PRIVACY_POLICY.md` to one static HTML file and host it anywhere (any static host).

Also link the policy inside the app (Guideline 5.1.1(i) requires it to be reachable in the app too) once the URL exists.
