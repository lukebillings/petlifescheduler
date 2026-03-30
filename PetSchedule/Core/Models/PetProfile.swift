import Foundation

struct PetProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    /// Species or animal type, e.g. Dog, Cat, Rabbit.
    var animalSpecies: String
    var dateOfBirth: Date?
    /// JPEG or PNG bytes for the profile photo.
    var photoData: Data?
    /// Centimeters; optional.
    var heightCm: Double?
    /// Kilograms; optional.
    var weightKg: Double?
    var breed: String
    var notes: String
    /// Provider, policy number, renewal dates, etc.
    var insuranceDetails: String?
    /// Clinic name, vet name, phone, address, hours.
    var vetDetails: String?
    /// Groomer / salon name, contact, usual services.
    var groomerDetails: String?

    init(
        id: UUID = UUID(),
        name: String = "",
        animalSpecies: String = "",
        dateOfBirth: Date? = nil,
        photoData: Data? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        breed: String = "",
        notes: String = "",
        insuranceDetails: String? = nil,
        vetDetails: String? = nil,
        groomerDetails: String? = nil
    ) {
        self.id = id
        self.name = name
        self.animalSpecies = animalSpecies
        self.dateOfBirth = dateOfBirth
        self.photoData = photoData
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.breed = breed
        self.notes = notes
        self.insuranceDetails = insuranceDetails
        self.vetDetails = vetDetails
        self.groomerDetails = groomerDetails
    }
}

extension PetProfile {
    /// RFC-style CSV escaping (quotes + doubled internal quotes).
    private static func csvEscapeField(_ string: String) -> String {
        let needsQuotes =
            string.contains(",")
            || string.contains("\n")
            || string.contains("\r")
            || string.contains("\"")
        if !needsQuotes { return string }
        let doubled = string.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(doubled)\""
    }

    /// Two-column CSV (`Key,Value`) suitable for spreadsheets; photo is not embedded.
    func csvExportDocument() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        var lines: [String] = ["Key,Value"]
        func row(_ key: String, _ value: String) {
            lines.append("\(Self.csvEscapeField(key)),\(Self.csvEscapeField(value))")
        }

        row("Pet id", id.uuidString)
        row("Name", name)
        row("Animal species", animalSpecies)
        row("Breed", breed)
        if let dob = dateOfBirth {
            row("Date of birth", dateFormatter.string(from: dob))
        } else {
            row("Date of birth", "")
        }
        row("Height cm", heightCm.map { String(format: "%g", $0) } ?? "")
        row("Weight kg", weightKg.map { String(format: "%g", $0) } ?? "")
        row("Insurance details", insuranceDetails ?? "")
        row("Vet details", vetDetails ?? "")
        row("Groomer details", groomerDetails ?? "")
        row("Notes", notes)
        row("Profile photo", photoData == nil ? "No" : "Yes (image not included in CSV)")

        return lines.joined(separator: "\n")
    }

    /// Safe base name for a `.csv` file in the share sheet.
    func suggestedCSVFileName() -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "pet" : trimmed
        let safe = base
            .map { ch -> Character in
                guard let scalar = ch.unicodeScalars.first else { return "-" }
                if CharacterSet.alphanumerics.contains(scalar) || ch == "-" || ch == "_" { return ch }
                return "-"
            }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let slug = safe.isEmpty ? "pet" : safe
        return "\(slug)-pet-data.csv"
    }
}

enum PetProfileStorage {
    private static let key = "PetSchedule.petProfiles.v1"

    static func load() -> [PetProfile] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PetProfile].self, from: data)) ?? []
    }

    static func save(_ pets: [PetProfile]) {
        guard let data = try? JSONEncoder().encode(pets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
