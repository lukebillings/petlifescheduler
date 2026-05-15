import Foundation

/// Payload written by the app and read by the home screen widget (App Group).
enum ScheduleWidgetShared {
    static let appGroupIdentifier = "group.com.lukebillings.PetSchedule"
    static let todayEventsWidgetKind = "com.lukebillings.PetSchedule.todayEvents"
    private static let payloadKey = "widgetSchedulePayload.v2"

    private static var suite: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func savePayload(_ payload: WidgetSchedulePayload) {
        guard let suite else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(payload) {
            suite.set(data, forKey: payloadKey)
            suite.synchronize()
            return
        }
        var lean = payload
        lean.events = payload.events.map { event in
            var copy = event
            copy.petPhotoJPEGData = nil
            return copy
        }
        if let data = try? encoder.encode(lean) {
            suite.set(data, forKey: payloadKey)
            suite.synchronize()
        }
    }

    static func loadPayload() -> WidgetSchedulePayload? {
        guard let data = suite?.data(forKey: payloadKey),
              let decoded = try? JSONDecoder().decode(WidgetSchedulePayload.self, from: data) else { return nil }
        return decoded
    }

    /// Keeps widget rows aligned with the Today tab when the payload was written on a prior day.
    static func eventsForToday(from payload: WidgetSchedulePayload?, on date: Date = .now) -> [WidgetScheduleEventDTO] {
        guard let payload else { return [] }
        let cal = Calendar.current
        return payload.events.filter { cal.isDate($0.time, inSameDayAs: date) || $0.isAllDay }
    }
}

struct WidgetSchedulePayload: Codable {
    var updatedAt: Date
    /// Mirrors `UserDefaults` key `timeFormat`: `"24h"` vs 12h.
    var timeFormat24h: Bool
    /// All events on the current day (completed + upcoming), for empty vs “all done” in the widget.
    var totalTodayEventCount: Int
    /// Today’s schedule rows (all-day first, then by time) — same ordering as `ScheduleListView`.
    var events: [WidgetScheduleEventDTO]

    enum CodingKeys: String, CodingKey {
        case updatedAt, timeFormat24h, totalTodayEventCount, events
    }

    init(updatedAt: Date, timeFormat24h: Bool, totalTodayEventCount: Int, events: [WidgetScheduleEventDTO]) {
        self.updatedAt = updatedAt
        self.timeFormat24h = timeFormat24h
        self.totalTodayEventCount = totalTodayEventCount
        self.events = events
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        timeFormat24h = try c.decode(Bool.self, forKey: .timeFormat24h)
        events = try c.decode([WidgetScheduleEventDTO].self, forKey: .events)
        totalTodayEventCount = try c.decodeIfPresent(Int.self, forKey: .totalTodayEventCount) ?? events.count
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(timeFormat24h, forKey: .timeFormat24h)
        try c.encode(totalTodayEventCount, forKey: .totalTodayEventCount)
        try c.encode(events, forKey: .events)
    }
}

struct WidgetScheduleEventDTO: Codable, Identifiable {
    var id: UUID
    var time: Date
    var isAllDay: Bool
    var activityName: String
    var petName: String
    var isCompleted: Bool
    /// Downscaled JPEG for the widget (written by the app; optional for older payloads).
    var petPhotoJPEGData: Data?
    /// SF Symbol for the activity (matches `ScheduleItem.activityIcon`).
    var activitySystemImage: String?
    /// SF Symbol fallback when there is no pet photo (matches `Pet.animalType.systemImage`).
    var petSystemImage: String?
    /// Pink-tinted card like quick logs in `ScheduleRowView`.
    var isQuickLog: Bool?

    enum CodingKeys: String, CodingKey {
        case id, time, isAllDay, activityName, petName, isCompleted
        case petPhotoJPEGData, activitySystemImage, petSystemImage, isQuickLog
    }

    init(
        id: UUID,
        time: Date,
        isAllDay: Bool,
        activityName: String,
        petName: String,
        isCompleted: Bool,
        petPhotoJPEGData: Data?,
        activitySystemImage: String?,
        petSystemImage: String?,
        isQuickLog: Bool?
    ) {
        self.id = id
        self.time = time
        self.isAllDay = isAllDay
        self.activityName = activityName
        self.petName = petName
        self.isCompleted = isCompleted
        self.petPhotoJPEGData = petPhotoJPEGData
        self.activitySystemImage = activitySystemImage
        self.petSystemImage = petSystemImage
        self.isQuickLog = isQuickLog
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        time = try c.decode(Date.self, forKey: .time)
        isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
        activityName = try c.decode(String.self, forKey: .activityName)
        petName = try c.decode(String.self, forKey: .petName)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        petPhotoJPEGData = try c.decodeIfPresent(Data.self, forKey: .petPhotoJPEGData)
        activitySystemImage = try c.decodeIfPresent(String.self, forKey: .activitySystemImage)
        petSystemImage = try c.decodeIfPresent(String.self, forKey: .petSystemImage)
        isQuickLog = try c.decodeIfPresent(Bool.self, forKey: .isQuickLog)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(time, forKey: .time)
        try c.encode(isAllDay, forKey: .isAllDay)
        try c.encode(activityName, forKey: .activityName)
        try c.encode(petName, forKey: .petName)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encodeIfPresent(petPhotoJPEGData, forKey: .petPhotoJPEGData)
        try c.encodeIfPresent(activitySystemImage, forKey: .activitySystemImage)
        try c.encodeIfPresent(petSystemImage, forKey: .petSystemImage)
        try c.encodeIfPresent(isQuickLog, forKey: .isQuickLog)
    }
}

extension WidgetScheduleEventDTO {
    func timeLabel(timeFormat24h: Bool) -> String {
        if isAllDay { return "All day" }
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = timeFormat24h ? "HH:mm" : "h:mm a"
        return f.string(from: time)
    }
}
