import Foundation

@Observable
final class HomeViewModel {
    private let calendar = Calendar.current

    /// Shared to-dos, habits, and wellness logs.
    var trackStore: TrackStore
    var scheduleViewModel: ScheduleViewModel

    /// Today’s schedule entries for this pet (and any “all pets” events with no specific pet).
    func todayCalendarItems(forPet profile: PetProfile) -> [HomeCalendarItem] {
        scheduleViewModel.eventsToday
            .filter { event in
                guard let pid = event.petId else { return true }
                return pid == profile.id
            }
            .sorted { $0.startTime < $1.startTime }
            .map {
                HomeCalendarItem(
                    id: $0.id,
                    title: $0.title,
                    startTime: $0.startTime,
                    symbolName: $0.symbolName
                )
            }
    }

    var todos: [HomeTodo] {
        trackStore.todos
            .sorted { a, b in
                if a.isDone != b.isDone { return !a.isDone && b.isDone }
                return a.createdAt > b.createdAt
            }
            .map { HomeTodo(id: $0.id, title: $0.title, isDone: $0.isDone) }
    }

    var habits: [HomeHabit] {
        let key = trackStore.todayDayKey
        return trackStore.habits.map { h in
            HomeHabit(
                id: h.id,
                title: h.title,
                completedToday: h.isCompleted(on: key),
                targetSummary: h.detail.isEmpty ? "Daily" : h.detail
            )
        }
    }

    /// Pets with a saved date of birth (for age-year ring).
    var dogs: [HomeDog] {
        PetProfileStorage.load().compactMap { profile -> HomeDog? in
            guard let dob = profile.dateOfBirth else { return nil }
            let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return HomeDog(id: profile.id, name: name.isEmpty ? "Pet" : name, birthday: dob)
        }
    }

    /// All saved pet profiles (for home cards), sorted by name.
    var homePets: [PetProfile] {
        PetProfileStorage.load().sorted { a, b in
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Wellness rows for a specific pet (matched by name).
    func wellnessStateItems(forPet profile: PetProfile) -> [PetStateItem] {
        let target = Self.normalizedPetKey(profile.name)
        return trackStore.wellnessLogs
            .filter { log in
                let n = Self.normalizedPetKey(log.petName)
                return !n.isEmpty && n == target
            }
            .prefix(6)
            .map { log in
                let pn = log.petName.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let labelName = pn.isEmpty ? (fallback.isEmpty ? "Pet" : fallback) : pn
                return PetStateItem(
                    id: log.id,
                    petName: labelName,
                    label: "Energy · mood",
                    value: Self.wellnessLogValueSummary(log),
                    symbolName: "heart.fill"
                )
            }
    }

    private static func wellnessLogValueSummary(_ log: WellnessStateLog) -> String {
        var parts: [String] = ["\(log.energy) · \(log.happiness)"]
        if let w = log.weightKg { parts.append(String(format: "%.1f kg", w)) }
        if let h = log.heightCm { parts.append(String(format: "%.1f cm", h)) }
        return parts.joined(separator: " · ")
    }

    func homeDog(for profile: PetProfile) -> HomeDog? {
        guard let dob = profile.dateOfBirth else { return nil }
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return HomeDog(id: profile.id, name: name.isEmpty ? "Pet" : name, birthday: dob)
    }

    private static func normalizedPetKey(_ name: String) -> String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.isEmpty ? "" : t
    }

    init(trackStore: TrackStore, scheduleViewModel: ScheduleViewModel) {
        self.trackStore = trackStore
        self.scheduleViewModel = scheduleViewModel
    }

    func toggleTodo(id: UUID) {
        trackStore.toggleTodo(id: id)
    }

    func toggleHabit(id: UUID) {
        trackStore.toggleHabitToday(id: id)
    }

    func ageYearProgress(for dog: HomeDog) -> Double {
        DogAgeYear.progressFraction(birthday: dog.birthday)
    }

    func chronologicalAge(for dog: HomeDog) -> Int {
        DogAgeYear.chronologicalYears(birthday: dog.birthday)
    }

    /// Age ring: full years as "Ny", else months, else days (two lines when not years).
    func ageRingDisplay(for dog: HomeDog) -> (primary: String, secondary: String, accessibility: String) {
        let years = chronologicalAge(for: dog)
        if years >= 1 {
            return ("\(years)y", "", "\(years) years old")
        }
        let m = calendar.dateComponents([.month], from: dog.birthday, to: Date()).month ?? 0
        if m >= 1 {
            let unit = m == 1 ? "mo" : "mos"
            return (String(m), unit, "\(m) \(unit) old")
        }
        let d = max(0, calendar.dateComponents([.day], from: dog.birthday, to: Date()).day ?? 0)
        let dd = max(d, 1)
        return (String(dd), "d", dd == 1 ? "1 day old" : "\(dd) days old")
    }

}
