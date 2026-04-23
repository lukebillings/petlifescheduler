import Foundation

struct HeightEntry: Identifiable, Hashable, Codable {
    let id: UUID
    var date: Date
    var cm: Double
    /// Optional photo attached when the reading was logged.
    var imageData: Data?

    init(id: UUID = UUID(), date: Date = .now, cm: Double, imageData: Data? = nil) {
        self.id = id
        self.date = date
        self.cm = cm
        self.imageData = imageData
    }
}
