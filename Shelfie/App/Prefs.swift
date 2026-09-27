import Foundation

/// Small app-wide settings, kept in UserDefaults (views bind to them with @AppStorage).
/// Defaults here must match the @AppStorage defaults in SettingsScreen.
enum Prefs {
    static let remindersEnabledKey = "remindersEnabled"
    static let reminderMinutesKey = "reminderMinutes"
    static let streakAlertEnabledKey = "streakAlertEnabled"
    static let unlockedCacheKey = "unlockedCache"
    /// "lifetime" or "monthly" while Shelfie Pro is active (see UnlockGate).
    static let planCacheKey = "proPlanCache"
    static let didSeedKey = "didSeedCategories"
    static let onboardingDoneKey = "onboardingDone"
    static let shelfColorKey = "theme.shelf"
    static let wallColorKey = "theme.wall"
    static let floorColorKey = "theme.floor"
    static let bookcaseStyleKey = "theme.style"

    static let defaultReminderMinutes = 19 * 60
    /// The "streak at risk" alert always goes out at 8 PM.
    static let streakAlertMinutes = 20 * 60

    static var remindersEnabled: Bool {
        UserDefaults.standard.object(forKey: remindersEnabledKey) as? Bool ?? true
    }

    static var reminderMinutes: Int {
        UserDefaults.standard.object(forKey: reminderMinutesKey) as? Int ?? defaultReminderMinutes
    }

    static var streakAlertEnabled: Bool {
        UserDefaults.standard.object(forKey: streakAlertEnabledKey) as? Bool ?? true
    }
}
