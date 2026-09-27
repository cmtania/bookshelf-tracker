# Shelfie (working name)

A reading tracker for iPhone. Your books sit in a real 3D bookcase in a sunny room. Each compartment of the bookcase is a category, and every book's thickness comes from its page count.

- **Bookshelf:** a 3D room built with RealityKit. Tap a compartment to look closer, then tap a spine to open that book. The glass chips along the bottom do the same thing with bigger tap targets.
- **Books:** title, author, page count, category, status (Want to read / Reading / Finished), spine color, a daily page goal, and notes.
- **Streaks:** each book has its own streak. It counts the days in a row with at least one logged reading session. There's also an overall streak.
- **Calendar:** a month grid with one dot per book read that day. Tap a day to see its sessions.
- **Reminders:** local notifications only. There's a daily reminder, and a "streak at risk" alert at 8 PM.
- **Money:** free for up to 10 books in 3 categories. **Shelfie Pro** gives unlimited books, all 10 compartments and room colors. It comes as **Pro Lifetime** (one-time purchase, ₱249) or **Pro Monthly** (auto-renewing subscription, ₱59/month). The paywall pre-selects Lifetime and shows how many months it takes to pay for itself.

It needs no account, no server and no third-party SDKs. All data stays on the device.

## Requirements

- A Mac with **Xcode 26** or later
- iOS **26** or later (it uses Liquid Glass)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), which generates the Xcode project from `project.yml`

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Shelfie.xcodeproj
```

1. In **Signing & Capabilities**, choose your team, or set `DEVELOPMENT_TEAM` in `project.yml`.
2. Pick an iPhone simulator and press **Run**.
3. To run the unit tests (streaks, shelf packing, reminder planning, calendar grid), press **Cmd+U**, or run:
   ```sh
   xcodebuild test -scheme Shelfie -destination 'platform=iOS Simulator,name=iPhone 17'
   ```

`Shelfie.xcodeproj` is generated and git-ignored. After you add or move files, run `xcodegen generate` again.

## In-app purchases (Shelfie Pro)

| Plan | Product ID | Type | Price (PH / US) |
|---|---|---|---|
| Pro Lifetime | `com.cmtania.shelfie.unlock` | Non-consumable | ₱249 / $4.99 |
| Pro Monthly | `com.cmtania.shelfie.pro.monthly` | Auto-renewable subscription, 1 month, group "Shelfie Pro" | ₱59 / $0.99 |

- **How it works:** both plans unlock the same features (`UnlockGate`). Lifetime wins if someone has both.
- **Where the status comes from:** it's read from StoreKit's current entitlements at launch, whenever the app comes to the foreground, and on every `Transaction.updates` event. That covers renewals, expiries and refunds.
- **Upgrading:** when a monthly subscriber buys Lifetime, the app asks them to cancel the subscription, which opens the system Manage Subscriptions sheet. Settings keeps showing a reminder while both are active.
- **Local testing:** the scheme runs with `Shelfie/Resources/Products.storekit`, which contains both products. Purchases work in the simulator with no App Store Connect setup.
  - To test renewals and expiry fast, open the `.storekit` file in Xcode and set **Editor → Subscription Renewal Rate** to "Monthly renewal every 30 seconds".
  - If Xcode says the file is invalid, create a new StoreKit Configuration File with both product IDs and point the scheme at it (Edit Scheme → Run → Options).
- **Before release**, in App Store Connect:
  1. Create the non-consumable `com.cmtania.shelfie.unlock` at ₱249.
  2. Create the subscription group **Shelfie Pro** containing the 1-month subscription `com.cmtania.shelfie.pro.monthly` at ₱59.
  3. Add a display name, description and review screenshot (the paywall) to each.
  4. In the app's App Store description, include links to the Terms of Use (Apple's standard EULA) and the Privacy Policy, because App Review requires them for subscriptions.
  5. Attach both products to the first app version you submit.

## Project layout

```
Shelfie/
  App/        ShelfieApp, RootTabView, UnlockGate (StoreKit 2), Prefs
  Models/     SwiftData: Book, BookCategory, ReadingSession, BookNote, Seed
  Room3D/     RoomScene (camera + hit testing), Room/Bookcase/BookEntity factories,
              BookcaseGeometry, ShelfPacker, ShelfSnapshot, TextureFactory
  Features/   Bookshelf, AddBook, BookDetail, Calendar, Settings, Paywall, Shared
  Services/   StreakCalculator, ReminderScheduler, CalendarMath, ColorHex
  Resources/  Assets, Products.storekit, Localizable.xcstrings
ShelfieTests/ Swift Testing unit tests
docs/plan.md  the v1.0 plan
```

## Logo

The final logo is cream shelves and books on an orange (`#FFA500`) tile. Files are in `design/logo/`:

| File | Use |
|---|---|
| `shelfie-applogo.svg` | The original design (master file) |
| `shelfie-logo.svg` | Clean copy with a transparent background: website, App Store page, social media, and the `Logo` image in the app |
| `shelfie-appicon.svg` / `app-icon-1024.png` | The app icon: the same artwork filling a square (iOS adds the rounded corners) |

Inside the app, the logo appears on the paywall and in the credit on the shareable shelf image, as `Image("Logo")`. The tab bar keeps the `books.vertical` symbol, because tab icons must be single-colour template symbols. Other files in `design/logo/` are earlier concepts that aren't used.

## Before submitting to the App Store

- [x] App icon (1024×1024) in `Assets.xcassets/AppIcon`, made from the final logo (see Logo above)
- [ ] Check the app name "Shelfie" is free on the App Store, or rename it
- [ ] Host `PRIVACY.md` at a public URL, and update `AppLinks.privacy` if it moves
- [ ] Create the IAP product in App Store Connect and add it to the first submission
- [ ] App Privacy label: **Data Not Collected**
- [ ] Screenshots: the 3D shelf, a close-up of one compartment, book detail with streak, and the calendar
- [ ] Check layout on iPhone SE (375×667) and on iPad in iPhone-compatibility mode
