import SwiftUI
import PhotosUI
import UIKit

/// Segments on Add / Edit Log — **Mood** first (left).
private let quickLogTypeSegmentOrder: [QuickLogKind] = [.mood, .poo, .wee, .custom]

struct AddLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel
    var prefilledDate: Date? = nil
    /// Pre-select this pet when opening from Analytics or elsewhere.
    var prefilledPet: Pet? = nil

    @State private var selectedPet: Pet?
    @State private var logKind: QuickLogKind = .mood
    @State private var customTitle = ""
    @State private var detail = ""
    @State private var occurredAt = Date.now
    @State private var attachmentPhotoItem: PhotosPickerItem?
    @State private var attachmentImageData: Data?
    @State private var mood: PetMood = .okay
    @State private var createdBy: String = ""
    @State private var assignedTo: String = ""
    @State private var completedBy: String = ""
    @State private var assigneeAccent: ScheduleAssigneeAccent = .pink

    private var resolvedTitle: String {
        switch logKind {
        case .poo, .wee: return logKind.rawValue
        case .mood: return "Mood"
        case .custom: return customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var canSave: Bool {
        guard selectedPet != nil else { return false }
        if logKind == .custom { return !resolvedTitle.isEmpty }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
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
                    Text("Pet")
                }

                HouseholdEventPeopleSingleSection(
                    createdBy: $createdBy,
                    assignedTo: $assignedTo,
                    completedBy: $completedBy,
                    assigneeAccent: $assigneeAccent,
                    viewModel: viewModel,
                    showAssignedTo: false,
                    showCompletedBy: false
                )

                Section("Type") {
                    Picker("Log type", selection: $logKind) {
                        ForEach(quickLogTypeSegmentOrder) { kind in
                            Label(kind.rawValue, systemImage: kind.iconName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if logKind == .custom {
                        TextField("What happened?", text: $customTitle)
                    }
                }

                if logKind == .mood {
                    Section("How were they feeling?") {
                        MoodLogPicker(selection: $mood)
                    }
                }

                Section("Detail") {
                    TextField("Optional notes…", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
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
                            Label(attachmentImageData == nil ? "Add photo" : "Change photo", systemImage: "photo.badge.plus")
                        }
                        if attachmentImageData != nil {
                            Button("Remove photo", role: .destructive) {
                                attachmentImageData = nil
                                attachmentPhotoItem = nil
                            }
                        }
                    }
                }

                Section("When") {
                    DatePicker("Time", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .onAppear {
                if selectedPet == nil {
                    if let prefilledPet {
                        selectedPet = prefilledPet
                    } else if viewModel.pets.count == 1 {
                        selectedPet = viewModel.pets.first
                    }
                }
                if let date = prefilledDate {
                    occurredAt = Calendar.current.date(
                        bySettingHour: Calendar.current.component(.hour, from: .now),
                        minute: Calendar.current.component(.minute, from: .now),
                        second: 0,
                        of: date
                    ) ?? date
                }
                let trimmedProfile = UserProfileStorage.trimmedDisplayName()
                if createdBy.isEmpty, !trimmedProfile.isEmpty {
                    createdBy = trimmedProfile
                }
                if assignedTo.isEmpty, !trimmedProfile.isEmpty {
                    assignedTo = trimmedProfile
                }
            }
            .onChange(of: attachmentPhotoItem) { _, item in
                Task { attachmentImageData = try? await item?.loadTransferable(type: Data.self) }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let pet = selectedPet, canSave else { return }
                        let profile = UserProfileStorage.trimmedDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedCompleted = completedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                        let resolvedCompletedBy = trimmedCompleted.isEmpty ? profile : trimmedCompleted
                        viewModel.scheduleItems.append(
                            ScheduleItem(
                                time: occurredAt,
                                activityName: resolvedTitle,
                                description: detail,
                                repeatRule: .never,
                                pet: pet,
                                isCompleted: true,
                                quickLogKind: logKind,
                                petMood: logKind == .mood ? mood : nil,
                                attachmentImageData: attachmentImageData,
                                createdByDisplayName: createdBy.trimmingCharacters(in: .whitespacesAndNewlines),
                                assignedToDisplayName: assignedTo.trimmingCharacters(in: .whitespacesAndNewlines),
                                completedByDisplayName: resolvedCompletedBy,
                                assigneeAccent: assigneeAccent
                            )
                        )
                        viewModel.syncWidgetSchedule()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}

/// Edit screen for **+ Log** items — matches Add Log layout (not Edit Event).
struct EditLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel
    let item: ScheduleItem

    @State private var selectedPet: Pet?
    @State private var logKind: QuickLogKind
    @State private var customTitle: String
    @State private var detail: String
    @State private var occurredAt: Date
    @State private var attachmentPhotoItem: PhotosPickerItem?
    @State private var attachmentImageData: Data?
    @State private var mood: PetMood
    @State private var isCompleted: Bool
    @State private var createdBy: String
    @State private var assignedTo: String
    @State private var completedBy: String
    @State private var assigneeAccent: ScheduleAssigneeAccent

    private var resolvedTitle: String {
        switch logKind {
        case .poo, .wee: return logKind.rawValue
        case .mood: return "Mood"
        case .custom: return customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var canSave: Bool {
        guard selectedPet != nil else { return false }
        if logKind == .custom { return !resolvedTitle.isEmpty }
        return true
    }

    init(viewModel: HomeViewModel, item: ScheduleItem) {
        self.viewModel = viewModel
        self.item = item
        let kind = item.quickLogKind ?? .custom
        _selectedPet      = State(initialValue: item.pet)
        _logKind          = State(initialValue: kind)
        _customTitle      = State(initialValue: kind == .custom ? item.activityName : "")
        _detail           = State(initialValue: item.description)
        _occurredAt       = State(initialValue: item.time)
        _attachmentImageData = State(initialValue: item.attachmentImageData)
        _mood             = State(initialValue: item.petMood ?? .okay)
        _isCompleted      = State(initialValue: item.isCompleted)
        _createdBy         = State(initialValue: item.createdByDisplayName)
        _assignedTo        = State(initialValue: item.assignedToDisplayName)
        _completedBy       = State(initialValue: item.completedByDisplayName)
        _assigneeAccent    = State(initialValue: item.assigneeAccent)
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
                    Text("Pet")
                }

                HouseholdEventPeopleSingleSection(
                    createdBy: $createdBy,
                    assignedTo: $assignedTo,
                    completedBy: $completedBy,
                    assigneeAccent: $assigneeAccent,
                    viewModel: viewModel,
                    showAssignedTo: false,
                    showCompletedBy: isCompleted
                )

                Section("Type") {
                    Picker("Log type", selection: $logKind) {
                        ForEach(quickLogTypeSegmentOrder) { kind in
                            Label(kind.rawValue, systemImage: kind.iconName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if logKind == .custom {
                        TextField("What happened?", text: $customTitle)
                    }
                }

                if logKind == .mood {
                    Section("How were they feeling?") {
                        MoodLogPicker(selection: $mood)
                    }
                }

                Section("Detail") {
                    TextField("Optional notes…", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
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
                            Label(attachmentImageData == nil ? "Add photo" : "Change photo", systemImage: "photo.badge.plus")
                        }
                        if attachmentImageData != nil {
                            Button("Remove photo", role: .destructive) {
                                attachmentImageData = nil
                                attachmentPhotoItem = nil
                            }
                        }
                    }
                }

                Section("When") {
                    DatePicker("Time", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    Button(role: .destructive) {
                        viewModel.scheduleItems.removeAll { $0.id == item.id }
                        viewModel.syncWidgetSchedule()
                        dismiss()
                    } label: {
                        Label("Delete Log", systemImage: "trash")
                    }
                }
            }
            .onChange(of: attachmentPhotoItem) { _, pickerItem in
                Task { attachmentImageData = try? await pickerItem?.loadTransferable(type: Data.self) }
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
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let pet = selectedPet, canSave else { return }
                        if let idx = viewModel.scheduleItems.firstIndex(where: { $0.id == item.id }) {
                            let profile = UserProfileStorage.trimmedDisplayName().trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedCompleted = completedBy.trimmingCharacters(in: .whitespacesAndNewlines)
                            let resolvedCompletedBy: String = {
                                guard isCompleted else { return "" }
                                return trimmedCompleted.isEmpty ? profile : trimmedCompleted
                            }()
                            viewModel.scheduleItems[idx].pet = pet
                            viewModel.scheduleItems[idx].activityName = resolvedTitle
                            viewModel.scheduleItems[idx].description = detail
                            viewModel.scheduleItems[idx].time = occurredAt
                            viewModel.scheduleItems[idx].quickLogKind = logKind
                            viewModel.scheduleItems[idx].petMood = logKind == .mood ? mood : nil
                            viewModel.scheduleItems[idx].attachmentImageData = attachmentImageData
                            viewModel.scheduleItems[idx].repeatRule = .never
                            viewModel.scheduleItems[idx].endTime = nil
                            viewModel.scheduleItems[idx].isAllDay = false
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
                    .disabled(!canSave)
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

/// Horizontal chips for mood logging on **Log**.
struct MoodLogPicker: View {
    @Binding var selection: PetMood

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PetMood.allCases) { mood in
                    let selected = selection == mood
                    Button {
                        selection = mood
                    } label: {
                        VStack(spacing: 4) {
                            Text(mood.emoji)
                                .font(.title)
                            Text(mood.rawValue)
                                .font(AppTypography.micro)
                                .foregroundStyle(selected ? Color.appPink : .secondary)
                        }
                        .frame(width: 72)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected ? Color.appPink.opacity(0.14) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(selected ? Color.appPink : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.rawValue)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    AddLogSheet(viewModel: HomeViewModel.preview)
}
