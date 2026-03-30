import Foundation

struct HomeCalendarItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var startTime: Date
    var symbolName: String

    func timeString(dateStyle: DateFormatter.Style = .none, timeStyle: DateFormatter.Style = .short) -> String {
        let f = DateFormatter()
        f.dateStyle = dateStyle
        f.timeStyle = timeStyle
        return f.string(from: startTime)
    }
}

struct HomeTodo: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
}

struct HomeHabit: Identifiable, Equatable {
    let id: UUID
    var title: String
    var completedToday: Bool
    var targetSummary: String
}

struct PetStateItem: Identifiable, Equatable {
    let id: UUID
    var petName: String
    var label: String
    var value: String
    var symbolName: String
}

struct HomeDog: Identifiable, Equatable {
    let id: UUID
    var name: String
    var birthday: Date
}

enum DogAgeYear {
    /// Fraction of the current “age year” (last birthday → next birthday) that has elapsed.
    static func progressFraction(birthday: Date, now: Date = .now, calendar: Calendar = .current) -> Double {
        let cal = calendar
        let bComps = cal.dateComponents([.month, .day], from: birthday)
        guard let month = bComps.month, let day = bComps.day else { return 0 }
        let y = cal.component(.year, from: now)
        var dc = DateComponents(year: y, month: month, day: day)
        guard var anchor = cal.date(from: dc) else { return 0 }
        if anchor > now {
            dc.year = y - 1
            anchor = cal.date(from: dc) ?? anchor
        }
        let lastBirthday = anchor
        guard let nextBirthday = cal.date(byAdding: .year, value: 1, to: lastBirthday) else { return 0 }
        let span = nextBirthday.timeIntervalSince(lastBirthday)
        guard span > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(lastBirthday)
        return min(1, max(0, elapsed / span))
    }

    static func chronologicalYears(birthday: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, calendar.dateComponents([.year], from: birthday, to: now).year ?? 0)
    }
}
