import SwiftUI

@Observable
final class HomeViewModel {
    let pets: [Pet]
    var scheduleItems: [ScheduleItem]
    var selectedView: ViewMode = .list
    var selectedCalendarDate: Date = .now

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    init() {
        let calendar = Calendar.current
        let now = Date.now

        let max   = Pet(name: "Max",  color: .orange, systemImage: "dog.fill")
        let luna  = Pet(name: "Luna", color: .purple, systemImage: "cat.fill")
        let buddy = Pet(name: "Nemo", color: .cyan,   systemImage: "fish.fill")

        pets = [max, luna, buddy]

        func time(hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        }

        scheduleItems = [
            ScheduleItem(time: time(hour: 8),  activityName: "Walk",  pet: max,   isCompleted: true),
            ScheduleItem(time: time(hour: 14), activityName: "Eat",   pet: luna,  isCompleted: true),
            ScheduleItem(time: time(hour: 22), activityName: "Sleep", pet: max),
            ScheduleItem(time: time(hour: 22), activityName: "Sleep", pet: buddy),
        ]
    }

    var todayItems: [ScheduleItem] {
        scheduleItems
            .filter { Calendar.current.isDateInToday($0.time) }
            .sorted { $0.time < $1.time }
    }

    func items(for date: Date) -> [ScheduleItem] {
        scheduleItems
            .filter { Calendar.current.isDate($0.time, inSameDayAs: date) }
            .sorted { $0.time < $1.time }
    }

    func toggleCompletion(for item: ScheduleItem) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        scheduleItems[index].isCompleted.toggle()
    }
}
