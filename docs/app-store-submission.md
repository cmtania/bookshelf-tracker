# Shelfie: App Store submission

Everything App Store Connect asks for, ready to paste, for version **1.0.0**. Fields are listed in the order they appear in App Store Connect. The character counts are within Apple's limits.

---

## 1. App information (App Store Connect → your app → App Information)

| Field | Value |
|---|---|
| **Name** (max 30) | `Shelfie: Reading Books Tracker` (29) |
| **Subtitle** (max 30) | `Your books on a 3D bookshelf` |
| **Bundle ID** | `com.cmtania.shelfie` |
| **SKU** | `shelfie-ios` |
| **Primary language** | English (U.S.) |
| **Primary category** | Books |
| **Secondary category** | Productivity |
| **Content rights** | "No, it does not contain, show, or access third-party content." Users type their own book titles. The app doesn't include or download any book content. |
| **Age rating** | Answer **None / No** to every question → **4+** |

**App price:** Free (Pricing and Availability → Add Pricing → Philippines → Free). Available in all 175 countries or regions. Tax category: App Store software. "iPhone and iPad Apps on Apple Silicon Macs" and Apple Vision Pro: **off** until they've been tested there.

---

## 2. Pricing and availability

| Field | Value |
|---|---|
| **Price** | Free (Shelfie Pro is sold as in-app purchases) |
| **Availability** | All countries or regions |
| **Devices** | iPhone and iPad (native iPad layout). Review may test on an iPad, so check it there before submitting (BuzzBee was rejected for its iPad layout). |

---

## 3. In-app purchases (attach both to version 1.0.0)

| | Pro Lifetime | Pro Monthly |
|---|---|---|
| **Where** | Monetization → In-App Purchases | Monetization → Subscriptions → group **Shelfie Pro** |
| **Type** | Non-Consumable | Auto-Renewable, **1 Month** |
| **Reference Name** | Shelfie Pro Lifetime | Shelfie Pro Monthly |
| **Product ID** | `com.cmtania.shelfie.unlock` | `com.cmtania.shelfie.pro.monthly` |
| **Price** (base: Philippines) | ₱249.00 | ₱59.00 |
| **Display Name** | Shelfie Pro Lifetime | Shelfie Pro Monthly |
| **Description** (max 55) | `Pay once: unlimited books, 10 shelves, room colors.` | `Unlimited books, 10 shelves and room colors, monthly.` |
| **Family Sharing** | Off | Off |
| **Review screenshot** | The paywall with **Lifetime** selected | The paywall with **Monthly** selected |
| **Review notes** | See section 8 | See section 8 |

Also give the **subscription group** "Shelfie Pro" its own App Store Localization, with the Display Name `Shelfie Pro`.

**Before either product can be sold:** App Store Connect → **Business** → the **Paid Apps agreement** must be **Active**, with your banking and tax details filled in.

After the first release, a new in-app purchase can only be submitted together with a new app version. For 1.0.0, add both products on the version page under **In-App Purchases and Subscriptions** before you click **Add for Review**.

---

## 4. Version 1.0.0 (the version page)

### Promotional text (max 170, can be changed anytime without review)

```
Your books, on a real 3D bookshelf. Log pages in seconds, keep a streak for every book and share your shelf. Free to start.
```

### Description (max 4000)

```
Shelfie is a reading tracker where your books live on a real 3D bookshelf.

Every category is a compartment of your bookcase. Thick books look thick, the one you're reading sticks out with a bookmark ribbon, and your to-read pile lies flat, just like at home. Tap a shelf to look closer, then tap a spine and the book slides out and turns to show its cover.

LOG READING IN SECONDS
• Type the page you're on, or how many pages you read
• Add minutes if you like, or log a session for earlier
• Mark a book finished when you reach the last page

A STREAK FOR EVERY BOOK
• Each book keeps its own reading streak, plus one for all your reading
• A gentle daily reminder at the time you choose
• An evening heads-up when a streak is about to slip, and never on days you've already read

NOTES AND HISTORY
• Save quotes and thoughts with the page they came from
• Every reading session, with pages and minutes
• A calendar that shows your week at a glance, with a dot for each book you read, and expands to the whole month

CATEGORIES WITH THE NUMBERS THAT MATTER
• Books, pages read, what you're reading now and a streak for each category
• Rename, recolor and rearrange your shelves anytime

SHARE YOUR SHELF
• Turn your bookcase into a clean picture for Instagram, Messages or anywhere else

PRIVATE BY DESIGN
• No account and no sign-in
• No ads, no analytics, no tracking
• Your library stays on your iPhone

SHELFIE PRO
Free for up to 10 books in 3 categories. Shelfie Pro adds:
• Unlimited books
• All 10 bookcase compartments
• Room colors for the bookcase, walls and floor, including premium lacquers, brass, and marble or herringbone floors

Get Pro with a one-time Lifetime purchase, or with a monthly subscription.

Subscription details: Pro Monthly is an auto-renewing subscription. Payment is charged to your Apple Account when you confirm the purchase. It renews automatically each month unless cancelled at least 24 hours before the end of the current period, and your account is charged for renewal within 24 hours before the period ends. You can manage or cancel your subscription in your Apple Account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://cmtania.github.io/bookshelf-tracker-docs/privacy.html
```

### Keywords (max 100, comma-separated, no spaces)

```
book,log,streak,bookshelf,journal,goals,library,pages,habit,notes,planner,tbr,diary,read,counter,3d
```

This is 99 characters. The words in the name and subtitle ("Shelfie", "Reading", "Books", "Tracker", "3D", "bookshelf") are already indexed, so they don't need repeating here. Never add other apps' names, such as Goodreads; that's a rejection reason.

### URLs

| Field | Value |
|---|---|
| **Support URL** | `https://cmtania.github.io/bookshelf-tracker-docs/support.html` |
| **Marketing URL** | `https://cmtania.github.io/bookshelf-tracker-docs/` |
| **Privacy Policy URL** (in App Privacy) | `https://cmtania.github.io/bookshelf-tracker-docs/privacy.html` |

The website must be **live** before you submit, because App Review opens these links. Push `bookshelf-tracker-docs` and turn on GitHub Pages first.

### Copyright

```
2026 Christian Tania
```

---

## 5. App Privacy (App Store Connect → App Privacy)

- **Privacy Policy URL:** as above.
- **"Do you or your third-party partners collect data from this app?"** → **No, we do not collect data from this app.**
- The label shows **Data Not Collected**. This matches the app: there's no account, server, analytics or SDKs, notifications are local, purchases go through Apple, and `PrivacyInfo.xcprivacy` is included in the app.

---

## 6. Screenshots

**Required:** the **6.9" iPhone** size, **1320 × 2868** pixels, portrait. Apple scales it down for smaller iPhones. You can upload 3 to 10 screenshots. Take them in the **iPhone 17 Pro Max** simulator with **Cmd+S**; they save to the Desktop at the right size.

**Also required, because the app supports iPad:** the **13" iPad** size, **2064 × 2752** pixels portrait (or 2752 × 2064 landscape), 3 to 10 screenshots. Take them in the **13-inch iPad Pro** simulator with **Cmd+S**. Apple scales them down for smaller iPads. A good set: the shelf in landscape, room colors with the side panel open, a book up close, and the calendar.

Use made-up book titles in the screenshots, not real bestsellers, just as the website does.

Suggested set and captions:

| # | Screen | Caption |
|---|---|---|
| 1 | Bookshelf, zoomed out, a full shelf | **Your books, on a real 3D bookshelf** |
| 2 | A book pulled out, showing its cover with Log reading and Edit | **Pull a book out and pick up where you left off** |
| 3 | Log reading screen with the progress ring and streak | **A reading streak for every book** |
| 4 | Calendar, week view with dots and sessions | **Your week of reading at a glance** |
| 5 | Categories tab with stats | **Every shelf, with the numbers that matter** |
| 6 | Room colors picker over a premium-colored room | **Make the room yours** |
| 7 | Share sheet with the shelf picture | **Share your shelf** |

**App preview video (optional):** 15–30 seconds of: zoom into a shelf, pull a book out, turn it, log reading, see the streak.

---

## 7. App Review information

| Field | Value |
|---|---|
| **Sign-in required** | **No.** There are no accounts. |
| **Contact first name** | Christian |
| **Contact last name** | Tania |
| **Phone** | *(your phone number, with country code, e.g. +63 …)* |
| **Email** | tania.dev.ph@gmail.com |

---

## 8. Notes for the reviewer (paste into "Notes")

```
Thank you for reviewing Shelfie.

No account or sign-in is needed. All data is stored on the device only.

HOW TO USE
1. On first launch, a short welcome can be skipped with "Skip".
2. Bookshelf tab: tap a compartment to zoom in, tap + to add a book, then tap the book's spine (or its name in the row at the bottom) to pull it out. "Log reading" records pages read and builds the reading streak.
3. Categories and Calendar tabs show per-category statistics and reading history.

IN-APP PURCHASES (Shelfie Pro)
- Pro Lifetime (com.cmtania.shelfie.unlock): non-consumable, one-time purchase.
- Pro Monthly (com.cmtania.shelfie.pro.monthly): auto-renewable, 1 month.
Both unlock the same features: unlimited books, all 10 bookcase compartments, and room colors.
To see the paywall: Settings tab > "Get Shelfie Pro", or tap the paintbrush on the Bookshelf tab (zoomed out), or try to add an 11th book or a 4th category.
"Restore purchase" is in Settings. Monthly subscribers can open "Manage subscription" from Settings.

NOTIFICATIONS
Reminders are local notifications only (daily reminder and an evening streak alert). The permission is requested during onboarding or when turning reminders on, and is optional.

The 3D bookshelf uses RealityKit and runs on any iPhone that supports iOS 26.
```

---

## 9. Build

| Item | Value / check |
|---|---|
| Version | `MARKETING_VERSION` 1.0.0 in `project.yml` |
| Build | Must be new for every upload: `CURRENT_PROJECT_VERSION` (local archives), or automatic with Xcode Cloud |
| Export compliance | Already answered in the build (`ITSAppUsesNonExemptEncryption = NO`), so App Store Connect won't ask |
| Privacy manifest | `Shelfie/Resources/PrivacyInfo.xcprivacy` is included |
| Upload | Xcode → Product → Archive → Distribute App → TestFlight & App Store, **or** Xcode Cloud (see `ci_scripts/`) |

On the version page, select the build under **Build** once it has finished processing.

---

## 10. Final checklist before "Add for Review"

**Store listing**
- [ ] Name, subtitle, description, keywords, promotional text filled in
- [ ] Support, Marketing and Privacy Policy URLs open in a browser (the website is live)
- [ ] 6.9" iPhone and 13" iPad screenshots uploaded (3–10 each), with made-up book titles only
- [ ] Age rating done (4+), categories set (Books / Productivity)
- [ ] App Privacy: Data Not Collected

**Purchases**
- [ ] Paid Apps agreement **Active** (Business section)
- [ ] Both products are **Ready to Submit**, each with a review screenshot, and attached to version 1.0.0
- [ ] In TestFlight:
  - [ ] Lifetime purchase works
  - [ ] Monthly purchase works, renews and expires
  - [ ] **Restore** works after reinstalling
  - [ ] **Switch to Lifetime** shows the cancel reminder

**App**
- [ ] The paywall shows the subscription terms and the Terms of Use and Privacy links (it does, in `PaywallView`)
- [ ] Tested on a small iPhone (SE-size simulator) and on an iPad in portrait, landscape and Split View: nothing overlaps or is cut off, and room colors open in the side panel
- [ ] A reminder set 1 minute ahead arrives on a real iPhone
- [ ] Onboarding shows on a fresh install, and **Skip** works
- [ ] **Reset all data** works and brings back onboarding

**Submit**
- [ ] App Review information: contact details and notes pasted, "Sign-in required" unchecked
- [ ] Build selected on the version page → **Add for Review** → **Submit for Review**

After it's approved, replace the placeholder `APP_STORE_URL` in `bookshelf-tracker-docs/src/config.js` with the real App Store link, and push the website again.
