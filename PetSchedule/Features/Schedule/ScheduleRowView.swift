import SwiftUI

struct ScheduleRowView: View {
    let item: ScheduleItem
    let onToggle: () -> Void
    var onTap: (() -> Void)? = nil
    var onPetTap: (() -> Void)? = nil
    var onMedicineAccept: ((Bool) -> Void)? = nil

    private var assigneeNameTrimmed: String {
        item.assignedToDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Single compact secondary line so cards stay short.
    private var compactDetailLine: String? {
        if !item.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return item.description
        }
        if let mood = item.petMood {
            return "\(mood.emoji) \(mood.rawValue)"
        }
        if item.repeatRule != .never {
            return item.repeatRule.rawValue
        }
        if item.quickLogKind != nil {
            let createdBy = item.createdByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let completedBy = item.completedByDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !createdBy.isEmpty { return "Created by \(createdBy)" }
            if !completedBy.isEmpty { return "Completed by \(completedBy)" }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            PetAvatarView(pet: item.pet, size: 48)
                .onTapGesture { onPetTap?() }

            Image(systemName: item.activityIcon)
                .font(AppTypography.rowIcon)
                .foregroundStyle(Color.appPink)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.timeString)
                        .font(AppTypography.primaryLabel)
                        .lineLimit(1)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)

                    Text(item.activityName)
                        .font(AppTypography.secondaryLabel)
                        .opacity(0.9)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    if !assigneeNameTrimmed.isEmpty, item.quickLogKind == nil {
                        Text(assigneeNameTrimmed)
                            .font(AppTypography.micro)
                            .fontWeight(.medium)
                            .foregroundStyle(item.assigneeAccent.pillLabelColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(item.assigneeAccent.swatchColor))
                    }

                    if let detail = compactDetailLine {
                        Text(detail)
                            .font(AppTypography.supportingText)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

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
                    .font(AppTypography.completionControl)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isCompleted ? Color.complianceAccept : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background {
            if item.quickLogKind != nil {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.appPink.opacity(0.2))
            }
        }
        .overlay {
            if item.quickLogKind != nil {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.appPink.opacity(0.35), lineWidth: 1)
            }
        }
        .modifier(ScheduleRowGlassModifier(isQuickLog: item.quickLogKind != nil))
        // Spacer is not hit-testable; without this, taps in the middle of the row miss the row tap.
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { onTap?() }
    }
}

private struct ScheduleRowGlassModifier: ViewModifier {
    let isQuickLog: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isQuickLog {
            content
        } else {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24))
        }
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
                HStack(spacing: 6) {
                    Text(accepted ? kind.acceptedResultLabel : kind.declinedResultLabel)
                        .font(AppTypography.compactControl)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(accepted ? Color.complianceAccept : Color.complianceDecline)
                )
            } else {
                VStack(alignment: .center, spacing: 6) {
                    Text(kind.compliancePrompt)
                        .font(AppTypography.micro)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button(action: onAccept) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color.complianceAccept, in: Circle())
                                Text(kind.acceptedResultLabel)
                                    .font(AppTypography.compactControl)
                                    .foregroundStyle(Color.complianceAccept)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: onDecline) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(AppTypography.micro)
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color.complianceDecline, in: Circle())
                                Text(kind.declinedResultLabel)
                                    .font(AppTypography.compactControl)
                                    .foregroundStyle(Color.complianceDecline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
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
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Walk", pet: pet, assignedToDisplayName: "Bob")) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give Medication", pet: pet)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give Medication", pet: pet, medicineAccepted: true)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give Medication", pet: pet, medicineAccepted: false)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Feed", pet: pet)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Give water", pet: pet, medicineAccepted: true)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Poo", pet: pet, isCompleted: true, quickLogKind: .poo)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Accident", description: "Kitchen", pet: pet, isCompleted: true, quickLogKind: .custom)) {}
        ScheduleRowView(item: ScheduleItem(time: .now, activityName: "Mood", pet: pet, isCompleted: true, quickLogKind: .mood, petMood: .good)) {}
    }
    .padding()
}
