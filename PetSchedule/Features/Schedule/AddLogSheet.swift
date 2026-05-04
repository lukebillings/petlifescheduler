import SwiftUI
import PhotosUI
import UIKit

/// Segments on Add / Edit Log — **Mood** first (left).
private let quickLogTypeSegmentOrder: [QuickLogKind] = [.mood, .poo, .wee, .custom]

struct AddLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel
    var prefilledDate: Date? = nil

    @State private var selectedPet: Pet?
    @State private var logKind: QuickLogKind = .poo
    @State private var customTitle = ""
    @State private var detail = ""
    @State private var occurredAt = Date.now
    @State private var attachmentPhotoItem: PhotosPickerItem?
    @State private var attachmentImageData: Data?
    @State private var mood: PetMood = .okay

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
                Section("Pet") {
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
                                                .font(.caption.bold())
                                                .foregroundStyle(isSelected ? Color.appPink : Color.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }

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
                if let date = prefilledDate {
                    occurredAt = Calendar.current.date(
                        bySettingHour: Calendar.current.component(.hour, from: .now),
                        minute: Calendar.current.component(.minute, from: .now),
                        second: 0,
                        of: date
                    ) ?? date
                }
            }
            .onChange(of: attachmentPhotoItem) { _, item in
                Task { attachmentImageData = try? await item?.loadTransferable(type: Data.self) }
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let pet = selectedPet, canSave else { return }
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
                                attachmentImageData: attachmentImageData
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
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pet") {
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
                                                .font(.caption.bold())
                                                .foregroundStyle(isSelected ? Color.appPink : Color.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }

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
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let pet = selectedPet, canSave else { return }
                        if let idx = viewModel.scheduleItems.firstIndex(where: { $0.id == item.id }) {
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
                                .font(.caption2.bold())
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
