import Testing
@testable import Shelfie

/// The card shown after Log reading picks the right message for what just happened.
struct ReadingCelebrationTests {
    @Test func finishingABookWinsOverEverything() {
        let logged = LoggedReading(pagesGained: 40, previousStreak: 6, streak: 7, finishedTitle: "The Quiet Orchard", totalPages: 384)
        #expect(logged.kind == .finished)
        #expect(logged.headline == "You finished The Quiet Orchard!")
        #expect(logged.icon == "ph-seal-check-fill")
    }

    @Test func milestoneStreaksGetTheirOwnMessage() {
        let logged = LoggedReading(pagesGained: 12, previousStreak: 6, streak: 7)
        #expect(logged.kind == .milestone)
        #expect(logged.headline == "7 days in a row!")
    }

    @Test func firstSessionStartsAStreak() {
        let logged = LoggedReading(pagesGained: 1, previousStreak: 0, streak: 1)
        #expect(logged.kind == .streakGrew)
        #expect(logged.headline == "Streak started")
        #expect(logged.detail.hasPrefix("+1 page."))
    }

    @Test func secondSessionTheSameDayKeepsTheStreak() {
        let logged = LoggedReading(pagesGained: 24, previousStreak: 5, streak: 5)
        #expect(logged.kind == .streakKept)
        #expect(logged.headline == "+24 pages")
        #expect(logged.detail == "Your 5-day streak is safe today.")
    }

    @Test func minutesWithoutNewPagesStillCount() {
        let logged = LoggedReading(pagesGained: 0, previousStreak: 2, streak: 2)
        #expect(logged.kind == .timeOnly)
        #expect(logged.headline == "Time well spent")
    }
}
