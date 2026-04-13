import SwiftUI
import Foundation

struct VetDetails: Hashable {
    var organisation: String = ""
    var address: String = ""
    var email: String = ""
    var phone: String = ""

    var isEmpty: Bool {
        organisation.isEmpty && address.isEmpty && email.isEmpty && phone.isEmpty
    }
}

struct Pet: Identifiable, Hashable {
    let id: UUID
    var name: String
    var animalType: AnimalType
    var customAnimalType: String?
    var dateOfBirth: Date?
    var photoData: Data?
    var weightHistory: [WeightEntry]
    var heightHistory: [HeightEntry]
    var notes: String
    var vetDetails: VetDetails

    init(id: UUID = UUID(), name: String, animalType: AnimalType, customAnimalType: String? = nil, dateOfBirth: Date? = nil, photoData: Data? = nil, weightHistory: [WeightEntry] = [], heightHistory: [HeightEntry] = [], notes: String = "", vetDetails: VetDetails = VetDetails()) {
        self.id = id
        self.name = name
        self.animalType = animalType
        self.customAnimalType = animalType == .other ? customAnimalType : nil
        self.dateOfBirth = dateOfBirth
        self.photoData = photoData
        self.weightHistory = weightHistory
        self.heightHistory = heightHistory
        self.notes = notes
        self.vetDetails = vetDetails
    }

    var systemImage: String { animalType.systemImage }
    var color: Color { animalType.color }

    var animalDisplayName: String {
        animalType == .other ? (customAnimalType?.capitalized ?? "Other") : animalType.displayName
    }

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
