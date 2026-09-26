# Shelfie (working name)

A reading tracker for iPhone. Your books sit in a real 3D bookcase in a sunny room. Each compartment of the bookcase is a category, and every book's thickness comes from its page count.

- **Bookshelf:** a 3D room built with RealityKit. Tap a compartment to look closer, then tap a spine to open that book. The glass chips along the bottom do the same thing with bigger tap targets.
- **Books:** title, author, page count, category, status (Want to read / Reading / Finished), spine color, a daily page goal, and notes.
- **Streaks:** each book has its own streak. It counts the days in a row with at least one logged reading session. There's also an overall streak.
- **Calendar:** a month grid with one dot per book read that day. Tap a day to see its sessions.
- **Reminders:** local notifications only. There's a daily reminder, and a "streak at risk" alert at 8 PM.
- **Money:** free for up to 10 books in 3 categories. A one-time **Unlock** purchase (a non-consumable in-app purchase) gives unlimited books and all 10 compartments.

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

## In-app purchase

- **Product ID:** `com.cmtania.shelfie.unlock` (non-consumable)
- **Local testing:** the scheme runs with `Shelfie/Resources/Products.storekit`, so purchases work in the simulator with no App Store Connect setup. If Xcode says the file is invalid, create a new StoreKit Configuration File with that product ID and point the scheme at it (Edit Scheme → Run → Options).
- **Before release:** create the same product in App Store Connect. The suggested price is ₱249 on the PH storefront, about $4.99 in the US.

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

## Before submitting to the App Store

- [ ] App icon (1024×1024) in `Assets.xcassets/AppIcon`
- [ ] Check the app name "Shelfie" is free on the App Store, or rename it
- [ ] Host `PRIVACY.md` at a public URL, and update `AppLinks.privacy` if it moves
- [ ] Create the IAP product in App Store Connect and add it to the first submission
- [ ] App Privacy label: **Data Not Collected**
- [ ] Screenshots: the 3D shelf, a close-up of one compartment, book detail with streak, and the calendar
- [ ] Check layout on iPhone SE (375×667) and on iPad in iPhone-compatibility mode
