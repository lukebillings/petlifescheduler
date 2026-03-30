import Foundation

enum ScheduleScope: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .week: "Week"
        case .month: "Month"
        }
    }
}

@Observable
final class ScheduleViewModel {
    private let calendar = Calendar.current

    var scope: ScheduleScope = .today
    /// Week or month views move this anchor; Today always uses calendar start of current day for filtering.
    var anchorDate: Date = .now
    var events: [ScheduleEvent] = []

    init() {
        loadSampleEvents()
    }

    var todayStart: Date {
        calendar.startOfDay(for: .now)
    }

    var eventsToday: [ScheduleEvent] {
        events
            .filter { calendar.isDate($0.startTime, inSameDayAs: .now) }
            .sorted { $0.startTime < $1.startTime }
    }

    var weekInterval: DateInterval? {
        calendar.dateInterval(of: .weekOfYear, for: anchorDate)
    }

    var eventsInWeek: [ScheduleEvent] {
        guard let interval = weekInterval else { return [] }
        return events
            .filter { interval.contains($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    var daysInDisplayedWeek: [Date] {
        guard let interval = weekInterval else { return [] }
        let start = interval.start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var monthInterval: DateInterval? {
        calendar.dateInterval(of: .month, for: anchorDate)
    }

    func monthGridDays() -> [Date?] {
        guard
            let monthStart = monthInterval?.start,
            let daysInMonth = calendar.range(of: .day, in: .month, for: anchorDate)?.count
        else { return [] }

        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let firstWeekday = calendar.firstWeekday
        let leading = (weekdayOfFirst - firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in 1...daysInMonth {
            var dc = calendar.dateComponents([.year, .month], from: monthStart)
            dc.day = day
            cells.append(calendar.date(from: dc))
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    func events(on day: Date) -> [ScheduleEvent] {
        events
            .filter { calendar.isDate($0.startTime, inSameDayAs: day) }
            .sorted { $0.startTime < $1.startTime }
    }

    func hasEvents(on day: Date) -> Bool {
        events.contains { calendar.isDate($0.startTime, inSameDayAs: day) }
    }

    func shiftWeek(by delta: Int) {
        anchorDate = calendar.date(byAdding: .weekOfYear, value: delta, to: anchorDate) ?? anchorDate
    }

    func shiftMonth(by delta: Int) {
        anchorDate = calendar.date(byAdding: .month, value: delta, to: anchorDate) ?? anchorDate
    }

    func jumpAnchorToToday() {
        anchorDate = .now
    }

    private func loadSampleEvents() {
        let today = Date()
        let dayStart = calendar.startOfDay(for: today)

        func at(dayOffset: Int, hour: Int, minute: Int) -> Date {
            let d = calendar.date(byAdding: .day, value: dayOffset, to: dayStart) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: d) ?? d
        }

        events = [
            ScheduleEvent(id: UUID(), title: "Breakfast", startTime: at(dayOffset: 0, hour: 7, minute: 30), symbolName: "leaf.fill"),
            ScheduleEvent(id: UUID(), title: "Morning walk", startTime: at(dayOffset: 0, hour: 8, minute: 0), symbolName: "figure.walk"),
            ScheduleEvent(id: UUID(), title: "Training", startTime: at(dayOffset: 0, hour: 12, minute: 15), symbolName: "graduationcap.fill"),
            ScheduleEvent(id: UUID(), title: "Evening walk", startTime: at(dayOffset: 0, hour: 18, minute: 30), symbolName: "figure.walk"),
            ScheduleEvent(id: UUID(), title: "Grooming", startTime: at(dayOffset: 1, hour: 17, minute: 0), symbolName: "sparkles"),
            ScheduleEvent(id: UUID(), title: "Vet check-in", startTime: at(dayOffset: 2, hour: 10, minute: 0), symbolName: "cross.case.fill"),
            ScheduleEvent(id: UUID(), title: "Playdate", startTime: at(dayOffset: 3, hour: 15, minute: 0), symbolName: "hare.fill"),
            ScheduleEvent(id: UUID(), title: "Medication", startTime: at(dayOffset: -1, hour: 8, minute: 0), symbolName: "pills.fill"),
            ScheduleEvent(id: UUID(), title: "Weigh-in", startTime: at(dayOffset: 5, hour: 9, minute: 30), symbolName: "scalemass.fill"),
        ]
    }
}
