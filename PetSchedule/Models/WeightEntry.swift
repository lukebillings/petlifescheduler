import Foundation

struct WeightEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var kg: Double

    init(id: UUID = UUID(), date: Date = .now, kg: Double) {
        self.id = id
        self.date = date
        self.kg = kg
    }
}
