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
                .foregroundStyle(Color.secondary)
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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
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

            HStack(spacing: 8) {
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
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background {
            if item.quickLogKind != nil {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.appPink.opacity(0.08))
            }
        }
        .overlay {
            if item.quickLogKind != nil {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.appPink.opacity(0.32), lineWidth: 1)
            }
        }
        .modifier(ScheduleRowGlassModifier())
        .opacity(item.isCompleted ? 0.74 : 1.0)
        .saturation(item.isCompleted ? 0.9 : 1.0)
        // Spacer is not hit-testable; without this, taps in the middle of the row miss the row tap.
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { onTap?() }
    }
}

private struct ScheduleRowGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                // Prompt above yes/no so the row title keeps horizontal space.
                VStack(alignment: .center, spacing: 6) {
                    Text(kind.compliancePrompt)
                        .font(AppTypography.micro)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    HStack(spacing: 6) {
                        Button(action: onAccept) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.complianceAccept, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Yes, \(kind.acceptedResultLabel.lowercased())")

                        Button(action: onDecline) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.complianceDecline, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("No, skipped")
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
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
