import SwiftUI
import UIKit

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
                .font(AppTypography.rowIcon)
                .foregroundStyle(Color.appPink)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.timeString)
                    .font(AppTypography.primaryLabel)
                Text(item.activityName)
                    .font(AppTypography.secondaryLabel)
                    .opacity(0.85)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let mood = item.petMood {
                    Text("\(mood.emoji) \(mood.rawValue)")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(Color.appPink.opacity(0.95))
                }
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
                if item.repeatRule != .never {
                    Label(item.repeatRule.rawValue, systemImage: item.repeatRule.icon)
                        .font(AppTypography.micro)
                        .foregroundStyle(Color.appPink)
                }
                if let data = item.attachmentImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.top, 4)
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
        .padding(.horizontal, 18)
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
                Text(accepted ? kind.acceptedResultLabel : kind.declinedResultLabel)
                    .font(AppTypography.secondaryEmphasis)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
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
