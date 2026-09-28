# Shelfie: Reading Books Tracker

A reading tracker for iPhone. Your books sit in a real 3D bookcase in a room you can color yourself. Each compartment of the bookcase is a category, and every book's thickness comes from its page count.

## Features

- **Bookshelf (3D, RealityKit):**
  - Tap a compartment to zoom in. Tap a spine and the book slides out with a soft sound, flies up and turns to show its cover, with **Log reading** and **Edit** below. Drag to turn it; tap anywhere else to put it back.
  - Pinch with two fingers to zoom in or out (toward your fingers, up to 3×), and drag with one finger to look around while zoomed in.
  - The sound follows the silent switch, doesn't stop your music, and can be turned off in Settings > Sound effects. It's synthesised by `design/sounds/make-book-sound.mjs` (no third-party audio).
  - Reading books stick out with a ribbon, and want-to-read books lie flat.
  - When zoomed out, the top bar has room colors and share. When zoomed in, it has rename and add book.
- **Books:** title, author, page count, category, status (Want to read / Reading / Finished), spine color, daily page goal, notes and reading sessions.
- **Streaks:** per book, per category and overall. A streak counts the days in a row with at least one logged session, and it doesn't break until the day is over.
- **Categories tab:** one card per category, with its position on the bookcase, books by status, pages progress, what's being read and its streak. You can add, reorder (which moves the compartments), rename, recolor and delete (only when empty).
- **Calendar tab:** opens on the current week and expands to the month (tap the title or handle, or swipe). Each day shows dots in spine colors, and tapping a day shows its sessions.
- **Room colors (Pro):** bookcase, wall and floor presets. Premium options include lacquers and metals, designer wall colors, and herringbone, marble, terrazzo and checker floors. The walls have a subtle plaster texture.
- **Share your shelf:** a 1080 × 1350 picture of the bookcase alone (no room), made in 2D from the same layout.
- **Reminders:** local notifications only. There's a daily reminder, plus a "streak at risk" alert at 8 PM.
- **Onboarding:** 4 skippable pages on first launch (welcome, name your 3 shelves, logging and streaks, reminders). It has no paywall.
- **Settings:** Pro status and management, reminders, **Reset all data** (type CONFIRM; it brings back onboarding), and **About Shelfie**. The About sheet shows the logo, name, version, Help & FAQ, Privacy Policy, Terms of Service and contact support. Room colors are only on the Bookshelf tab (the paintbrush).
- **Money:** free for up to 10 books in 3 categories. **Shelfie Pro** gives unlimited books, all 10 compartments and room colors. It comes as **Pro Lifetime** (one-time, ₱249) or **Pro Monthly** (auto-renewing, ₱59/month). The paywall pre-selects Lifetime and shows how many months it takes to pay for itself.

It needs no account, no server and no third-party SDKs. All data stays on the device.

## Requirements

- A Mac with **Xcode 26** or later
- iOS / iPadOS **26** or later (it uses Liquid Glass). The app runs on iPhone (portrait) and iPad (any orientation, Split View and resizable windows). On iPad, room colors open in a side panel next to the room, and the book card, calendar and onboarding keep a readable width.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), which generates the Xcode project from `project.yml`

## Getting started

```sh
brew install xcodegen
xcodegen generate
open Shelfie.xcodeproj
```

1. Signing uses the team in `project.yml` (`DEVELOPMENT_TEAM`), with automatic signing.
2. Pick an iPhone simulator and press **Run**.
3. To run the unit tests (streaks, shelf packing, reminder planning, calendar weeks and months), press **Cmd+U**.

`Shelfie.xcodeproj` is generated and git-ignored. After you add, move or pull new files, run `xcodegen generate` again.

## In-app purchases (Shelfie Pro)

| Plan | Product ID | Type | Price (PH / US) |
|---|---|---|---|
| Pro Lifetime | `com.cmtania.shelfie.unlock` | Non-consumable | ₱249 / $4.99 |
| Pro Monthly | `com.cmtania.shelfie.pro.monthly` | Auto-renewable subscription, 1 month, group "Shelfie Pro" | ₱59 / $0.99 |

- **How it works:** both plans unlock the same features (`UnlockGate`). Lifetime wins if someone has both.
- **Where the status comes from:** StoreKit's current entitlements, read at launch, whenever the app comes to the foreground, and on every `Transaction.updates` event. That covers renewals, expiries and refunds.
- **Upgrading:** when a monthly subscriber buys Lifetime, the app asks them to cancel the subscription, which opens the system Manage Subscriptions sheet.
- **If prices don't load:** the paywall shows **Try again**. Debug builds print any missing product IDs to the Xcode console.
- **Local testing:** the Run scheme uses `Shelfie/Resources/Products.storekit`. The most reliable version is one synced from App Store Connect: **File → New → StoreKit Configuration File → Sync with App Store Connect**. For quick renewal tests, open the file and choose **Editor → Subscription Renewal Rate**.
- **App Store Connect:** both products exist. The Paid Apps agreement, bank and tax details are active.

## Building for TestFlight

- **From the Mac:**
  1. Raise `CURRENT_PROJECT_VERSION` in `project.yml`, then run `xcodegen generate`.
  2. Set the destination to **Any iOS Device**, then choose **Product → Archive**.
  3. Choose **Distribute App** → **TestFlight & App Store**.
- **With Xcode Cloud:** `ci_scripts/ci_post_clone.sh` installs XcodeGen and generates the project after cloning. The script must stay executable (`git update-index --chmod=+x`), and `.gitattributes` keeps it at Unix line endings.
- **Required by App Store Connect:** `Shelfie/Resources/PrivacyInfo.xcprivacy`, the privacy manifest. Shelfie collects no data and uses UserDefaults with reason CA92.1.

## App Store

- **Everything to paste into App Store Connect:** [`docs/app-store-submission.md`](docs/app-store-submission.md). It covers the name, subtitle, description, keywords, in-app purchases, privacy, review notes and a final checklist.
- **Screenshots (6.9", 1320 × 2868):** the simulator captures go in `appstore/raw/`. Run `powershell -ExecutionPolicy Bypass -File appstore\render.ps1` on Windows to make the framed promo images in `appstore/final/`. Captions and order are set in `render.ps1`, and the design is in `appstore/template.html`.
- **Website** (support, privacy, terms): the `bookshelf-tracker-docs` repo, published at https://cmtania.github.io/bookshelf-tracker-docs/
- **Support contact:** Christian Tania, tania.dev.ph@gmail.com

## Project layout

```
Shelfie/
  App/         ShelfieApp, RootTabView (tabs, onboarding cover), UnlockGate (StoreKit 2), Prefs
  Models/      SwiftData: Book, BookCategory, ReadingSession, BookNote; Seed and DataReset
  Room3D/      RoomScene (camera, fly-out book, hit testing), RoomTheme, Room/Bookcase/BookEntity factories,
               BookcaseGeometry, CompartmentLayout, ShelfPacker, ShelfSnapshot,
               TextureFactory, FloorPainter, WallPainter
  Features/    Bookshelf, Categories, AddBook, BookDetail (Log reading, notes, sessions), Calendar,
               Settings, Paywall, Onboarding, Theme (room colors), Share, Shared (NumberField, swatches)
  Services/    StreakCalculator, ReminderScheduler, CalendarMath, ColorHex
  Resources/   Assets (AppIcon, Logo, AccentColor), Products.storekit, PrivacyInfo.xcprivacy, Localizable.xcstrings
ShelfieTests/  Swift Testing unit tests
ci_scripts/    Xcode Cloud post-clone script (XcodeGen)
appstore/      App Store screenshots: raw/ captures, final/ framed images, template.html, render.ps1
design/logo/   The final logo (see below)
docs/          plan.md (the original v1.0 plan, with what changed since), app-store-submission.md
```

## Logo

The final logo is cream shelves and books on an orange (`#FFA500`) tile. The files are in `design/logo/`:

| File | Use |
|---|---|
| `shelfie-applogo.svg` | The original design (master file) |
| `shelfie-logo.svg` | Clean copy with a transparent background: website, App Store page, social media, and the `Logo` image in the app |
| `shelfie-appicon.svg` / `app-icon-1024.png` | The app icon: the same artwork filling a square (iOS adds the rounded corners) |

Inside the app, the logo appears in onboarding, on the paywall and in the credit on the share image, as `Image("Logo")`.

### Icons

The app's icons are [Phosphor Icons](https://phosphoricons.com) (MIT licence), Regular weight, plus Fill for the tab bar and filled states. They are stored as custom SF Symbols in `Shelfie/Resources/Assets.xcassets/Phosphor/`, so they scale with the text, take the text colour and line up like system symbols. Use them as `Image("ph-books")` or `Label("Title", image: "ph-books")`.

To add more, use the Phosphor file name (add `-fill` for the filled version) and run:

```sh
node design/icons/make-symbols.mjs bookmark-simple heart-fill
```

It downloads the icons (Phosphor 2.1.1) and writes one `ph-<name>.symbolset` for each. It needs Node 18+ and internet, and adds nothing to the app except those files.
