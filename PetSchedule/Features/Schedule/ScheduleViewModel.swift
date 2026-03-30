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
    private let storageKey = "PetSchedule.schedule.events.v1"

    var scope: ScheduleScope = .today
    /// Week or month views move this anchor; Today always uses calendar start of current day for filtering.
    var anchorDate: Date = .now
    var events: [ScheduleEvent] = []

    init() {
        loadEvents()
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

    func addEvent(
        title: String,
        startTime: Date,
        symbolName: String,
        pet: PetProfile?
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let pid = pet?.id
        let pname: String
        if let pet {
            let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
            pname = n.isEmpty ? "Pet" : n
        } else {
            pname = ""
        }
        let new = ScheduleEvent(
            id: UUID(),
            title: trimmed,
            startTime: startTime,
            symbolName: symbolName,
            petId: pid,
            petName: pname
        )
        events = (events + [new]).sorted { $0.startTime < $1.startTime }
        saveEvents()
    }

    func deleteEvent(id: UUID) {
        events = events.filter { $0.id != id }
        saveEvents()
    }

    private func loadEvents() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ScheduleEvent].self, from: data) else {
            events = []
            return
        }
        events = decoded.sorted { $0.startTime < $1.startTime }
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
