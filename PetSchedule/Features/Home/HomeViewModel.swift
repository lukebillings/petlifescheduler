import SwiftUI
import UIKit
import WidgetKit

@Observable
final class HomeViewModel {
    var pets: [Pet]
    var scheduleItems: [ScheduleItem]
    var selectedView: ViewMode = .list
    var selectedCalendarDate: Date = .now
    var selectedPet: Pet? = nil
    /// Set when enough tasks are checked off; `HomeView` presents `AppRatingReviewSheet`.
    var showAppRatingPrompt = false

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
        let jill = Pet(name: "Jill", animalType: .fish)

        vm.pets = [max, luna, jill]

        func time(hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
        }

        vm.scheduleItems = [
            ScheduleItem(time: time(hour: 8),  activityName: "Walk",  pet: max,  isCompleted: true),
            ScheduleItem(time: time(hour: 14), activityName: "Feed",  pet: luna, isCompleted: true),
            ScheduleItem(time: time(hour: 22), activityName: "Put to Bed", pet: max),
            ScheduleItem(time: time(hour: 22), activityName: "Put to Bed", pet: jill),
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
        let jillWeights: [WeightEntry] = [
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
        let jillHeights: [HeightEntry] = [
            HeightEntry(date: daysAgo(20), cm: 7.5),
            HeightEntry(date: daysAgo(10), cm: 8.0),
            HeightEntry(date: daysAgo(0),  cm: 8.5),
        ]

        let max  = Pet(
            name: "Max",  animalType: .dog,
            dateOfBirth: cal.date(from: DateComponents(year: 2021, month: 3, day: 15)),
            weightHistory: maxWeights, heightHistory: maxHeights,
            notes: "Neutered. Allergic to chicken. Currently on Metacam for joint pain.",
            vetDetails: VetDetails(
                organisation: "Your Vet's Name",
                address: "Your Vet's Address",
                email: "yourvetsname@yourvetsname.com",
                phone: "0123456789"
            ),
            documents: PetDocument.samplePack(for: .dog, petName: "Max", reference: now, calendar: cal)
        )
        let luna = Pet(
            name: "Luna", animalType: .cat,
            dateOfBirth: cal.date(from: DateComponents(year: 2020, month: 8, day: 22)),
            weightHistory: lunaWeights, heightHistory: lunaHeights,
            notes: "Indoor cat. On Prednisolone for mild asthma. Needs inhaler twice daily.",
            vetDetails: VetDetails(
                organisation: "Your Vet's Name",
                address: "Your Vet's Address",
                email: "yourvetsname@yourvetsname.com",
                phone: "0123456789"
            ),
            documents: PetDocument.samplePack(for: .cat, petName: "Luna", reference: now, calendar: cal)
        )
        let jill = Pet(
            name: "Jill", animalType: .fish,
            dateOfBirth: cal.date(from: DateComponents(year: 2023, month: 1, day: 10)),
            weightHistory: jillWeights, heightHistory: jillHeights,
            notes: "Betta fish. Treated with API Fin & Body Cure every 5 days for minor fin rot.",
            documents: PetDocument.samplePack(for: .fish, petName: "Jill", reference: now, calendar: cal)
        )
        vm.pets = [max, luna, jill]

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
            if d == 0 {
                items.append(ScheduleItem(
                    time: cal.date(bySettingHour: 8, minute: 10, second: 0, of: startOf(0)) ?? now,
                    activityName: "Mood",
                    pet: max,
                    isCompleted: true,
                    quickLogKind: .mood,
                    petMood: .great
                ))
            }
            items.append(ScheduleItem(
                time: at(d, hour: 18), activityName: "Feed", pet: max,
                isCompleted: maxFed != nil, medicineAccepted: maxFed
            ))
            let maxWater: Bool? = past ? true : nil
            items.append(ScheduleItem(
                time: at(d, hour: 12), activityName: "Give water", pet: max,
                isCompleted: maxWater != nil, medicineAccepted: maxWater
            ))
            // Max — daily medication (preset activity name)
            let maxAccepted: Bool? = past ? ((29 + d) % 7 != 0 ? true : false) : nil
            items.append(ScheduleItem(
                time: at(d, hour: 9), activityName: "Medication", pet: max,
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
            // Luna — twice-daily medication (preset activity name)
            let lunaInhalerTaken: Bool? = past ? ((29 + d) % 5 != 2 ? true : false) : nil
            let lunaMorningMedTime = d == 0
                ? (cal.date(bySettingHour: 8, minute: 20, second: 0, of: startOf(0)) ?? now)
                : at(d, hour: 8)
            items.append(ScheduleItem(
                time: lunaMorningMedTime, activityName: "Medication", pet: luna,
                isCompleted: lunaInhalerTaken != nil, medicineAccepted: lunaInhalerTaken
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 20), activityName: "Medication", pet: luna,
                isCompleted: lunaInhalerTaken != nil, medicineAccepted: lunaInhalerTaken
            ))

            // Jill — feeding always done; medication every 3 days
            items.append(ScheduleItem(
                time: at(d, hour: 9), activityName: "Feed Jill", pet: jill,
                isCompleted: past, medicineAccepted: past ? true : nil
            ))
            items.append(ScheduleItem(
                time: at(d, hour: 16), activityName: "Give water", pet: jill,
                isCompleted: past, medicineAccepted: past ? true : nil
            ))
            if (29 + d) % 3 == 0 {
                let jillAccepted: Bool? = past ? true : nil
                items.append(ScheduleItem(
                    time: at(d, hour: 10), activityName: "Medication", pet: jill,
                    isCompleted: jillAccepted != nil, medicineAccepted: jillAccepted
                ))
            }
        }

        // Mood quick logs (Analytics → Mood Over Time; dates within default Week window)
        let maxMoodDays = [2, 4]
        let maxMoodSeries: [PetMood] = [.good, .okay]
        for (idx, day) in maxMoodDays.enumerated() {
            items.append(ScheduleItem(
                time: daysAgo(day),
                activityName: "Mood",
                pet: max,
                isCompleted: true,
                quickLogKind: .mood,
                petMood: maxMoodSeries[idx]
            ))
        }
        let lunaMoodDays = [1, 3, 5]
        let lunaMoodSeries: [PetMood] = [.good, .anxious, .okay]
        for (idx, day) in lunaMoodDays.enumerated() {
            items.append(ScheduleItem(
                time: daysAgo(day),
                activityName: "Mood",
                pet: luna,
                isCompleted: true,
                quickLogKind: .mood,
                petMood: lunaMoodSeries[idx]
            ))
        }

        // Spread two made-up household members — Bob and Wendy — across the dummy schedule so
        // demos and App Store screenshots show a realistic shared household. Assignment is
        // deterministic per activity so a recurring task keeps the same owner over the 30 days,
        // while medicine alternates day-by-day to demonstrate hand-offs.
        let dayCal = Calendar.current
        for i in items.indices {
            let lower = items[i].activityName.lowercased()
            let isMedicine = lower.contains("medic")
                || lower.contains("tablet")
                || lower.contains("pill")
            let isOutdoorOrWater = lower.contains("walk")
                || lower.contains("run")
                || lower.contains("play")
                || lower.contains("water")
                || lower.contains("drink")
            let assignedIsBob: Bool
            if isMedicine {
                let ordinal = dayCal.ordinality(of: .day, in: .era, for: items[i].time) ?? 0
                assignedIsBob = ordinal % 2 == 0
            } else if isOutdoorOrWater {
                assignedIsBob = true
            } else {
                // Feeding, grooming, mood logs, and anything else default to Wendy.
                assignedIsBob = false
            }
            let assigned = assignedIsBob ? "Bob" : "Wendy"
            // Created by the *other* member so both names appear as event authors.
            let creator = assignedIsBob ? "Wendy" : "Bob"
            items[i].assignedToDisplayName = assigned
            items[i].createdByDisplayName = creator
            items[i].assigneeAccent = assignedIsBob ? .blue : .pink
            if items[i].isCompleted {
                items[i].completedByDisplayName = assigned
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
        HouseholdLocalStore.clear()
        Task { @MainActor in
            HouseholdSyncCoordinator.shared.clearModificationCache()
        }
        resetPostTutorialHintUserDefaults()
        syncWidgetSchedule()
    }

    /// Replaces pets and schedule with sample **dog**, **cat**, and **fish** profiles plus ~30 days of events (for demos and screenshots).
    func populateWithDummyDogCatFishData() {
        let demo = HomeViewModel.analyticsPreview
        pets = demo.pets
        scheduleItems = demo.scheduleItems
        selectedPet = nil
        selectedView = .list
        selectedCalendarDate = .now
        HouseholdLocalStore.save(viewModel: self)
        syncWidgetSchedule()
    }

    /// Clears post-tutorial hint flags. Keys must stay aligned with `PostTutorialHintPersistence`.
    private func resetPostTutorialHintUserDefaults() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: "postTutorialHints.bundleStarted")
        ud.removeObject(forKey: "postTutorialHints.revision")
        ud.removeObject(forKey: "postTutorialHints.baseline.nonLogCount")
        ud.removeObject(forKey: "postTutorialHints.baseline.quickLogCount")
        for raw in ["scheduleTryEvent", "scheduleTryLog", "petsOpenProfileExtras", "petsAddAnother"] {
            ud.removeObject(forKey: "postTutorialHints.\(raw)")
        }
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

    /// Incomplete tasks scheduled for today for this pet (matches Today list semantics).
    func pendingTodayTaskCount(for pet: Pet) -> Int {
        let cal = Calendar.current
        let regular = scheduleItems.filter {
            cal.isDateInToday($0.time) && $0.pet.id == pet.id && !$0.isCompleted
        }.count
        let birthdays = birthdayItems(on: .now).filter {
            $0.pet.id == pet.id && !$0.isCompleted
        }.count
        return regular + birthdays
    }

    func items(for date: Date) -> [ScheduleItem] {
        let regular = scheduleItems
            .filter { Calendar.current.isDate($0.time, inSameDayAs: date) }
            .filter { selectedPet == nil || $0.pet.id == selectedPet!.id }
        let birthdays = birthdayItems(on: date)
        return (birthdays + regular).sorted { $0.time < $1.time }
    }

    // MARK: - Schedule actions

    /// When the profile name changes in Settings, keep schedule rows in sync for created/assigned person fields.
    func applyUserProfileDisplayNameChange(from previousName: String, to newName: String) {
        let old = previousName.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard old != new else { return }

        var changed = false
        for index in scheduleItems.indices {
            if !old.isEmpty {
                if scheduleItems[index].createdByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) == old {
                    scheduleItems[index].createdByDisplayName = new
                    changed = true
                }
                if scheduleItems[index].assignedToDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) == old {
                    scheduleItems[index].assignedToDisplayName = new
                    changed = true
                }
            } else if !new.isEmpty {
                if scheduleItems[index].createdByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scheduleItems[index].createdByDisplayName = new
                    changed = true
                }
                if scheduleItems[index].assignedToDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    scheduleItems[index].assignedToDisplayName = new
                    changed = true
                }
            }
        }
        if changed {
            syncWidgetSchedule()
        }
    }

    func toggleCompletion(for item: ScheduleItem) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        let wasCompleted = scheduleItems[index].isCompleted
        let profile = UserProfileStorage.trimmedDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
        if !wasCompleted {
            scheduleItems[index].isCompleted = true
            if scheduleItems[index].completedByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !profile.isEmpty
            {
                scheduleItems[index].completedByDisplayName = profile
            }
            if AppRatingPrompt.recordTaskCompleted() {
                showAppRatingPrompt = true
            }
        } else {
            scheduleItems[index].isCompleted = false
            scheduleItems[index].completedByDisplayName = ""
        }
        syncWidgetSchedule()
    }

    /// Stores yes/no for medicine, feed, and water (`ScheduleItem.complianceKind`).
    /// Does not mark the schedule row complete — use `toggleCompletion` for that.
    func setMedicineAccepted(_ accepted: Bool, for item: ScheduleItem) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        scheduleItems[index].medicineAccepted = accepted
        syncWidgetSchedule()
    }

    // MARK: - Pet filter

    func togglePetFilter(_ pet: Pet) {
        selectedPet = (selectedPet?.id == pet.id) ? nil : pet
    }

    // MARK: - Pet CRUD

    func addPet(_ pet: Pet) {
        pets.append(pet)
        syncWidgetSchedule()
    }

    func updatePet(_ pet: Pet) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else { return }
        pets[index] = pet
        for i in scheduleItems.indices where scheduleItems[i].pet.id == pet.id {
            scheduleItems[i].pet = pet
        }
        syncWidgetSchedule()
    }

    func deletePet(_ pet: Pet) {
        pets.removeAll { $0.id == pet.id }
        scheduleItems.removeAll { $0.pet.id == pet.id }
        if selectedPet?.id == pet.id { selectedPet = nil }
        syncWidgetSchedule()
    }

    // MARK: - Home screen widget

    private static func widgetDTO(from item: ScheduleItem) -> WidgetScheduleEventDTO {
        WidgetScheduleEventDTO(
            id: item.id,
            time: item.time,
            isAllDay: item.isAllDay,
            activityName: item.activityName,
            petName: item.pet.name,
            isCompleted: item.isCompleted,
            petPhotoJPEGData: widgetPetThumbnailJPEG(from: item.pet.photoData),
            activitySystemImage: item.activityIcon,
            petSystemImage: item.pet.animalType.systemImage,
            isQuickLog: item.quickLogKind.map { _ in true }
        )
    }

    /// Small JPEG for the widget extension (keeps App Group payload bounded).
    private static func widgetPetThumbnailJPEG(from photoData: Data?, maxSide: CGFloat = 192, maxBytes: Int = 72_000) -> Data? {
        guard let photoData, let image = UIImage(data: photoData) else { return nil }
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return nil }
        let scale = min(1, min(maxSide / w, maxSide / h))
        let target = CGSize(width: (w * scale).rounded(.down), height: (h * scale).rounded(.down))
        guard target.width >= 1, target.height >= 1 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: target)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        var quality: CGFloat = 0.82
        var data = scaled.jpegData(compressionQuality: quality)
        while let d = data, d.count > maxBytes, quality > 0.28 {
            quality -= 0.12
            data = scaled.jpegData(compressionQuality: quality)
        }
        return data
    }

    /// Same ordering as `ScheduleListView` (all-day rows, then timed by time).
    private func widgetTodayScheduleItems(on date: Date = .now) -> [ScheduleItem] {
        let cal = Calendar.current
        let regular = scheduleItems.filter { cal.isDate($0.time, inSameDayAs: date) }
        let birthdays = pets.compactMap { birthdayItem(for: $0, on: date) }
        let merged = (birthdays + regular).sorted { $0.time < $1.time }
        let allDay = merged.filter(\.isAllDay)
        let timed = merged.filter { !$0.isAllDay }
        return allDay + timed
    }

    /// Writes today’s schedule into the App Group and asks WidgetKit to refresh.
    func syncWidgetSchedule() {
        let ordered = widgetTodayScheduleItems()
        let totalToday = ordered.count
        let tf24 = TimeFormat.current == .twentyFourHour
        let dtos = ordered.prefix(8).map { Self.widgetDTO(from: $0) }
        ScheduleWidgetShared.savePayload(
            WidgetSchedulePayload(
                updatedAt: Date(),
                timeFormat24h: tf24,
                totalTodayEventCount: totalToday,
                events: dtos
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: ScheduleWidgetShared.todayEventsWidgetKind)
        ScheduleReminderScheduler.reschedule(for: scheduleItems)
        Task { @MainActor in
            HouseholdSyncCoordinator.shared.scheduleCloudSync(from: self)
        }
    }

    /// Initial launch restores saved pets and schedule before CloudKit merges run.
    static func bootstrapFromPersistence() -> HomeViewModel {
        let vm = HomeViewModel()
        _ = HouseholdLocalStore.applyIfAvailable(to: vm)
        vm.syncWidgetSchedule()
        return vm
    }
}
