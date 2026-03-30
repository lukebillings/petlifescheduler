import Foundation

// MARK: - One-off to-dos

struct OneOffTodo: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
}

// MARK: - Habits (per-day completion)

struct HabitTrack: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    /// Extra context (e.g. “Morning pill”).
    var detail: String
    /// Calendar-local `yyyy-MM-dd` days marked complete.
    var completedDayKeys: [String]

    func isCompleted(on dayKey: String) -> Bool {
        completedDayKeys.contains(dayKey)
    }

    mutating func toggleDay(_ dayKey: String) {
        if let idx = completedDayKeys.firstIndex(of: dayKey) {
            completedDayKeys.remove(at: idx)
        } else {
            completedDayKeys.append(dayKey)
            completedDayKeys.sort()
        }
    }
}

// MARK: - Wellness / state log

struct WellnessStateLog: Identifiable, Codable, Equatable {
    var id: UUID
    var recordedAt: Date
    /// Empty when not tied to a named pet.
    var petName: String
    var energy: String
    var happiness: String
    /// Optional snapshot when logging state (kilograms).
    var weightKg: Double?
    /// Optional snapshot when logging state (centimeters).
    var heightCm: Double?
}

enum WellnessOptions {
    static let energyLevels = ["Low", "Medium", "High"]
    static let happinessLevels = ["Unhappy", "Ok", "Happy", "Very happy"]

    /// Index for line charts (0 … count-1). Unknown strings map to the middle bucket.
    static func energyIndex(_ energy: String) -> Double {
        if let i = energyLevels.firstIndex(of: energy) { return Double(i) }
        return Double(energyLevels.count / 2)
    }

    static func happinessIndex(_ happiness: String) -> Double {
        if let i = happinessLevels.firstIndex(of: happiness) { return Double(i) }
        return Double(happinessLevels.count / 2)
    }
}

/// Visual state for a day cell in the habit month calendar.
enum HabitCalendarDayState: Equatable {
    case future
    case noHabits
    case allComplete
    case partial
    case missed
}

// MARK: - Store

@Observable
final class TrackStore {
    private let calendar = Calendar.current
    private let todosKey = "PetSchedule.track.todos.v1"
    private let habitsKey = "PetSchedule.track.habits.v1"
    private let wellnessKey = "PetSchedule.track.wellness.v1"

    private(set) var todos: [OneOffTodo] = []
    private(set) var habits: [HabitTrack] = []
    private(set) var wellnessLogs: [WellnessStateLog] = []

    init() {
        load()
        seedHabitsIfNeeded()
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0
        let m = c.month ?? 0
        let d = c.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    var todayDayKey: String {
        Self.dayKey(for: Date(), calendar: calendar)
    }

    /// Oldest → newest calendar day keys ending today (for habit grids).
    func recentDayKeys(count: Int) -> [String] {
        let n = max(1, count)
        let todayStart = calendar.startOfDay(for: Date())
        return (0..<n).compactMap { i -> String? in
            guard let d = calendar.date(byAdding: .day, value: -(n - 1) + i, to: todayStart) else { return nil }
            return Self.dayKey(for: d, calendar: calendar)
        }
    }

    func isFutureDayKey(_ key: String) -> Bool {
        key > todayDayKey
    }

    // MARK: Todos

    func addTodo(title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var next = todos
        next.insert(
            OneOffTodo(id: UUID(), title: t, isDone: false, createdAt: Date()),
            at: 0
        )
        todos = next
        saveTodos()
    }

    func toggleTodo(id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        var next = todos
        next[i].isDone.toggle()
        todos = next
        saveTodos()
    }

    func deleteTodo(id: UUID) {
        todos = todos.filter { $0.id != id }
        saveTodos()
    }

    // MARK: Habits

    func toggleHabitToday(id: UUID) {
        toggleHabit(id: id, onDayKey: todayDayKey)
    }

    func toggleHabit(id: UUID, onDayKey dayKey: String) {
        guard !isFutureDayKey(dayKey) else { return }
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        var next = habits
        next[i].toggleDay(dayKey)
        habits = next
        saveHabits()
    }

    /// Every habit completed on that day (needs at least one habit).
    func allHabitsCompleted(on dayKey: String) -> Bool {
        guard !habits.isEmpty else { return false }
        return habits.allSatisfy { $0.isCompleted(on: dayKey) }
    }

    func habitCalendarDayState(for date: Date) -> HabitCalendarDayState {
        let key = Self.dayKey(for: date, calendar: calendar)
        if isFutureDayKey(key) { return .future }
        if habits.isEmpty { return .noHabits }
        if allHabitsCompleted(on: key) { return .allComplete }
        if habits.contains(where: { $0.isCompleted(on: key) }) { return .partial }
        return .missed
    }

    /// Leading `nil` padding + each day in the month (like a wall calendar).
    static func monthGridCells(forMonthContaining date: Date, calendar: Calendar = .current) -> [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: date),
            let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count
        else { return [] }
        let monthStart = interval.start
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

    func addHabit(title: String, detail: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var next = habits
        next.append(
            HabitTrack(id: UUID(), title: t, detail: detail, completedDayKeys: [])
        )
        habits = next
        saveHabits()
    }

    func deleteHabit(id: UUID) {
        habits = habits.filter { $0.id != id }
        saveHabits()
    }

    func isHabitCompletedToday(id: UUID) -> Bool {
        guard let h = habits.first(where: { $0.id == id }) else { return false }
        return h.isCompleted(on: todayDayKey)
    }

    // MARK: Wellness

    func addWellnessLog(
        petName: String,
        energy: String,
        happiness: String,
        weightKg: Double? = nil,
        heightCm: Double? = nil
    ) {
        var next = wellnessLogs
        next.insert(
            WellnessStateLog(
                id: UUID(),
                recordedAt: Date(),
                petName: petName.trimmingCharacters(in: .whitespacesAndNewlines),
                energy: energy,
                happiness: happiness,
                weightKg: weightKg,
                heightCm: heightCm
            ),
            at: 0
        )
        wellnessLogs = next
        saveWellness()
    }

    func deleteWellnessLog(id: UUID) {
        wellnessLogs = wellnessLogs.filter { $0.id != id }
        saveWellness()
    }

    // MARK: Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: todosKey),
           let decoded = try? JSONDecoder().decode([OneOffTodo].self, from: data) {
            todos = decoded
        }
        if let data = UserDefaults.standard.data(forKey: habitsKey),
           let decoded = try? JSONDecoder().decode([HabitTrack].self, from: data) {
            habits = decoded
        }
        if let data = UserDefaults.standard.data(forKey: wellnessKey),
           let decoded = try? JSONDecoder().decode([WellnessStateLog].self, from: data) {
            wellnessLogs = decoded
        }
    }

    private func seedHabitsIfNeeded() {
        guard habits.isEmpty else { return }
        habits = [
            HabitTrack(id: UUID(), title: "Medicine", detail: "Daily medication", completedDayKeys: []),
            HabitTrack(id: UUID(), title: "Walk", detail: "Exercise walk", completedDayKeys: []),
            HabitTrack(id: UUID(), title: "Water", detail: "Fresh water / intake", completedDayKeys: []),
        ]
        saveHabits()
    }

    private func saveTodos() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: todosKey)
        }
    }

    private func saveHabits() {
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: habitsKey)
        }
    }

    private func saveWellness() {
        if let data = try? JSONEncoder().encode(wellnessLogs) {
            UserDefaults.standard.set(data, forKey: wellnessKey)
        }
    }
}
