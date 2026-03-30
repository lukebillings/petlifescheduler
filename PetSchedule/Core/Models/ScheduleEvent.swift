import Foundation

struct ScheduleEvent: Identifiable, Equatable {
    let id: UUID
    var title: String
    var startTime: Date
    var symbolName: String

    func timeString(timeStyle: DateFormatter.Style = .short) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = timeStyle
        return f.string(from: startTime)
    }
}
