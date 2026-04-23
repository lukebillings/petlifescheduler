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
    var documents: [PetDocument]

    init(id: UUID = UUID(), name: String, animalType: AnimalType, customAnimalType: String? = nil, dateOfBirth: Date? = nil, photoData: Data? = nil, weightHistory: [WeightEntry] = [], heightHistory: [HeightEntry] = [], notes: String = "", vetDetails: VetDetails = VetDetails(), documents: [PetDocument] = []) {
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
        self.documents = documents
    }

    var systemImage: String { animalType.systemImage }
    var color: Color { animalType.color }

    var animalDisplayName: String {
        animalType == .other ? (customAnimalType?.capitalized ?? "Other") : animalType.displayName
    }

    /// Human-readable age from `dateOfBirth` (e.g. for UI and PDFs).
    var age: String? {
        guard let dob = dateOfBirth else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: dob)
        let end = cal.startOfDay(for: .now)
        guard start <= end else { return nil }

        let years = cal.dateComponents([.year], from: start, to: end).year ?? 0
        if years >= 1 {
            return years == 1 ? "1 year old" : "\(years) years old"
        }

        let months = cal.dateComponents([.month], from: start, to: end).month ?? 0
        if months >= 1 {
            return months == 1 ? "1 month old" : "\(months) months old"
        }

        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        if days > 1 {
            return "\(days) days old"
        }
        if days == 1 {
            return "1 day old"
        }
        return "Born today"
    }

    /// Full calendar years plus days since the last birthday (start of day). Nil without a valid DOB.
    var ageYearsAndDaysComponents: (years: Int, days: Int)? {
        guard let dob = dateOfBirth else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: dob)
        let end = cal.startOfDay(for: .now)
        guard start <= end else { return nil }

        let years = cal.dateComponents([.year], from: start, to: end).year ?? 0
        guard let afterLastBirthday = cal.date(byAdding: .year, value: years, to: start) else {
            return (years, 0)
        }
        let days = cal.dateComponents([.day], from: afterLastBirthday, to: end).day ?? 0
        return (years, days)
    }

    /// Profile-style line, e.g. "2 years, 47 days" or "Born today". Nil if no DOB.
    var ageYearsAndDaysSummary: String? {
        guard let (y, d) = ageYearsAndDaysComponents else { return nil }
        if y == 0 && d == 0 { return "Born today" }
        let yearPart: String
        switch y {
        case 0: yearPart = "0 years"
        case 1: yearPart = "1 year"
        default: yearPart = "\(y) years"
        }
        let dayPart = d == 1 ? "1 day" : "\(d) days"
        return "\(yearPart), \(dayPart)"
    }
}
