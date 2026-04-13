import SwiftUI

@Observable
final class HomeViewModel {
    var pets: [Pet]
    var scheduleItems: [ScheduleItem]
    var selectedView: ViewMode = .list
    var selectedCalendarDate: Date = .now
    var selectedPet: Pet? = nil

    enum ViewMode: String, CaseIterable {
        case list = "Today"
        case calendar = "Month View"
    }

    init() {
        pets = []
        scheduleItems = []
    }

    // MARK: - Preview factory

    static var preview: HomeViewModel {
        let vm = HomeViewModel()
        let calendar = Calendar.current
        let now = Date.now

        let max  = Pet(name: "Max",  animalType: .dog)
        let luna = Pet(name: "Luna", animalType: .cat)
        let nemo = Pet(name: "Nemo", animalType: .fish)

        vm.pets = [max, luna, nemo]

        func time(hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        }

        vm.scheduleItems = [
            ScheduleItem(time: time(hour: 8),  activityName: "Walk",  pet: max,  isCompleted: true),
            ScheduleItem(time: time(hour: 14), activityName: "Eat",   pet: luna, isCompleted: true),
            ScheduleItem(time: time(hour: 22), activityName: "Sleep", pet: max),
            ScheduleItem(time: time(hour: 22), activityName: "Sleep", pet: nemo),
        ]
        return vm
    }

    // MARK: - Reset

    func resetAll() {
        pets = []
        scheduleItems = []
        selectedPet = nil
        selectedView = .list
        selectedCalendarDate = .now
    }

    // MARK: - Filtered queries

    var todayItems: [ScheduleItem] {
        scheduleItems
            .filter { Calendar.current.isDateInToday($0.time) }
            .filter { selectedPet == nil || $0.pet.id == selectedPet!.id }
            .sorted { $0.time < $1.time }
    }

    func items(for date: Date) -> [ScheduleItem] {
        scheduleItems
            .filter { Calendar.current.isDate($0.time, inSameDayAs: date) }
            .filter { selectedPet == nil || $0.pet.id == selectedPet!.id }
            .sorted { $0.time < $1.time }
    }

    // MARK: - Schedule actions

    func toggleCompletion(for item: ScheduleItem) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        scheduleItems[index].isCompleted.toggle()
    }

    // MARK: - Pet filter

    func togglePetFilter(_ pet: Pet) {
        selectedPet = (selectedPet?.id == pet.id) ? nil : pet
    }

    // MARK: - Pet CRUD

    func addPet(_ pet: Pet) {
        pets.append(pet)
    }

    func updatePet(_ pet: Pet) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else { return }
        pets[index] = pet
        for i in scheduleItems.indices where scheduleItems[i].pet.id == pet.id {
            scheduleItems[i].pet = pet
        }
    }

    func deletePet(_ pet: Pet) {
        pets.removeAll { $0.id == pet.id }
        scheduleItems.removeAll { $0.pet.id == pet.id }
        if selectedPet?.id == pet.id { selectedPet = nil }
    }
}
