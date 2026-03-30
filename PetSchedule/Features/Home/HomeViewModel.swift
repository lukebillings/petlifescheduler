import Foundation

@Observable
final class HomeViewModel {
    private let calendar = Calendar.current

    var calendarItems: [HomeCalendarItem] = []
    var todos: [HomeTodo] = []
    var habits: [HomeHabit] = []
    var petStates: [PetStateItem] = []
    var dogs: [HomeDog] = []

    var todayCalendarItems: [HomeCalendarItem] {
        calendarItems
            .filter { calendar.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    init() {
        loadSampleData()
    }

    func toggleTodo(id: UUID) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[i].isDone.toggle()
    }

    func toggleHabit(id: UUID) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[i].completedToday.toggle()
    }

    func ageYearProgress(for dog: HomeDog) -> Double {
        DogAgeYear.progressFraction(birthday: dog.birthday)
    }

    func chronologicalAge(for dog: HomeDog) -> Int {
        DogAgeYear.chronologicalYears(birthday: dog.birthday)
    }

    private func loadSampleData() {
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

        todos = [
            HomeTodo(id: UUID(), title: "Refill water fountain", isDone: false),
            HomeTodo(id: UUID(), title: "Order flea & tick refill", isDone: false),
            HomeTodo(id: UUID(), title: "Book nail trim", isDone: true),
        ]

        habits = [
            HomeHabit(id: UUID(), title: "Dental chew", completedToday: true, targetSummary: "1× daily"),
            HomeHabit(id: UUID(), title: "Play / enrichment", completedToday: false, targetSummary: "20 min"),
            HomeHabit(id: UUID(), title: "Log weight", completedToday: false, targetSummary: "Weekly Mon"),
        ]

        petStates = [
            PetStateItem(id: UUID(), petName: "Maple", label: "Energy", value: "Medium", symbolName: "bolt.fill"),
            PetStateItem(id: UUID(), petName: "Maple", label: "Appetite", value: "Normal", symbolName: "fork.knife"),
            PetStateItem(id: UUID(), petName: "Cedar", label: "Mood", value: "Playful", symbolName: "face.smiling"),
        ]

        let mapleBD = calendar.date(from: DateComponents(year: 2021, month: 6, day: 15)) ?? today
        let cedarBD = calendar.date(from: DateComponents(year: 2019, month: 2, day: 3)) ?? today
        dogs = [
            HomeDog(id: UUID(), name: "Maple", birthday: mapleBD),
            HomeDog(id: UUID(), name: "Cedar", birthday: cedarBD),
        ]
    }
}
