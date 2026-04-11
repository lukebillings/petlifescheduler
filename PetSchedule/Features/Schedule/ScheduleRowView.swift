import SwiftUI

struct ScheduleRowView: View {
    let item: ScheduleItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            PetAvatarView(pet: item.pet, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.timeString)
                    .font(.headline.bold())
                Text(item.activityName)
                    .font(.subheadline)
                    .opacity(0.85)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isCompleted ? Color(red: 0.0, green: 0.55, blue: 0.2) : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    let pet = Pet(name: "Max", animalType: .dog)
    VStack(spacing: 12) {
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Walk", pet: pet, isCompleted: true)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Sleep", pet: pet)) {}
    }
    .padding()
}
