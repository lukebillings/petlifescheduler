import Foundation

struct WeightEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var kg: Double
    /// Optional photo (e.g. scale display) attached when the reading was logged.
    var imageData: Data?

    init(id: UUID = UUID(), date: Date = .now, kg: Double, imageData: Data? = nil) {
        self.id = id
        self.date = date
        self.kg = kg
        self.imageData = imageData
    }
}
