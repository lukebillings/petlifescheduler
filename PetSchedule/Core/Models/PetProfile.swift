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

    init(
        id: UUID = UUID(),
        name: String = "",
        animalSpecies: String = "",
        dateOfBirth: Date? = nil,
        photoData: Data? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        breed: String = "",
        notes: String = ""
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
