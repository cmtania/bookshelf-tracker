# Plan: 3D Book Reading Tracker — iOS, SwiftUI + RealityKit (approved 2026-09-26)

*Working name: "Shelfie" (placeholder; check App Store availability). Decisions: free + one-time Unlock; each compartment = a category; manual entry only; full v1.0 over one weekend; Mac + Xcode 26 ready.*

> **Where the first implementation differs from the plan below**
> - **Settings storage:** app settings (reminder time and toggles, the cached unlock state) live in `UserDefaults`/`@AppStorage` (`Prefs`), not in a SwiftData `AppSettings` row.
> - **Swift language mode:** Swift 5 mode on the Swift 6 compiler. Code was first written without a compiler, and this mode turns strict-concurrency problems into warnings. Switch to Swift 6 once it builds cleanly.
> - **Camera poses:** *overview* and *compartment close-up*. At the overview distance a book spine is only about 6 pt wide, too small to tap, so tapping a compartment zooms in first; tapping a spine then pulls the book out and opens its detail. A glass chip row mirrors the shelf with full-size tap targets and serves as the VoiceOver path.
> - **Reminders:** planned up to 7 days ahead as one-off notifications (at most 9 pending), so today's reminder can be skipped once you've already read.

> **Added or changed after the plan, during the build (27 September 2026).** The plan below is kept as it was approved. The README describes the current app.
> - **App name:** "Shelfie: Reading Books Tracker". The final logo is the flat orange tile in `design/logo/`.
> - **Money:** "Unlock" became **Shelfie Pro**, sold two ways:
>   - **Pro Lifetime** (non-consumable `com.cmtania.shelfie.unlock`, ₱249), pre-selected on the paywall;
>   - **Pro Monthly** (auto-renewing `com.cmtania.shelfie.pro.monthly`, ₱59).
>   - Room colors are Pro as well.
> - **Bookshelf:**
>   - A tapped book flies out of the shelf and shows its cover, with Log reading and Edit.
>   - Zoomed out, the top bar has room colors and share; zoomed in, it has rename and add.
>   - Category labels are bigger, and the walls have a plaster texture.
> - **Room colors:** bookcase, wall and floor presets. Premium options add lacquer and metal finishes, and patterned floors.
> - **Share your shelf:** a 2D image of the bookcase alone.
> - **Categories tab:** a new tab. Category management moved there from Settings.
> - **Calendar:** a compact stats strip, and a week view that expands to the month.
> - **Log reading screen:** it starts at the page progress. Book details and Edit moved under the 3D book.
> - **Categories at first launch:** they start as neutral "Shelf 1–3" names for the user to rename.
> - **Onboarding:** 4 skippable pages, with no paywall.
> - **Settings:** Reset all data, and support contact (Christian Tania, tania.dev.ph@gmail.com).
> - **Number fields:** they accept digits only.
> - **Release:**
>   - a privacy manifest;
>   - an Xcode Cloud post-clone script;
>   - App Store screenshots in `appstore/`;
>   - the website `bookshelf-tracker-docs` (landing, support, privacy, terms);
>   - `docs/app-store-submission.md`.

## Context
The user wants a reading tracker where the home screen is a **3D room with a bookshelf**, and their books sit on it grouped by category. It sets itself apart the same way Subwall does, through a physical, tactile 3D home screen instead of a list. Features: books per category with details (page count and more), notes per book, a reading calendar, notifications, and a **streak per book**. Native iOS only, **one-time payment**. The user wants it done over a weekend, so the scope has to be split into a weekend slice plus follow-up work.

Reference images from the user: a two-column, five-row bookcase (Hum3D render) and an empty white room with a light wood-plank floor. We **build the bookcase procedurally** instead of shipping that model: the Hum3D model is a paid, licensed asset, and a procedural case can grow shelves to fit the number of categories.

## Stack
- SwiftUI, RealityKit (`RealityView`), SwiftData, UserNotifications, StoreKit 2, Swift 6. iOS 26+ with Liquid Glass (same as Subwall/BuzzBee), iPhone portrait.
- Needs a Mac + Xcode 26; Expo/EAS can't build it.
- No server, no account, and no third-party SDKs. App Privacy label: "Data Not Collected".

## Screens
**Tab bar (system Liquid Glass):** Bookshelf · Calendar · Settings.

1. **Bookshelf (home, 3D):** edge-to-edge `RealityView` showing the white room, the wood floor and the bookcase.
   - **Rows are categories:** each shelf row is one category, with a small label plate on the front edge.
   - **Books:** each book is a box. Its **thickness scales with the page count**, and height and spine colour vary. The spine texture shows the title, rendered from a SwiftUI view.
   - **Status reads from the shelf:** books being read stick out a little and have a bookmark ribbon. Want-to-read books lie in a flat stack (like the reference). Finished books stand upright.
   - **Tap a book:** it slides out and the camera eases in, then Book Detail opens as a sheet.
   - **Glass "+" button:** opens Add Book.
   - **Reduce Motion:** the pull-out and camera move become a crossfade. Each book entity has a VoiceOver label ("Dune, page 120 of 412, 5-day streak").
2. **Add/Edit Book:** title, author, total pages, category (or add a new one), status, spine colour, daily page goal (optional), reminders on/off.
3. **Book Detail:**
   - Progress ring (current / total pages), streak flame 🔥 N days, and the best streak.
   - A **"Log reading"** button: enter the page reached (or pages read) and optional minutes.
   - Session history.
   - **Notes:** text, optional page number, date; add, edit and delete.
4. **Calendar:** a month grid where each day shows dots in the colours of the books read that day. Tapping a day lists that day's sessions. Top cards show "Pages this month" and "Current overall streak".
5. **Settings:** manage categories (rename, reorder, colour), a default reminder time, a "streak at risk" alert on/off, Unlock (one-time purchase), Restore, Privacy.

## Streaks and notifications
- **Per-book streak:** the number of consecutive local calendar days with ≥1 `ReadingSession` for that book, counted back from today. If today has no session yet, the streak counts back from yesterday, so it doesn't break until the day ends.
- **Overall streak:** the same rule applied across all books.
- **Notifications (local only):**
  - **Daily reminder** at the global reminder time, for each book set to Reading with reminders on.
  - **"Streak at risk":** at 8 pm if a book with a streak has no session today. Schedule it for today and cancel it when a session is logged.
  - Reschedule on launch, when app becomes active, and after each edit. Keep under iOS's limit of 64 pending notifications.

## Data model (SwiftData, every property optional or defaulted so CloudKit can be added later)
- `Category`: id, name, colorHex, sortIndex (= shelf row).
- `Book`: id, title, author, totalPages, currentPage, status (wantToRead/reading/finished), category, spineColorHex, dailyGoalPages?, remindersOn, startedAt?, finishedAt?, shelfOrder, createdAt.
- `ReadingSession`: book, date, fromPage, toPage, minutes?.
- `BookNote`: book, text, page?, createdAt, updatedAt.
- `AppSettings`: reminderTime, streakAlertEnabled, isUnlocked (cache).

## Project structure
```
Shelfie/
  App/ ShelfieApp.swift, RootTabView.swift, UnlockGate.swift
  Models/ Category.swift, Book.swift, ReadingSession.swift, BookNote.swift, AppSettings.swift
  Room3D/ BookshelfView.swift, RoomScene.swift, BookcaseFactory.swift, BookEntityFactory.swift,
          ShelfPacker.swift, SpineTextureRenderer.swift, CameraRig.swift
  Features/ AddBook/, BookDetail/ (LogReadingSheet, NotesSection), Calendar/, Settings/, Paywall/
  Services/ StreakCalculator.swift, ReminderScheduler.swift, StoreManager.swift
  Resources/ Assets.xcassets (wood floor texture), Localizable.xcstrings, Products.storekit
ShelfieTests/ StreakCalculatorTests, ShelfPackerTests, ReminderSchedulerTests
```
Repo: a new folder at `z:\Git\<name>`. Since this Windows shell has no GitHub login, you push it yourself (same as Subwall).

## 3D (RealityKit)
- **`RoomScene`:** a floor plane with a wood-plank PBR texture, three white wall planes and a ceiling (matching reference image 2), one directional light and a soft fill light.
- **`BookcaseFactory`:** builds the frame (sides, top, base, back panel, shelf boards) from boxes.
  - **Case size:** 2 columns × 5 rows = 10 compartments. Compartment `i` holds category `sortIndex == i`. Empty compartments show a faint "+ Add category" plate.
- **`BookEntityFactory`:** a box mesh sized from the page count (≈ 0.1 mm per page, clamped), with the spine texture from `ImageRenderer` and cached per book.
  - **Packing:** books pack left to right inside their compartment. When a compartment is full, the rest lie flat as a stack on top (like the reference), and a "+N" plate shows any that don't fit.
- **`CameraRig`:** poses `.overview` and `.bookFocus(book)`, animated with `move(to:)` (0.6 s). Framing is worked out from the aspect ratio so it fits on iPhone SE.
- **Target:** 60 fps with ~100 books; shared meshes, cached textures.

## Monetization (decided: free + one-time Unlock)
- **Free:** up to **10 books and 3 categories**, plus every feature: 3D shelf, notes, streaks, calendar and reminders.
- **Unlock (non-consumable, lifetime):** unlimited books and up to 10 categories.
  - **Price:** suggested ₱249 on the PH base storefront (≈ $4.99 US); adjust as you like.
- **Paywall:** shown only when you try to add the 11th book or the 4th category, or from the Settings Unlock row. It has a clear ✕, the price from `Product.displayPrice`, and Restore/Terms/Privacy.
- **StoreKit 2:** `Product.purchase()`, `Transaction.currentEntitlements` and `Transaction.updates`, behind a single `UnlockGate` observable. No SDK.

## Scope: full v1.0 over one weekend (decided)
Getting everything done in 2 days means **hard simplifications**. The build fits them because we cut the extras, not the features:
- **One bookcase with 10 compartments** (2 columns × 5 rows). Each compartment is a category, capped at 10 categories. There's no second bookcase and no camera panning.
- **Camera:** two poses only, overview and book focus.
- **Reminders:** one global daily reminder time (set in Settings, per-book on/off) plus the per-book "streak at risk" alert. No separate time per book.
- **Books:** no cover photos and no ISBN scan. The spine colour and title are the book's look.
- **Accessibility:** a Reduce Motion crossfade and VoiceOver labels on book entities. The 2D list fallback is deferred.

**Schedule (~18 focused hours):**

| Block | Build |
|---|---|
| **Sat AM (~4h)** | Xcode project, SwiftData models, `StreakCalculator` + tests, Add/Edit Book form, category CRUD |
| **Sat PM (~5h)** | `RoomScene` (walls, wood floor, lights), `BookcaseFactory`, `BookEntityFactory` + spine textures, shelf packing, tap → pull out → Book Detail |
| **Sun AM (~4h)** | Book Detail (progress, Log reading, sessions, notes CRUD, streak flame), Calendar tab (month dots, day list, top cards) |
| **Sun PM (~5h)** | `ReminderScheduler`, Settings, `.storekit` + `UnlockGate` + paywall + limits, iPhone SE/iPad-compat check, TestFlight build |
| **Following week** | Privacy policy page, App Store screenshots, listing, submit |

**Deferred to v1.1:** cover photos and ISBN scan, a separate reminder time per book, a second bookcase or room themes, iCloud sync, widgets (current streak), the 2D list view.

**Risk:** the Saturday PM 3D block is the one most likely to overrun. The fallback is to ship spines as solid colours with the title rendered once, and to animate the pull-out only (no camera move).

## Verification
- **Unit tests:**
  - **`StreakCalculator`:** today vs yesterday, gaps, time zones and DST, multiple sessions in one day.
  - **Shelf packing:** overflow to the next column and the next case.
  - **Notification scheduling:** stays under 64 pending.
- **Simulator:**
  - Add 3 categories and 12 books; the shelf rebuilds correctly.
  - Log a reading session; the streak increments, and a dot appears on the calendar.
  - Kill and relaunch; everything persists.
- **Device:** a reminder set 1 minute out fires; the streak-at-risk alert is cancelled after logging; 60 fps in Instruments.
- **StoreKit:** a local `.storekit` file.
  - The 11th book and the 4th category show the paywall.
  - Buying lifts the limits; after a reinstall, Restore brings the unlock back.
  - The ✕ always closes the paywall.
- **Screen sizes:** iPhone SE (375×667): the whole bookcase fits between the top bar and the tab bar, and forms scroll. Also check a Pro Max and an iPad in iPhone-compatibility mode (BuzzBee's rejection lesson).
