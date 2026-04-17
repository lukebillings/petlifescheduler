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

    /// Rich preview with 14 days of historical data — used by the Analytics tab preview.
    static var analyticsPreview: HomeViewModel {
        let vm  = HomeViewModel()
        let cal = Calendar.current
        let now = Date.now

        func startOf(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) ?? now
        }
        func at(_ offset: Int, hour: Int) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: startOf(offset)) ?? now
        }
        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: now) ?? now
        }

        let maxWeights: [WeightEntry] = [
            WeightEntry(date: daysAgo(14), kg: 12.4),
            WeightEntry(date: daysAgo(10), kg: 12.6),
            WeightEntry(date: daysAgo(6),  kg: 12.5),
            WeightEntry(date: daysAgo(3),  kg: 12.9),
            WeightEntry(date: daysAgo(0),  kg: 13.1),
        ]
        let lunaWeights: [WeightEntry] = [
            WeightEntry(date: daysAgo(12), kg: 4.2),
            WeightEntry(date: daysAgo(6),  kg: 4.1),
            WeightEntry(date: daysAgo(1),  kg: 4.0),
        ]

        let max  = Pet(name: "Max",  animalType: .dog,  weightHistory: maxWeights)
        let luna = Pet(name: "Luna", animalType: .cat,  weightHistory: lunaWeights)
        let nemo = Pet(name: "Nemo", animalType: .fish)
        vm.pets = [max, luna, nemo]

        var items: [ScheduleItem] = []

        for d in -13...0 {
            let past = d < 0

            // Max — walks completed days -13..-4 then stopped (triggers gap insight)
            items.append(ScheduleItem(time: at(d, hour: 8),  activityName: "Walk",     pet: max,  isCompleted: d <= -4))
            items.append(ScheduleItem(time: at(d, hour: 8),  activityName: "Eat",      pet: max,  isCompleted: past))
            items.append(ScheduleItem(time: at(d, hour: 18), activityName: "Eat",      pet: max,  isCompleted: past))
            if (13 + d) % 2 == 0 {
                items.append(ScheduleItem(time: at(d, hour: 9), activityName: "Medicine", pet: max, isCompleted: past))
            }

            // Luna — regular feedings with occasional miss; weekly groom
            let lunaFed = past && (13 + d) % 7 != 3
            items.append(ScheduleItem(time: at(d, hour: 7),  activityName: "Feed",    pet: luna, isCompleted: lunaFed))
            items.append(ScheduleItem(time: at(d, hour: 19), activityName: "Feed",    pet: luna, isCompleted: lunaFed))
            if (13 + d) % 7 == 0 {
                items.append(ScheduleItem(time: at(d, hour: 14), activityName: "Grooming", pet: luna, isCompleted: past))
            }

            // Nemo — daily feeding, always done
            items.append(ScheduleItem(time: at(d, hour: 9), activityName: "Feed Nemo", pet: nemo, isCompleted: true))
        }

        vm.scheduleItems = items
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

    // MARK: - Birthday events

    func birthdayItem(for pet: Pet, on date: Date) -> ScheduleItem? {
        guard let dob = pet.dateOfBirth else { return nil }
        let cal = Calendar.current
        guard cal.component(.month, from: dob) == cal.component(.month, from: date),
              cal.component(.day,   from: dob) == cal.component(.day,   from: date) else { return nil }
        let years = cal.dateComponents([.year], from: dob, to: date).year ?? 0
        let ordinal: String
        switch years % 10 {
        case 1 where years % 100 != 11: ordinal = "\(years)st"
        case 2 where years % 100 != 12: ordinal = "\(years)nd"
        case 3 where years % 100 != 13: ordinal = "\(years)rd"
        default:                         ordinal = "\(years)th"
        }
        let title = years > 0 ? "\(pet.name)'s \(ordinal) Birthday 🎂" : "\(pet.name)'s Birthday 🎂"
        // Derive a stable UUID from the pet's id XORed with the birthday year,
        // so ForEach gets a consistent identity without storing the item.
        let year = cal.component(.year, from: date)
        var bytes = pet.id.uuid
        bytes.0  ^= UInt8((year >> 8) & 0xFF)
        bytes.1  ^= UInt8(year & 0xFF)
        bytes.6   = (bytes.6 & 0x0F) | 0x50  // version 5
        bytes.8   = (bytes.8 & 0x3F) | 0x80  // variant
        let stableID = UUID(uuid: bytes)
        return ScheduleItem(
            id: stableID,
            time: cal.startOfDay(for: date),
            activityName: title,
            pet: pet,
            isAllDay: true,
            isBirthday: true
        )
    }

    private func birthdayItems(on date: Date) -> [ScheduleItem] {
        pets
            .filter { selectedPet == nil || $0.id == selectedPet!.id }
            .compactMap { birthdayItem(for: $0, on: date) }
    }

    // MARK: - Filtered queries

    var todayItems: [ScheduleItem] {
        let regular = scheduleItems
            .filter { Calendar.current.isDateInToday($0.time) }
            .filter { selectedPet == nil || $0.pet.id == selectedPet!.id }
        let birthdays = birthdayItems(on: .now)
        return (birthdays + regular).sorted { $0.time < $1.time }
    }

    func items(for date: Date) -> [ScheduleItem] {
        let regular = scheduleItems
            .filter { Calendar.current.isDate($0.time, inSameDayAs: date) }
            .filter { selectedPet == nil || $0.pet.id == selectedPet!.id }
        let birthdays = birthdayItems(on: date)
        return (birthdays + regular).sorted { $0.time < $1.time }
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
