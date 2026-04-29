import Foundation

/// Tracks yes/no logging for medicine, feeding, and water (stored in `medicineAccepted`).
enum ScheduleComplianceKind: Equatable {
    case medicine
    case feed
    case water

    /// Short question above the yes / no controls on schedule rows.
    var compliancePrompt: String {
        switch self {
        case .medicine: return "Took it?"
        case .feed:     return "Ate food?"
        case .water:    return "Drank water?"
        }
    }

    /// Past-tense outcomes after logging — lowercase chips: took / ate / drank / skipped.
    var acceptedResultLabel: String {
        switch self {
        case .medicine: return "took"
        case .feed:     return "ate"
        case .water:    return "drank"
        }
    }

    var declinedResultLabel: String {
        "skipped"
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

/// One-off bathroom / care logs from **+ Log**; shown with a pink-tinted row.
enum QuickLogKind: String, CaseIterable, Identifiable {
    case poo = "Poo"
    case wee = "Wee"
    case mood = "Mood"
    case custom = "Custom"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .poo: return "toilet.fill"
        case .wee: return "drop.fill"
        case .mood: return "face.smiling"
        case .custom: return "note.text"
        }
    }
}

/// Recorded with **Log → Mood** for behaviour / wellbeing notes.
enum PetMood: String, CaseIterable, Identifiable, Hashable {
    case great = "Great"
    case good = "Good"
    case okay = "Okay"
    case low = "Low"
    case anxious = "Anxious"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: return "😄"
        case .good: return "🙂"
        case .okay: return "😐"
        case .low: return "😔"
        case .anxious: return "😰"
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
    /// Set for quick logs from **+ Log**; drives icon and pink row styling.
    var quickLogKind: QuickLogKind?
    /// How the pet seemed — only used when `quickLogKind == .mood`.
    var petMood: PetMood?
    /// Optional photo (“memory”) attached to this event or quick log.
    var attachmentImageData: Data?

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
        medicineAccepted: Bool? = nil,
        quickLogKind: QuickLogKind? = nil,
        petMood: PetMood? = nil,
        attachmentImageData: Data? = nil
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
        self.quickLogKind = quickLogKind
        self.petMood = petMood
        self.attachmentImageData = attachmentImageData
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
        if quickLogKind != nil { return nil }
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

    var activityIcon: String {
        if let kind = quickLogKind { return kind.iconName }
        return ScheduleItem.icon(for: activityName)
    }

    static func icon(for activityName: String) -> String {
        let n = activityName.lowercased()
        if n.contains("poo") || n.contains("poop")                         { return "toilet.fill" }
        if n.contains("wee") || n.contains("urin") || n.contains("pee")  { return "drop.fill" }
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
