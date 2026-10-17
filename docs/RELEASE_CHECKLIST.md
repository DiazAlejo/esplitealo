# Release checklist

Everything that has to be true before Esplitéalo is on the App Store, with who has to act. Nothing has been submitted, and no external account has been created.

Status:

- **done**: finished and checked in this repository.
- **needs owner**: a decision, text or action only the owner can do, and it does not need the paid program.
- **needs paid enrollment**: blocked until the owner enrolls in the paid Apple Developer Program (US$99 per year).

Listing text lives in [store/es.md](store/es.md) and [store/en.md](store/en.md); screenshots in [store/README.md](store/README.md).

## 1. Apple accounts and identifiers

| Item | Status | Notes |
| ---- | ------ | ----- |
| Enroll in the **Apple Developer Program** (paid) | needs owner | Needed to register the id, sign for distribution, upload builds and use TestFlight. Individual enrollment shows the owner's legal name as the seller; an organization needs a D-U-N-S number. Decide which before enrolling, because the seller name cannot be hidden. |
| Bundle identifier `com.esplitealo.app` | done in code, needs paid enrollment to register | Final value, set once in `App/Config/Shared.xcconfig`; it cannot change after the first App Store release. Register it as an explicit App ID in the developer portal. |
| Confirm the id and name are cleared (trademark) | needs owner | See section 6. Do this before registering the id, since registering and the App Store name reserve both. |
| Signing: Automatic signing with the team | needs paid enrollment | No team id is committed. Put `DEVELOPMENT_TEAM` in git-ignored `App/Config/Local.xcconfig` for local builds; for Xcode Cloud the team comes from the connected App Store Connect account. |
| Distribution certificate and provisioning profile | needs paid enrollment | Automatic signing creates them; nothing to commit. |
| Capabilities | done | None: no push, iCloud, sign-in or in-app purchase. Camera is a permission, not a capability. |

## 2. The app build

| Item | Status | Notes |
| ---- | ------ | ----- |
| iOS 18 minimum, iPhone only | done | `IPHONEOS_DEPLOYMENT_TARGET = 18.0`, `TARGETED_DEVICE_FAMILY = 1`. |
| Built with Xcode 26 or later | done | CI uses Xcode 26.3. Apple requires the current SDK generation for uploads; re-check the minimum Xcode on the day of upload. |
| App icon | done | Layered `Esplitealo.icon` in the app; flat 1024 × 1024 marketing master at `design/brand/png/icon/appstore-marketing-1024.png` (no alpha). |
| Display name `Esplitéalo`, localized | done | `InfoPlist.xcstrings`. |
| Camera usage text (Spanish and English) | done | `NSCameraUsageDescription`; the only permission. |
| Privacy manifest | done | `PrivacyInfo.xcprivacy`: no tracking, no collected data, no required-reason APIs. Re-check if an API that needs a reason is added. |
| Version `MARKETING_VERSION` and build `CURRENT_PROJECT_VERSION` | needs owner | Now `0.1.0` and `1`. Set the first release to `1.0.0` (the number on the store) and build `1`; each upload to App Store Connect needs a build number higher than the last one for that version. Xcode Cloud can set the build number automatically (see section 5). |
| Test on a physical iPhone | needs owner | Listed in [REQUIREMENTS.md](REQUIREMENTS.md). Check the camera scan on a real receipt, and the share sheet. |
| Camera scan quality on real receipts | needs owner | See [OCR_BENCHMARK.md](OCR_BENCHMARK.md) and [SCANNING.md](SCANNING.md). |
| Open review items before launch | needs owner | [Issue 34](https://github.com/DiazAlejo/esplitealo/issues/34) (parser warnings do not reach Review) and the name check issue 31. |

## 3. App Store Connect record

All of it needs the paid program, because the record is created under the developer account.

| Item | Status | Notes |
| ---- | ------ | ----- |
| Create the app record (platform iOS, name, primary language Spanish, bundle id, SKU) | needs paid enrollment | The name `Esplitéalo` is reserved the moment the record is created; check availability first. SKU is private, any unique string. |
| Localizations | needs paid enrollment | Spanish (Mexico) slot for the Puerto Rico Spanish text (Apple has no Puerto Rico entry), English (U.S.) for English. See [store/es.md](store/es.md). |
| Name, subtitle, promotional text, description, keywords, what's new | done (drafts) | In `docs/store/`, within Apple's limits, counted by a unit test. Needs the owner's review of the wording. |
| Category | done (draft), needs owner | Primary Finance (matches `LSApplicationCategoryType`), secondary Utilities. Owner may prefer Utilities as primary. |
| Support URL | needs owner | A real page with a way to reach the owner. Placeholder in the drafts. Not GitHub and not a personal address. |
| Marketing URL | needs owner | Optional. |
| Copyright line (year and legal name) | needs owner | Depends on how the owner enrolls. |
| Screenshots | done (generator), needs owner to upload | Run the workflow in [store/README.md](store/README.md); upload to each localization once the record exists. The pictures are generated on a simulator, which Apple accepts, but check that they show nothing that misleads (the fixture bill is a sample). |
| App icon (1024 × 1024) | done | Comes from the build; Xcode puts it in the upload. |
| Pricing and availability | needs owner | Free is assumed. Storefronts: at least the United States, which includes Puerto Rico. |
| Content rights | needs owner | Answer "no third-party content". The bundled Unkempt font is licensed (Apache 2.0 and OFL); see `THIRD_PARTY_NOTICES.md`. |
| Review notes | done (draft), needs owner | In both listing files. Attach a clean photo of a restaurant receipt named `sample-receipt.jpg` in App Review Information, taken on a real iPhone (not a mockup). The notes say it is attached. |
| Review contact (name, phone, email) | needs owner | Required by App Store Connect; not shown to customers. |
| Sign-in information | done | None required: no accounts. Leave "Sign-in required" off. |

## 4. Compliance answers

| Item | Status | Answer / source |
| ---- | ------ | --------------- |
| **Privacy policy URL** | needs owner | Required for every app. The text is [PRIVACY_POLICY.md](PRIVACY_POLICY.md), not published. Publish it (options in [APP_STORE_PRIVACY.md](APP_STORE_PRIVACY.md#publishing-the-policy-later)); the in-app link to it also has to exist (Guideline 5.1.1). |
| Policy contact placeholder | needs owner | The same contact that is a TODO in the listing; replace the placeholder at the end of both sections of the policy before publishing. |
| **App privacy questionnaire** ("nutrition label") | needs paid enrollment | "Data Not Collected" and "does not track". The full reasoning is in [APP_STORE_PRIVACY.md](APP_STORE_PRIVACY.md). |
| **Export compliance** | done in code, needs paid enrollment to answer | `ITSAppUsesNonExemptEncryption = NO` is already in the build, so uploads skip the question: the app uses no encryption of its own (no network code). If the app ever adds networking beyond Apple's own, revisit. |
| **Age rating** | needs paid enrollment | Answer every item in Apple's questionnaire **None**: parental controls, age assurance, unrestricted web access, user-generated content, messaging and chat, advertising, profanity, horror, alcohol/tobacco/drugs, medical, health topics, sexual or suggestive content, violence of every kind, gambling, contests, loot boxes. Expected result **4+**. Apple's questionnaire changes; confirm the question list on the day. |
| Content: nothing about payments | done | The app only calculates and shares text; it does not process payments or handle money. That keeps it out of the financial-service rules; the category is Finance only as a label. |
| Digital Services Act trader status | needs owner | The EU asks developers who sell in the EU to declare if they are a trader. A free app without a business behind it can answer "not a trader"; the owner decides and may simply not distribute in the EU at first. |
| Camera permission wording | done | Spanish and English, in `InfoPlist.xcstrings`, shown only when the user taps Scan. |

## 5. TestFlight and Xcode Cloud

| Item | Status | Notes |
| ---- | ------ | ----- |
| Archive and upload the first build | needs paid enrollment | Xcode: Product > Archive > Distribute App > App Store Connect. Apple processes the build for several minutes. |
| Internal TestFlight testing | needs paid enrollment | Add up to 100 internal testers (people with App Store Connect roles). No review needed. |
| External TestFlight testing | needs paid enrollment | The first build of a version goes through a short beta App Review (the review notes help). Public link or invited emails, up to 10,000 testers. |
| Test a real receipt, Spanish and English, light and dark, on at least two iPhone sizes | needs owner | Use the scenarios in [REQUIREMENTS.md](REQUIREMENTS.md). |
| Xcode Cloud (optional) | needs paid enrollment | Connect the repository in Xcode (Product > Xcode Cloud); a workflow that archives on a tag and sends to TestFlight. The free monthly compute hours of the paid program are plenty for this app. The project already builds with no secrets and no team id in the repository, which is what Xcode Cloud wants. Not required: manual archive works. |
| Build numbers | needs paid enrollment | If Xcode Cloud is used, let it set `CURRENT_PROJECT_VERSION` (`$CI_BUILD_NUMBER` through an `ci_scripts/ci_post_clone.sh` or the workflow's setting); otherwise bump by hand each upload. |

## 6. Trademark, name and domain (from the pre-launch reminder, issue 31)

| Item | Status | Notes |
| ---- | ------ | ----- |
| Search USPTO for `Esplitéalo` / `Esplitealo` | needs owner | Classes 9 (software) and 42. Also search similar spellings and the Spanish verb form. |
| Search the Puerto Rico registries | needs owner | The Departamento de Estado de Puerto Rico keeps its own trademark register. |
| Search the App Store for the name | needs owner | The name must be unique among apps; `Esplitéalo` and `Esplitealo` both. |
| The television-character risk of the mascot name and look | needs owner | Issue 31 records that the risk was accepted earlier for the markets Puerto Rico and the United States; review it again before launch. The listing drafts avoid every reference to the character, its barrel, cap and striped shirt, and a test keeps it that way. Decide whether the in-app mascot name `Chavito` stays. |
| Replace the bundle id placeholder | done | `com.esplitealo.app` is the final id (issue 31's remark is out of date); only the trademark check above can still change it, and it must happen before registering the id. |
| Domain for support, marketing and the policy | needs owner | Register a domain you control; use it for the three URLs and a contact mailbox. Check that `esplitealo.app` / `.com` are free. |
| Contact mailbox that is not personal | needs owner | One address used in the privacy policy, the support page and the review contact. |

## 7. Submit (last, by the owner)

| Item | Status | Notes |
| ---- | ------ | ----- |
| Select the build in the version page, fill every required field, **Add for Review** | needs paid enrollment | Do not do this until sections 1 to 6 are green and a TestFlight build has been used on a real iPhone. |
| Phased release | needs owner | Optional: release to all at once is fine for a first version. |
| After approval | needs owner | Set the release date, share the store link; the support page and policy must stay live. |

## What was prepared here (all `done`)

- Spanish (Puerto Rico) and English listing drafts, with limits checked by a unit test: [store/es.md](store/es.md), [store/en.md](store/en.md).
- A screenshot generator that needs no Mac and no extra tools: [store/README.md](store/README.md).
- This checklist.
