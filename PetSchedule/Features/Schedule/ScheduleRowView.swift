import SwiftUI

struct ScheduleRowView: View {
    let item: ScheduleItem
    let onToggle: () -> Void
    var onTap: (() -> Void)? = nil
    var onPetTap: (() -> Void)? = nil
    var onMedicineAccept: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            PetAvatarView(pet: item.pet, size: 52)
                .onTapGesture { onPetTap?() }

            Image(systemName: item.activityIcon)
                .font(.body.bold())
                .foregroundStyle(Color.appPink)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.timeString)
                    .font(.headline.bold())
                Text(item.activityName)
                    .font(.subheadline)
                    .opacity(0.85)
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if item.repeatRule != .never {
                    Label(item.repeatRule.rawValue, systemImage: item.repeatRule.icon)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.appPink)
                }
            }

            Spacer()

            if let kind = item.complianceKind {
                CareCompliancePill(
                    kind: kind,
                    accepted: item.medicineAccepted,
                    onAccept: { onMedicineAccept?(true) },
                    onDecline: { onMedicineAccept?(false) }
                )
            }

            Button {
                onToggle()
            } label: {
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
        .onTapGesture { onTap?() }
    }
}

// MARK: - Care compliance (medicine, feed, water)

private struct CareCompliancePill: View {
    let kind: ScheduleComplianceKind
    let accepted: Bool?
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        Group {
            if let accepted {
                HStack(spacing: 4) {
                    Image(systemName: accepted ? "checkmark" : "xmark")
                        .font(.caption2.bold())
                    Text(accepted ? kind.acceptedResultLabel : kind.declinedResultLabel)
                        .font(.caption2.bold())
                }
                .foregroundStyle(accepted ? Color.green : Color.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(accepted ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(accepted ? Color.green.opacity(0.35) : Color.red.opacity(0.35), lineWidth: 1)
                )
            } else {
                VStack(alignment: .center, spacing: 6) {
                    Text(kind.compliancePrompt)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button(action: onAccept) {
                            Image(systemName: "checkmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.green, in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onDecline) {
                            Image(systemName: "xmark")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.red, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.25), value: accepted)
    }
}

#Preview {
    let pet = Pet(name: "Max", animalType: .dog)
    VStack(spacing: 12) {
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Walk", pet: pet, isCompleted: true)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give Medication", pet: pet)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give Medication", pet: pet, medicineAccepted: true)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give Medication", pet: pet, medicineAccepted: false)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Feed", pet: pet)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give water", pet: pet, medicineAccepted: true)) {}
    }
    .padding()
}
