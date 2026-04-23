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
            ScheduleItem(time: time(hour: 14), activityName: "Feed",  pet: luna, isCompleted: true),
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
            WeightEntry(date: daysAgo(28), kg: 11.8),
            WeightEntry(date: daysAgo(21), kg: 12.1),
            WeightEntry(date: daysAgo(14), kg: 12.4),
            WeightEntry(date: daysAgo(10), kg: 12.6),
            WeightEntry(date: daysAgo(6),  kg: 12.5),
            WeightEntry(date: daysAgo(3),  kg: 12.9),
            WeightEntry(date: daysAgo(0),  kg: 13.1),
        ]
        let lunaWeights: [WeightEntry] = [
            WeightEntry(date: daysAgo(25), kg: 4.4),
            WeightEntry(date: daysAgo(18), kg: 4.3),
            WeightEntry(date: daysAgo(12), kg: 4.2),
            WeightEntry(date: daysAgo(6),  kg: 4.1),
            WeightEntry(date: daysAgo(1),  kg: 4.0),
        ]
        let nemoWeights: [WeightEntry] = [
            WeightEntry(date: daysAgo(20), kg: 0.08),
            WeightEntry(date: daysAgo(10), kg: 0.09),
            WeightEntry(date: daysAgo(0),  kg: 0.10),
        ]
        let maxHeights: [HeightEntry] = [
            HeightEntry(date: daysAgo(28), cm: 56.0),
            HeightEntry(date: daysAgo(14), cm: 57.0),
            HeightEntry(date: daysAgo(7),  cm: 57.5),
            HeightEntry(date: daysAgo(0),  cm: 58.0),
        ]
        let lunaHeights: [HeightEntry] = [
            HeightEntry(date: daysAgo(25), cm: 23.5),
            HeightEntry(date: daysAgo(12), cm: 24.0),
            HeightEntry(date: daysAgo(4),  cm: 24.2),
        ]
        let nemoHeights: [HeightEntry] = [
            HeightEntry(date: daysAgo(20), cm: 7.5),
            HeightEntry(date: daysAgo(10), cm: 8.0),
            HeightEntry(date: daysAgo(0),  cm: 8.5),
        ]

        let max  = Pet(
            name: "Max",  animalType: .dog,
            dateOfBirth: cal.date(from: DateComponents(year: 2021, month: 3, day: 15)),
            weightHistory: maxWeights, heightHistory: maxHeights,
            notes: "Neutered. Allergic to chicken. Currently on Metacam for joint pain.",
            vetDetails: VetDetails(organisation: "Riverside Vets", address: "12 River Lane, London", email: "info@riversidevets.co.uk", phone: "020 7946 0123")
        )
        let luna = Pet(
            name: "Luna", animalType: .cat,
            dateOfBirth: cal.date(from: DateComponents(year: 2020, month: 8, day: 22)),
            weightHistory: lunaWeights, heightHistory: lunaHeights,
            notes: "Indoor cat. On Prednisolone for mild asthma. Needs inhaler twice daily.",
            vetDetails: VetDetails(organisation: "City Cat Clinic", address: "7 Park Street, Manchester", email: "hello@citycatclinic.co.uk", phone: "0161 234 5678")
        )
        let nemo = Pet(
            name: "Nemo", animalType: .fish,
            dateOfBirth: cal.date(from: DateComponents(year: 2023, month: 1, day: 10)),
            weightHistory: nemoWeights, heightHistory: nemoHeights,
            notes: "Betta fish. Treated with API Fin & Body Cure every 5 days for minor fin rot."
        )
        vm.pets = [max, luna, nemo]

        var items: [ScheduleItem] = []

        for d in -29...0 {
            let past = d < 0

            // Max — walks completed days -29..-4 then stopped (triggers gap insight)
            items.append(ScheduleItem(time: at(d, hour: 8),  activityName: "Walk",     pet: max,  isCompleted: d <= -4))
            let maxFed: Bool? = past ? ((29 + d) % 6 != 1) : nil
            items.append(ScheduleItem(
                time: at(d, hour: 8), activityName: "Feed", pet: max,
                isCompleted: maxFed != nil, medicineAccepted: maxFed
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 18), activityName: "Feed", pet: max,
                isCompleted: maxFed != nil, medicineAccepted: maxFed
            ))
            let maxWater: Bool? = past ? true : nil
            items.append(ScheduleItem(
                time: at(d, hour: 12), activityName: "Give water", pet: max,
                isCompleted: maxWater != nil, medicineAccepted: maxWater
            ))
            // Max — Metacam daily
            let maxAccepted: Bool? = past ? ((29 + d) % 7 != 0 ? true : false) : nil
            items.append(ScheduleItem(
                time: at(d, hour: 9), activityName: "Metacam (medicine)", pet: max,
                isCompleted: maxAccepted != nil, medicineAccepted: maxAccepted
            ))

            // Luna — feedings with occasional miss; weekly groom
            let lunaFed: Bool? = past ? ((29 + d) % 7 != 3) : nil
            items.append(ScheduleItem(
                time: at(d, hour: 7), activityName: "Feed", pet: luna,
                isCompleted: lunaFed != nil, medicineAccepted: lunaFed
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 19), activityName: "Feed", pet: luna,
                isCompleted: lunaFed != nil, medicineAccepted: lunaFed
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 15), activityName: "Give water", pet: luna,
                isCompleted: past, medicineAccepted: past ? true : nil
            ))
            if (29 + d) % 7 == 0 {
                items.append(ScheduleItem(time: at(d, hour: 14), activityName: "Grooming", pet: luna, isCompleted: past))
            }
            // Luna — Prednisolone inhaler twice daily
            let lunaInhalerTaken: Bool? = past ? ((29 + d) % 5 != 2 ? true : false) : nil
            items.append(ScheduleItem(
                time: at(d, hour: 8), activityName: "Prednisolone (medicine)", pet: luna,
                isCompleted: lunaInhalerTaken != nil, medicineAccepted: lunaInhalerTaken
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 20), activityName: "Prednisolone (medicine)", pet: luna,
                isCompleted: lunaInhalerTaken != nil, medicineAccepted: lunaInhalerTaken
            ))

            // Nemo — feeding always done; medication every 3 days
            items.append(ScheduleItem(
                time: at(d, hour: 9), activityName: "Feed Nemo", pet: nemo,
                isCompleted: past, medicineAccepted: past ? true : nil
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 16), activityName: "Give water", pet: nemo,
                isCompleted: past, medicineAccepted: past ? true : nil
            ))
            if (29 + d) % 3 == 0 {
                let nemoAccepted: Bool? = past ? true : nil
                items.append(ScheduleItem(
                    time: at(d, hour: 10), activityName: "Fin & Body medicine", pet: nemo,
                    isCompleted: nemoAccepted != nil, medicineAccepted: nemoAccepted
                ))
            }
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

    /// Stores yes/no for medicine, feed, and water (`ScheduleItem.complianceKind`).
    func setMedicineAccepted(_ accepted: Bool, for item: ScheduleItem) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        scheduleItems[index].medicineAccepted = accepted
        scheduleItems[index].isCompleted = true
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
