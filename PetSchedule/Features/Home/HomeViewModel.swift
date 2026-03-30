import Foundation

@Observable
final class HomeViewModel {
    private let calendar = Calendar.current

    /// Shared to-dos, habits, and wellness logs.
    var trackStore: TrackStore

    var calendarItems: [HomeCalendarItem] = []

    var todayCalendarItems: [HomeCalendarItem] {
        calendarItems
            .filter { calendar.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    var todos: [HomeTodo] {
        trackStore.todos
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone && b.isDone }
                return a.createdAt > b.createdAt
            }
            .map { HomeTodo(id: $0.id, title: $0.title, isDone: $0.isDone) }
    }

    var habits: [HomeHabit] {
        let key = trackStore.todayDayKey
        return trackStore.habits.map { h in
            HomeHabit(
                id: h.id,
                title: h.title,
                completedToday: h.isCompleted(on: key),
                targetSummary: h.detail.isEmpty ? "Daily" : h.detail
            )
        }
    }

    var petStates: [PetStateItem] {
        trackStore.wellnessLogs.prefix(4).map { log in
            PetStateItem(
                id: log.id,
                petName: log.petName.isEmpty ? "State" : log.petName,
                label: "Energy · mood",
                value: "\(log.energy) · \(log.happiness)",
                symbolName: "heart.fill"
            )
        }
    }

    /// Pets with a saved date of birth (for age-year ring).
    var dogs: [HomeDog] {
        PetProfileStorage.load().compactMap { profile -> HomeDog? in
            guard let dob = profile.dateOfBirth else { return nil }
            let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return HomeDog(id: profile.id, name: name.isEmpty ? "Pet" : name, birthday: dob)
        }
    }

    init(trackStore: TrackStore) {
        self.trackStore = trackStore
        loadSampleCalendarOnly()
    }

    func toggleTodo(id: UUID) {
        trackStore.toggleTodo(id: id)
    }

    func toggleHabit(id: UUID) {
        trackStore.toggleHabitToday(id: id)
    }

    func ageYearProgress(for dog: HomeDog) -> Double {
        DogAgeYear.progressFraction(birthday: dog.birthday)
    }

    func chronologicalAge(for dog: HomeDog) -> Int {
        DogAgeYear.chronologicalYears(birthday: dog.birthday)
    }

    private func loadSampleCalendarOnly() {
        let today = Date()
        func timeToday(hour: Int, minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        calendarItems = [
            HomeCalendarItem(id: UUID(), title: "Morning walk", startTime: timeToday(hour: 8, minute: 0), symbolName: "figure.walk"),
            HomeCalendarItem(id: UUID(), title: "Meal — breakfast", startTime: timeToday(hour: 7, minute: 30), symbolName: "leaf.fill"),
            HomeCalendarItem(id: UUID(), title: "Grooming / brush", startTime: timeToday(hour: 17, minute: 0), symbolName: "sparkles"),
            HomeCalendarItem(id: UUID(), title: "Training session", startTime: timeToday(hour: 12, minute: 15), symbolName: "graduationcap.fill"),
        ]
    }
}
