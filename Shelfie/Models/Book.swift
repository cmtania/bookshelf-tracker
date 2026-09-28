import Foundation
import SwiftData

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case wantToRead, reading, finished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wantToRead: "Want to read"
        case .reading: "Reading"
        case .finished: "Finished"
        }
    }

    var symbol: String {
        switch self {
        case .wantToRead: "ph-bookmark-simple"
        case .reading: "ph-book-open"
        case .finished: "ph-check-circle"
        }
    }
}

// Every property is optional or defaulted, so a CloudKit-backed container can be added later.
@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var totalPages: Int = 0
    var currentPage: Int = 0
    var statusRaw: String = ReadingStatus.wantToRead.rawValue
    var spineColorHex: String = "#1F3A68"
    var dailyGoalPages: Int?
    var remindersOn: Bool = true
    var startedAt: Date?
    var finishedAt: Date?
    var shelfOrder: Int = 0
    var createdAt: Date = Date()

    var category: BookCategory?

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var sessions: [ReadingSession]? = []

    @Relationship(deleteRule: .cascade, inverse: \BookNote.book)
    var notes: [BookNote]? = []

    init(title: String = "", author: String = "", totalPages: Int = 0) {
        self.title = title
        self.author = author
        self.totalPages = totalPages
    }

    var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusRaw) ?? .wantToRead }
        set { statusRaw = newValue.rawValue }
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, Double(currentPage) / Double(totalPages))
    }

    var sessionDates: [Date] {
        (sessions ?? []).map(\.date)
    }

    var sortedSessions: [ReadingSession] {
        (sessions ?? []).sorted { $0.date > $1.date }
    }

    var sortedNotes: [BookNote] {
        (notes ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    /// Changes the status and keeps the start/finish dates consistent.
    func setStatus(_ newStatus: ReadingStatus, now: Date = .now) {
        status = newStatus
        switch newStatus {
        case .wantToRead:
            finishedAt = nil
        case .reading:
            if startedAt == nil { startedAt = now }
            finishedAt = nil
        case .finished:
            if startedAt == nil { startedAt = now }
            finishedAt = now
            currentPage = max(currentPage, totalPages)
        }
    }
}
