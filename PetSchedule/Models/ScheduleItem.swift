import Foundation

/// Tracks yes/no logging for medicine, feeding, and water (stored in `medicineAccepted`).
enum ScheduleComplianceKind: Equatable {
    case medicine
    case feed
    case water

    /// Short question above the yes / no controls on schedule rows.
    var compliancePrompt: String {
        switch self {
        case .medicine: return "Taken?"
        case .feed:     return "Ate food?"
        case .water:    return "Drank water?"
        }
    }

    var acceptedResultLabel: String {
        switch self {
        case .medicine: return "Taken"
        case .feed:     return "Ate"
        case .water:    return "Drank"
        }
    }

    var declinedResultLabel: String {
        switch self {
        case .medicine: return "Skipped"
        case .feed:     return "Didn't eat"
        case .water:    return "Didn't drink"
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable {
    case never     = "Never"
    case daily     = "Every day"
    case weekdays  = "Weekdays"
    case weekends  = "Weekends"
    case weekly    = "Every week"
    case monthly   = "Every month"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .never:    return "slash.circle"
        case .daily:    return "sun.max.fill"
        case .weekdays: return "briefcase.fill"
        case .weekends: return "beach.umbrella.fill"
        case .weekly:   return "calendar.badge.clock"
        case .monthly:  return "calendar"
        }
    }
}

struct ScheduleItem: Identifiable {
    let id: UUID
    var time: Date
    var endTime: Date?
    var activityName: String
    var description: String
    var repeatRule: RepeatRule
    var pet: Pet
    var isCompleted: Bool
    var isAllDay: Bool
    var isBirthday: Bool
    /// nil = not yet answered, true = pet took the medicine, false = pet did not
    var medicineAccepted: Bool?

    init(
        id: UUID = UUID(),
        time: Date,
        endTime: Date? = nil,
        activityName: String,
        description: String = "",
        repeatRule: RepeatRule = .never,
        pet: Pet,
        isCompleted: Bool = false,
        isAllDay: Bool = false,
        isBirthday: Bool = false,
        medicineAccepted: Bool? = nil
    ) {
        self.id = id
        self.time = time
        self.endTime = endTime
        self.activityName = activityName
        self.description = description
        self.repeatRule = repeatRule
        self.pet = pet
        self.isCompleted = isCompleted
        self.isAllDay = isAllDay
        self.isBirthday = isBirthday
        self.medicineAccepted = medicineAccepted
    }

    var isMedicineEvent: Bool {
        let n = activityName.lowercased()
        return n.contains("medic") || n.contains("tablet") || n.contains("pill")
    }

    /// Feeding / meal activities (yes–no: ate food).
    var isFeedComplianceEvent: Bool {
        let n = activityName.lowercased()
        return n.contains("feed") || n.contains("meal") || n.contains("food") || n.contains("eat")
    }

    /// Water / hydration (yes–no: drank).
    var isWaterComplianceEvent: Bool {
        let n = activityName.lowercased()
        return n.contains("water") || n.contains("drink") || n.contains("hydrat")
    }

    /// Activities that show the same yes/no control as medicine (mutually exclusive kinds).
    var complianceKind: ScheduleComplianceKind? {
        if isMedicineEvent { return .medicine }
        if isWaterComplianceEvent { return .water }
        if isFeedComplianceEvent { return .feed }
        return nil
    }

    var timeString: String {
        if isAllDay { return "All day" }
        let f = DateFormatter()
        f.dateFormat = TimeFormat.current.dateFormat
        let start = f.string(from: time).lowercased()
        if let end = endTime {
            return "\(start) – \(f.string(from: end).lowercased())"
        }
        return start
    }

    var activityIcon: String { ScheduleItem.icon(for: activityName) }

    static func icon(for activityName: String) -> String {
        let n = activityName.lowercased()
        if n.contains("walk")                                               { return "figure.walk" }
        if n.contains("run")                                                { return "figure.run" }
        if n.contains("feed") || n.contains("meal") || n.contains("food") || n.contains("eat") { return "fork.knife" }
        if n.contains("water") || n.contains("drink")                      { return "drop.fill" }
        if n.contains("groom") || n.contains("bath") || n.contains("wash") { return "bubbles.and.sparkles" }
        if n.contains("vet") || n.contains("doctor") || n.contains("health") { return "stethoscope" }
        if n.contains("sleep") || n.contains("nap") || n.contains("rest")  { return "moon.zzz.fill" }
        if n.contains("play") || n.contains("toy")                         { return "tennisball.fill" }
        if n.contains("train") || n.contains("trick")                      { return "star.fill" }
        if n.contains("medic") || n.contains("tablet") || n.contains("pill") { return "pill.fill" }
        if n.contains("brush") || n.contains("comb")                       { return "comb.fill" }
        return "pawprint.fill"
    }
}
