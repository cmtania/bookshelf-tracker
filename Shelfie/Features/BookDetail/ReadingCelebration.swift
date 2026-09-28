import SwiftUI

/// What just happened when a reading session was saved: the moment the app celebrates.
struct LoggedReading: Equatable, Identifiable {
    let id = UUID()
    var pagesGained: Int
    /// The book's streak before and after this session.
    var previousStreak: Int
    var streak: Int
    /// Set when this session finished the book.
    var finishedTitle: String?
    var totalPages: Int = 0

    /// Streak lengths that get their own message.
    static let milestones: Set<Int> = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365]

    enum Kind: Equatable {
        case finished, milestone, streakGrew, streakKept, timeOnly
    }

    var kind: Kind {
        if finishedTitle != nil { return .finished }
        if streak > previousStreak {
            return Self.milestones.contains(streak) ? .milestone : .streakGrew
        }
        return pagesGained > 0 ? .streakKept : .timeOnly
    }

    var headline: String {
        switch kind {
        case .finished: "You finished \(finishedTitle ?? "the book")!"
        case .milestone: "\(streak) days in a row!"
        case .streakGrew: streak == 1 ? "Streak started" : "\(streak)-day streak"
        case .streakKept: "+\(pagesGained) \(pagesGained == 1 ? "page" : "pages")"
        case .timeOnly: "Time well spent"
        }
    }

    var detail: String {
        let pages = "+\(pagesGained) \(pagesGained == 1 ? "page" : "pages")"
        switch kind {
        case .finished: return "\(totalPages) pages, start to finish. On to the next one."
        case .milestone: return "\(pages) today. That’s a real habit now."
        case .streakGrew: return streak == 1 ? "\(pages). Come back tomorrow to keep it going." : "\(pages). See you tomorrow."
        case .streakKept: return streak > 0 ? "Your \(streak)-day streak is safe today." : "Nice reading."
        case .timeOnly: return streak > 0 ? "Your \(streak)-day streak is safe today." : "Every minute counts."
        }
    }

    var icon: String {
        kind == .finished ? "ph-seal-check-fill" : "ph-flame-fill"
    }
}

/// A glass card that drops in after Log reading is saved: a bouncing flame (or a seal for a
/// finished book) with a soft glow, the headline and the pages gained. Taps or 2.8 s dismiss it.
struct ReadingCelebrationCard: View {
    let logged: LoggedReading
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = 0

    private var tint: Color {
        logged.kind == .finished ? .accentColor : .orange
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                // Soft glow behind the icon.
                Circle()
                    .fill(tint.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .blur(radius: 12)
                Image(logged.icon)
                    .font(.title)
                    .foregroundStyle(tint)
                    .symbolEffect(.bounce, value: bounce)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(logged.headline)
                    .font(.headline)
                    .lineLimit(2)
                Text(logged.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Dismiss")
        .task {
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(250))
                bounce += 1
            }
            try? await Task.sleep(for: .seconds(2.8))
            onDismiss()
        }
    }
}
