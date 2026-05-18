import Foundation

extension PetDocument {
    /// Five placeholder documents for demos, screenshots, and “Load sample data”.
    static func samplePack(
        for animalType: AnimalType,
        petName: String,
        reference now: Date = .now,
        calendar: Calendar = .current
    ) -> [PetDocument] {
        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: now) ?? now
        }

        let specs: [(name: String, ext: String, daysAgo: Int, bytes: Int)]
        switch animalType {
        case .dog:
            specs = [
                ("Rabies vaccination certificate", "pdf", 120, 48_200),
                ("Annual wellness exam summary", "pdf", 45, 62_400),
                ("Blood panel results", "pdf", 14, 38_900),
                ("Pet insurance policy", "pdf", 200, 156_000),
                ("Hip X-ray", "png", 7, 412_000),
            ]
        case .cat:
            specs = [
                ("FVRCP vaccination record", "pdf", 90, 41_500),
                ("Dental cleaning report", "pdf", 60, 55_800),
                ("Asthma inhaler prescription", "pdf", 21, 28_400),
                ("Wellness bloodwork", "pdf", 10, 36_200),
                ("Microchip registration", "png", 365, 124_000),
            ]
        case .fish:
            specs = [
                ("Aquarium water test log", "pdf", 30, 22_100),
                ("Fin rot treatment notes", "txt", 12, 4_800),
                ("Tank setup checklist", "pdf", 180, 18_600),
                ("Betta care reference sheet", "pdf", 200, 31_200),
                ("Purchase receipt", "jpg", 400, 89_500),
            ]
        case .rabbit:
            specs = [
                ("RHDV vaccination record", "pdf", 80, 39_000),
                ("Annual check-up summary", "pdf", 40, 51_200),
                ("Dental exam notes", "pdf", 15, 27_400),
                ("Diet & hay guide", "pdf", 120, 19_800),
                ("Adoption paperwork", "pdf", 500, 72_000),
            ]
        case .bird:
            specs = [
                ("Avian wellness exam", "pdf", 70, 44_500),
                ("Wing & nail trim record", "pdf", 25, 21_300),
                ("Psittacosis test results", "pdf", 90, 33_600),
                ("Diet conversion plan", "pdf", 45, 16_900),
                ("Band registration photo", "jpg", 200, 98_000),
            ]
        case .tortoise:
            specs = [
                ("Reptile vet exam summary", "pdf", 100, 47_800),
                ("UVB & habitat checklist", "pdf", 60, 24_100),
                ("Fecal parasite screen", "pdf", 20, 29_500),
                ("Hibernation prep notes", "txt", 150, 6_200),
                ("Shell growth chart", "pdf", 30, 38_400),
            ]
        case .other:
            specs = [
                ("Vaccination record", "pdf", 90, 42_000),
                ("Wellness visit summary", "pdf", 35, 58_300),
                ("Lab results", "pdf", 12, 35_700),
                ("Insurance documents", "pdf", 180, 140_000),
                ("Registration certificate", "png", 300, 110_000),
            ]
        }

        return specs.map { spec in
            let label = "\(petName) — \(spec.name)"
            return PetDocument(
                name: spec.name,
                data: stubBytes(label: label, approximateSize: spec.bytes),
                dateAdded: daysAgo(spec.daysAgo),
                fileExtension: spec.ext
            )
        }
    }

    private static func stubBytes(label: String, approximateSize: Int) -> Data {
        var data = Data("PetLifeScheduler sample document\n\(label)\n".utf8)
        if data.count < approximateSize {
            data.append(Data(repeating: 0, count: approximateSize - data.count))
        }
        return data
    }
}
