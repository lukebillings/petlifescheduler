import SwiftUI
import PhotosUI
import UIKit

struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel
    let item: ScheduleItem

    @State private var activityName: String
    @State private var eventDescription: String
    @State private var eventDate: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var repeatRule: RepeatRule
    @State private var customActivity: Bool
    @State private var attachmentImageData: Data?
    @State private var attachmentPhotoItem: PhotosPickerItem?
    @State private var mood: PetMood
    @State private var isCompleted: Bool
    @State private var selectedPet: Pet?
    @State private var createdBy: String
    @State private var assignedTo: String
    @State private var completedBy: String
    @State private var assigneeAccent: ScheduleAssigneeAccent

    private let commonActivities = ["Walk", "Feed", "Give water", "Put to Bed", "Play", "Vet", "Groom", "Give Medication"]
    private static let legacyPresetNames: Set<String> = ["Eat", "Medicine"]

    init(viewModel: HomeViewModel, item: ScheduleItem) {
        self.viewModel = viewModel
        self.item = item
        _activityName    = State(initialValue: item.activityName)
        _eventDescription = State(initialValue: item.description)
        _eventDate       = State(initialValue: item.time)
        _hasEndTime      = State(initialValue: item.endTime != nil)
        _endTime         = State(initialValue: item.endTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: item.time) ?? item.time)
        _repeatRule      = State(initialValue: item.repeatRule)
        let presets = Set(commonActivities).union(Self.legacyPresetNames)
        _customActivity  = State(initialValue: item.quickLogKind != nil || !presets.contains(item.activityName))
        _attachmentImageData = State(initialValue: item.attachmentImageData)
        _mood = State(initialValue: item.petMood ?? .okay)
        _isCompleted = State(initialValue: item.isCompleted)
        _selectedPet = State(initialValue: item.pet)
        _createdBy = State(initialValue: item.createdByDisplayName)
        _assignedTo = State(initialValue: item.assignedToDisplayName)
        _completedBy = State(initialValue: item.completedByDisplayName)
        _assigneeAccent = State(initialValue: item.assigneeAccent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    FormCompletedCheckboxRow(isCompleted: $isCompleted)
                }

                Section {
                    if viewModel.pets.isEmpty {
                        Text("Add a pet first in the My Pets tab.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(viewModel.pets) { pet in
                                    let isSelected = selectedPet?.id == pet.id
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            selectedPet = isSelected ? nil : pet
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            PetAvatarView(pet: pet, size: 52)
                                                .overlay {
                                                    if isSelected {
                                                        Circle()
                                                            .strokeBorder(Color.appPink, lineWidth: 3)
                                                    }
                                                }
                                                .scaleEffect(isSelected ? 1.05 : 1.0)
                                            Text(pet.name)
                                                .font(AppTypography.compactControl)
                                                .foregroundStyle(isSelected ? Color.appPink : Color.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Planned for")
                }

                Section("Activity") {
                    if customActivity {
                        TextField("Activity name", text: $activityName)
                    } else {
                        Picker("Activity", selection: $activityName) {
                            ForEach(commonActivities, id: \.self) { activity in
                                Label(activity, systemImage: ScheduleItem.icon(for: activity)).tag(activity)
                            }
                        }
                    }

                    Toggle("Custom activity", isOn: $customActivity.animation())
                }

                HouseholdEventPeopleSingleSection(
                    createdBy: $createdBy,
                    assignedTo: $assignedTo,
                    completedBy: $completedBy,
                    assigneeAccent: $assigneeAccent,
                    viewModel: viewModel,
                    showCompletedBy: isCompleted
                )

                Section("Description") {
                    TextField("Optional notes…", text: $eventDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                if item.quickLogKind == .mood {
                    Section("How were they feeling?") {
                        MoodLogPicker(selection: $mood)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        if let data = attachmentImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        PhotosPicker(selection: $attachmentPhotoItem, matching: .images) {
                            Label(attachmentImageData == nil ? "Add photo" : "Change photo", systemImage: "photo.on.rectangle.angled")
                        }
                        if attachmentImageData != nil {
                            Button("Remove photo", role: .destructive) {
                                attachmentImageData = nil
                                attachmentPhotoItem = nil
                            }
                        }
                    }
                } header: {
                    Text("Event photo")
                } footer: {
                    Text("Optional—attach a picture to this event.")
                }

                Section("When") {
                    DatePicker("Start", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("End time", isOn: $hasEndTime.animation())
                        .tint(Color.appPink)
                    if hasEndTime {
                        DatePicker("End", selection: $endTime, in: eventDate..., displayedComponents: .hourAndMinute)
                    }
                    Picker("Repeat", selection: $repeatRule) {
                        ForEach(RepeatRule.allCases) { rule in
                            Label(rule.rawValue, systemImage: rule.icon).tag(rule)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.scheduleItems.removeAll { $0.id == item.id }
                        viewModel.syncWidgetSchedule()
                        dismiss()
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                }
            }
            .onChange(of: attachmentPhotoItem) { _, pickerItem in
                Task { attachmentImageData = try? await pickerItem?.loadTransferable(type: Data.self) }
            }
            .onChange(of: customActivity) { _, isCustom in
                if isCustom {
                    activityName = ""
                } else if activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    activityName = commonActivities[0]
                }
            }
            .onChange(of: isCompleted) { _, newValue in
                if newValue {
                    let profile = UserProfileStorage.trimmedDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
                    if completedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !profile.isEmpty {
                        completedBy = profile
                    }
                } else {
                    completedBy = ""
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let pet = selectedPet else { return }
                        if let idx = viewModel.scheduleItems.firstIndex(where: { $0.id == item.id }) {
                            let profile = UserProfileStorage.trimmedDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedCompleted = completedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                            let resolvedCompletedBy = isCompleted
                                ? (trimmedCompleted.isEmpty ? profile : trimmedCompleted)
                                : ""
                            viewModel.scheduleItems[idx].pet = pet
                            viewModel.scheduleItems[idx].activityName = activityName
                            viewModel.scheduleItems[idx].description = eventDescription
                            viewModel.scheduleItems[idx].time = eventDate
                            viewModel.scheduleItems[idx].endTime = hasEndTime ? endTime : nil
                            viewModel.scheduleItems[idx].repeatRule = repeatRule
                            viewModel.scheduleItems[idx].quickLogKind = item.quickLogKind
                            viewModel.scheduleItems[idx].petMood = item.quickLogKind == .mood ? mood : nil
                            viewModel.scheduleItems[idx].attachmentImageData = attachmentImageData
                            viewModel.scheduleItems[idx].isCompleted = isCompleted
                            viewModel.scheduleItems[idx].createdByDisplayName = createdBy.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.scheduleItems[idx].assignedToDisplayName = assignedTo.trimmingCharacters(in: .whitespacesAndNewlines)
                            viewModel.scheduleItems[idx].completedByDisplayName = resolvedCompletedBy
                            viewModel.scheduleItems[idx].assigneeAccent = assigneeAccent
                        }
                        viewModel.syncWidgetSchedule()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(activityName.trimmingCharacters(in: .whitespaces).isEmpty || selectedPet == nil)
                }
            }
        }
    }
}

private struct FormCompletedCheckboxRow: View {
    @Binding var isCompleted: Bool

    var body: some View {
        HStack(alignment: .center) {
            Text("Completed")
            Spacer(minLength: 8)
            Button {
                withAnimation(.spring(duration: 0.25)) {
                    isCompleted.toggle()
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(AppTypography.completionControl)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isCompleted ? Color.complianceAccept : .primary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? "Completed" : "Mark as completed")
        }
    }
}
