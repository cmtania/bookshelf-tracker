import SwiftData
import SwiftUI

/// Reading calendar: a slim stats strip, then the current week (tap or swipe down to see the
/// whole month), then the sessions logged on the selected day, which get most of the screen.
struct CalendarScreen: View {
    @Query(sort: \ReadingSession.date, order: .reverse) private var sessions: [ReadingSession]

    /// Any day inside the visible week (collapsed) or month (expanded).
    @State private var anchor = Calendar.current.startOfDay(for: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var expanded = false

    private let calendar = Calendar.current

    var body: some View {
        let byDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    statsStrip
                    calendarCard(byDay)
                    dayList(byDay[selectedDay] ?? [])
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
        }
    }

    // MARK: Stats

    /// One slim row instead of two tall cards: pages in the visible week/month, and the streak.
    private var statsStrip: some View {
        let streak = StreakCalculator().currentStreak(sessions.map(\.date))
        return HStack(spacing: 0) {
            stat(
                icon: "ph-book-open-fill",
                tint: .accentColor,
                value: "\(pagesInVisiblePeriod)",
                label: expanded ? "pages in \(anchor.formatted(.dateTime.month(.wide)))" : "pages this week"
            )
            Divider().frame(height: 28)
            stat(
                icon: "ph-flame-fill",
                tint: .orange,
                value: "\(streak)",
                label: "day streak"
            )
        }
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func stat(icon: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(icon)
                .font(.subheadline)
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Week / month

    private func calendarCard(_ byDay: [Date: [ReadingSession]]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Button {
                    shift(-1)
                } label: {
                    Image("ph-caret-left").frame(width: 44, height: 44)
                }
                .accessibilityLabel(expanded ? "Previous month" : "Previous week")

                Button {
                    toggleExpanded()
                } label: {
                    HStack(spacing: 6) {
                        Text(periodTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Image("ph-caret-down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(periodTitle)
                .accessibilityHint(expanded ? "Shows only this week" : "Shows the whole month")

                Button {
                    shift(1)
                } label: {
                    Image("ph-caret-right").frame(width: 44, height: 44)
                }
                .accessibilityLabel(expanded ? "Next month" : "Next week")
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(CalendarMath.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(visibleCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, colors: colors(byDay[day] ?? []))
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            // Grab handle: another way to expand / collapse.
            Button {
                toggleExpanded()
            } label: {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expanded ? "Show this week only" : "Show the whole month")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)))
        // Swipe down on the calendar to open the month, up to go back to the week.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let vertical = value.translation.height
                    guard abs(vertical) > abs(value.translation.width) else { return }
                    if vertical > 0, !expanded { toggleExpanded() }
                    if vertical < 0, expanded { toggleExpanded() }
                }
        )
    }

    private var visibleCells: [Date?] {
        expanded
            ? CalendarMath.monthCells(for: anchor, calendar: calendar)
            : CalendarMath.weekDays(containing: anchor, calendar: calendar).map { Optional($0) }
    }

    private var periodTitle: String {
        if expanded {
            return anchor.formatted(.dateTime.month(.wide).year())
        }
        let week = CalendarMath.weekDays(containing: anchor, calendar: calendar)
        guard let first = week.first, let last = week.last else { return "" }
        if week.contains(where: { calendar.isDateInToday($0) }) {
            return "This week"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day())) – \(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func toggleExpanded() {
        withAnimation(.snappy) {
            // Keep the selected day in view when switching between week and month.
            anchor = selectedDay
            expanded.toggle()
        }
    }

    private func shift(_ delta: Int) {
        let component: Calendar.Component = expanded ? .month : .weekOfYear
        guard let next = calendar.date(byAdding: component, value: delta, to: anchor) else { return }
        withAnimation(.snappy) {
            anchor = calendar.startOfDay(for: next)
        }
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

    /// Pages read in the visible week (collapsed) or month (expanded).
    private var pagesInVisiblePeriod: Int {
        let granularity: Calendar.Component = expanded ? .month : .weekOfYear
        return sessions
            .filter { calendar.isDate($0.date, equalTo: anchor, toGranularity: granularity) }
            .reduce(0) { $0 + $1.pagesRead }
    }
}
