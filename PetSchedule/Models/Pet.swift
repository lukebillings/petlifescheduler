import SwiftUI
import Foundation

struct Pet: Identifiable, Hashable {
    let id: UUID
    var name: String
    var animalType: AnimalType
    var dateOfBirth: Date?

    init(id: UUID = UUID(), name: String, animalType: AnimalType, dateOfBirth: Date? = nil) {
        self.id = id
        self.name = name
        self.animalType = animalType
        self.dateOfBirth = dateOfBirth
    }

    var systemImage: String { animalType.systemImage }
    var color: Color { animalType.color }

    var age: String? {
        guard let dob = dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.year, .month], from: dob, to: .now)
        if let years = components.year, years > 0 {
            return "\(years) yr\(years == 1 ? "" : "s")"
        } else if let months = components.month, months > 0 {
            return "\(months) mo"
        }
        return "< 1 mo"
    }
}
