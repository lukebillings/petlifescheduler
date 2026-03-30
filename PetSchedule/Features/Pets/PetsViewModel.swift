import Foundation

@Observable
final class PetsViewModel {
    var pets: [PetProfile] = [] {
        didSet { PetProfileStorage.save(pets) }
    }

    init() {
        pets = PetProfileStorage.load()
    }

    func upsert(_ profile: PetProfile) {
        var next = pets
        if let i = next.firstIndex(where: { $0.id == profile.id }) {
            next[i] = profile
        } else {
            next.append(profile)
        }
        pets = next.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func delete(id: UUID) {
        pets = pets.filter { $0.id != id }
    }

    func profile(id: UUID) -> PetProfile? {
        pets.first { $0.id == id }
    }
}
