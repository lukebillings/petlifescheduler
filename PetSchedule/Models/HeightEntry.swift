import Foundation

struct HeightEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var cm: Double

    init(id: UUID = UUID(), date: Date = .now, cm: Double) {
        self.id = id
        self.date = date
        self.cm = cm
    }
}
