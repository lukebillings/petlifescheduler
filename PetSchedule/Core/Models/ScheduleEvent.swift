import Foundation

struct ScheduleEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var startTime: Date
    var symbolName: String
    /// Linked pet profile; `nil` means all pets / household.
    var petId: UUID?
    /// Display name at save time (or "All pets").
    var petName: String

    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        symbolName: String,
        petId: UUID? = nil,
        petName: String = ""
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.symbolName = symbolName
        self.petId = petId
        self.petName = petName
    }

    func timeString(timeStyle: DateFormatter.Style = .short) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = timeStyle
        return f.string(from: startTime)
    }

    var petLabel: String {
        let t = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "All pets" }
        return t
    }
}
