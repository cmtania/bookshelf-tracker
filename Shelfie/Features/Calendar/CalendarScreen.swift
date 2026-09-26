import SwiftData
import SwiftUI

/// Month grid with a dot per book read that day, plus the day's sessions.
struct CalendarScreen: View {
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]

    @State private var month = CalendarMath.startOfMonth(.now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    var body: some View {
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Pages in \(month.formatted(.dateTime.month(.wide)))",
                            value: "\(pages(inMonthOf: month))",
                            systemImage: "book.fill",
                            tint: .accentColor
                        )
                        StatCard(
                            title: "Reading streak",
                            value: "\(StreakCalculator().currentStreak(sessions.map(\.date))) days",
                            systemImage: "flame.fill",
                            tint: .orange
                        )
                    }
                    monthCard(byDay)
                    dayList(byDay[selectedDay] ?? [])
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
        }
    }

    // MARK: Month

    private func monthCard(_ byDay: [Date: [ReadingSession]]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous month")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next month")
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(CalendarMath.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(CalendarMath.monthCells(for: month, calendar: calendar).enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, colors: colors(byDay[day] ?? []))
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func dayCell(_ day: Date, colors: [String]) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.accentColor : Color.primary)
                HStack(spacing: 2) {
                    ForEach(colors.prefix(3), id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.18))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityValue(colors.isEmpty ? "No reading" : "\(colors.count) \(colors.count == 1 ? "book" : "books") read")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Day

    private func dayList(_ daySessions: [ReadingSession]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.headline)
            if daySessions.isEmpty {
                Text("No reading logged.")
                    .foregroundStyle(.secondary)
            }
            ForEach(daySessions) { session in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: session.book?.spineColorHex ?? "#999999"))
                        .frame(width: 8, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.book?.title ?? "Deleted book")
                            .font(.subheadline.weight(.semibold))
                        Text("p. \(session.fromPage) → \(session.toPage) · \(session.date.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(session.pagesRead)")
                            .font(.subheadline.weight(.semibold))
                        if let minutes = session.minutes {
                            Text("\(minutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    /// Unique spine colours of the books read that day, in first-read order.
    private func colors(_ daySessions: [ReadingSession]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in daySessions.reversed() {
            guard let hex = session.book?.spineColorHex, !seen.contains(hex) else { continue }
            seen.insert(hex)
            result.append(hex)
        }
        return result
    }

    private func pages(inMonthOf date: Date) -> Int {
        sessions
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.pagesRead }
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) {
            month = CalendarMath.startOfMonth(next, calendar: calendar)
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
        .accessibilityElement(children: .combine)
    }
}
