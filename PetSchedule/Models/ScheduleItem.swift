import Foundation

/// Tracks yes/no logging for medicine, feeding, and water (stored in `medicineAccepted`).
enum ScheduleComplianceKind: Equatable, Hashable {
    case medicine
    case feed
    case water

    /// Short question beside the yes / no controls on schedule rows.
    var compliancePrompt: String {
        switch self {
        case .medicine: return "Took?"
        case .feed:     return "Ate?"
        case .water:    return "Drank?"
        }
    }

    /// Past-tense outcomes on schedule rows (logged chip after the user answers).
    var acceptedResultLabel: String {
        switch self {
        case .medicine: return "Took"
        case .feed:     return "Ate"
        case .water:    return "Drank"
        }
    }

    /// Shown on schedule row after user logs compliance.
    var resultSymbolName: String {
        switch self {
        case .medicine: return "pills.fill"
        case .feed:     return "fork.knife"
        case .water:    return "drop.fill"
        }
    }

    var declinedResultLabel: String {
        "Skipped"
    }

    /// Analytics section titles (schedule yes/no compliance).
    var analyticsSectionTitle: String {
        switch self {
        case .medicine: return "Medicine Compliance"
        case .feed:     return "Feeding Compliance"
        case .water:    return "Water Compliance"
        }
    }

    /// Full-screen log title when filtering by pet (`petName` nil → all pets).
    func logNavigationTitle(petName: String?) -> String {
        let base: String = {
            switch self {
            case .medicine: return "Medicine Log"
            case .feed:     return "Feeding Log"
            case .water:    return "Water Log"
            }
        }()
        if let name = petName { return "\(name)'s \(base)" }
        return base
    }

    var logEmptySystemImage: String {
        switch self {
        case .medicine: return "pill.fill"
        case .feed:     return "fork.knife"
        case .water:    return "drop.fill"
        }
    }

    var logEmptyTitle: String {
        switch self {
        case .medicine: return "No Medicine Events"
        case .feed:     return "No Feeding Events"
        case .water:    return "No Water Events"
        }
    }

    var logEmptyDescription: String {
        switch self {
        case .medicine: return "No medicine events have been logged yet."
        case .feed:     return "No feeding events have been logged yet."
        case .water:    return "No water events have been logged yet."
        }
    }

    /// Day card copy when there are no rows for that calendar day.
    var logDayEmptyRowLabel: String {
        switch self {
        case .medicine: return "No medicine scheduled"
        case .feed:     return "No feeding scheduled"
        case .water:    return "No water scheduled"
        }
    }

    /// Shown under the chart when the selected date range has no rows for this pet.
    var analyticsPeriodEmptyMessage: String {
        switch self {
        case .medicine: return "No medicine events in this period."
        case .feed:     return "No feeding events in this period."
        case .water:    return "No water events in this period."
        }
    }
}

enum RepeatRule: String, CaseIterable, Identifiable, Codable {
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
enum QuickLogKind: String, CaseIterable, Identifiable, Codable {
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
enum PetMood: String, CaseIterable, Identifiable, Hashable, Codable {
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

    /// 1 (lowest) … 5 (highest) for analytics charts — higher means brighter mood.
    var wellbeingChartScore: Double {
        switch self {
        case .great: return 5
        case .good: return 4
        case .okay: return 3
        case .low: return 2
        case .anxious: return 1
        }
    }

    /// Mood label for chart axis ticks at integer scores 1…5.
    static func mood(forChartScore score: Int) -> PetMood? {
        switch score {
        case 5: return .great
        case 4: return .good
        case 3: return .okay
        case 2: return .low
        case 1: return .anxious
        default: return nil
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
    /// Household member who created this event or log (names are visible to household participants).
    var createdByDisplayName: String
    /// Who is expected to perform the task.
    var assignedToDisplayName: String
    /// Who completed or logged the outcome.
    var completedByDisplayName: String
    /// Highlight color for the assignee name pill on event cards.
    var assigneeAccent: ScheduleAssigneeAccent

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
        attachmentImageData: Data? = nil,
        createdByDisplayName: String = "",
        assignedToDisplayName: String = "",
        completedByDisplayName: String = "",
        assigneeAccent: ScheduleAssigneeAccent = .pink
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
        self.createdByDisplayName = createdByDisplayName
        self.assignedToDisplayName = assignedToDisplayName
        self.completedByDisplayName = completedByDisplayName
        self.assigneeAccent = assigneeAccent
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
        f.locale = .autoupdatingCurrent
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
        if n.contains("sleep") || n.contains("nap") || n.contains("rest") || n.contains("bed") { return "moon.zzz.fill" }
        if n.contains("play") || n.contains("toy")                         { return "tennisball.fill" }
        if n.contains("train") || n.contains("trick")                      { return "star.fill" }
        if n.contains("medic") || n.contains("tablet") || n.contains("pill") { return "pill.fill" }
        if n.contains("brush") || n.contains("comb")                       { return "comb.fill" }
        return "pawprint.fill"
    }
}
