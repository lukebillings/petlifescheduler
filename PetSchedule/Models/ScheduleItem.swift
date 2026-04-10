import Foundation

struct ScheduleItem: Identifiable {
    let id: UUID
    var time: Date
    var activityName: String
    var pet: Pet
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        time: Date,
        activityName: String,
        pet: Pet,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.time = time
        self.activityName = activityName
        self.pet = pet
        self.isCompleted = isCompleted
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: time).lowercased()
    }
}
