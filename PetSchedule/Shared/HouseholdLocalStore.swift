import Foundation

/// Persists pets + schedule on-device (and mirrors CloudKit state locally).
enum HouseholdLocalStore {
    private static let snapshotKey = "householdLocalSnapshot.v2"

    private struct Snapshot: Codable {
        var pets: [Pet]
        var scheduleRows: [ScheduleRowDTO]
    }

    private struct ScheduleRowDTO: Codable {
        var id: UUID
        var time: Date
        var endTime: Date?
        var activityName: String
        var description: String
        var repeatRule: RepeatRule
        var petId: UUID
        var isCompleted: Bool
        var isAllDay: Bool
        var isBirthday: Bool
        var medicineAccepted: Bool?
        var quickLogKind: QuickLogKind?
        var petMood: PetMood?
        var attachmentImageData: Data?
        var createdByDisplayName: String
        var assignedToDisplayName: String
        var completedByDisplayName: String
        var assigneeAccentRaw: String

        enum CodingKeys: String, CodingKey {
            case id, time, endTime, activityName, description, repeatRule, petId
            case isCompleted, isAllDay, isBirthday, medicineAccepted, quickLogKind, petMood
            case attachmentImageData
            case createdByDisplayName, assignedToDisplayName, completedByDisplayName
            case assigneeAccentRaw
            case loggedByDisplayName
        }

        init(from item: ScheduleItem) {
            id = item.id
            time = item.time
            endTime = item.endTime
            activityName = item.activityName
            description = item.description
            repeatRule = item.repeatRule
            petId = item.pet.id
            isCompleted = item.isCompleted
            isAllDay = item.isAllDay
            isBirthday = item.isBirthday
            medicineAccepted = item.medicineAccepted
            quickLogKind = item.quickLogKind
            petMood = item.petMood
            attachmentImageData = item.attachmentImageData
            createdByDisplayName = item.createdByDisplayName
            assignedToDisplayName = item.assignedToDisplayName
            completedByDisplayName = item.completedByDisplayName
            assigneeAccentRaw = item.assigneeAccent.rawValue
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            time = try c.decode(Date.self, forKey: .time)
            endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
            activityName = try c.decode(String.self, forKey: .activityName)
            description = try c.decode(String.self, forKey: .description)
            repeatRule = try c.decode(RepeatRule.self, forKey: .repeatRule)
            petId = try c.decode(UUID.self, forKey: .petId)
            isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
            isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
            isBirthday = try c.decode(Bool.self, forKey: .isBirthday)
            medicineAccepted = try c.decodeIfPresent(Bool.self, forKey: .medicineAccepted)
            quickLogKind = try c.decodeIfPresent(QuickLogKind.self, forKey: .quickLogKind)
            petMood = try c.decodeIfPresent(PetMood.self, forKey: .petMood)
            attachmentImageData = try c.decodeIfPresent(Data.self, forKey: .attachmentImageData)
            createdByDisplayName = try c.decodeIfPresent(String.self, forKey: .createdByDisplayName) ?? ""
            assignedToDisplayName = try c.decodeIfPresent(String.self, forKey: .assignedToDisplayName) ?? ""
            completedByDisplayName = try c.decodeIfPresent(String.self, forKey: .completedByDisplayName) ?? ""
            assigneeAccentRaw = try c.decodeIfPresent(String.self, forKey: .assigneeAccentRaw) ?? ScheduleAssigneeAccent.pink.rawValue
            if createdByDisplayName.isEmpty,
               let legacy = try c.decodeIfPresent(String.self, forKey: .loggedByDisplayName)?
                   .trimmingCharacters(in: .whitespacesAndNewlines),
               !legacy.isEmpty
            {
                createdByDisplayName = legacy
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(time, forKey: .time)
            try c.encodeIfPresent(endTime, forKey: .endTime)
            try c.encode(activityName, forKey: .activityName)
            try c.encode(description, forKey: .description)
            try c.encode(repeatRule, forKey: .repeatRule)
            try c.encode(petId, forKey: .petId)
            try c.encode(isCompleted, forKey: .isCompleted)
            try c.encode(isAllDay, forKey: .isAllDay)
            try c.encode(isBirthday, forKey: .isBirthday)
            try c.encodeIfPresent(medicineAccepted, forKey: .medicineAccepted)
            try c.encodeIfPresent(quickLogKind, forKey: .quickLogKind)
            try c.encodeIfPresent(petMood, forKey: .petMood)
            try c.encodeIfPresent(attachmentImageData, forKey: .attachmentImageData)
            try c.encode(createdByDisplayName, forKey: .createdByDisplayName)
            try c.encode(assignedToDisplayName, forKey: .assignedToDisplayName)
            try c.encode(completedByDisplayName, forKey: .completedByDisplayName)
            try c.encode(assigneeAccentRaw, forKey: .assigneeAccentRaw)
        }

        func resolveScheduleItem(pets: [Pet]) -> ScheduleItem? {
            guard let pet = pets.first(where: { $0.id == petId }) else { return nil }
            return ScheduleItem(
                id: id,
                time: time,
                endTime: endTime,
                activityName: activityName,
                description: description,
                repeatRule: repeatRule,
                pet: pet,
                isCompleted: isCompleted,
                isAllDay: isAllDay,
                isBirthday: isBirthday,
                medicineAccepted: medicineAccepted,
                quickLogKind: quickLogKind,
                petMood: petMood,
                attachmentImageData: attachmentImageData,
                createdByDisplayName: createdByDisplayName,
                assignedToDisplayName: assignedToDisplayName,
                completedByDisplayName: completedByDisplayName,
                assigneeAccent: ScheduleAssigneeAccent.decode(stored: assigneeAccentRaw)
            )
        }
    }

    static func save(viewModel: HomeViewModel, using defaults: UserDefaults = .standard) {
        let rows = viewModel.scheduleItems.map { ScheduleRowDTO(from: $0) }
        let snap = Snapshot(pets: viewModel.pets, scheduleRows: rows)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func applyIfAvailable(to viewModel: HomeViewModel, using defaults: UserDefaults = .standard) -> Bool {
        guard let data = defaults.data(forKey: snapshotKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return false }
        viewModel.pets = snap.pets
        viewModel.scheduleItems = snap.scheduleRows.compactMap { $0.resolveScheduleItem(pets: snap.pets) }
        return true
    }

    static func clear(using defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: snapshotKey)
    }

    static var hasSnapshot: Bool {
        UserDefaults.standard.data(forKey: snapshotKey) != nil
    }
}
