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

    private let commonActivities = ["Walk", "Feed", "Give water", "Sleep", "Play", "Vet", "Groom", "Give Medication"]
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
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    Toggle("Custom activity", isOn: $customActivity.animation())

                    if customActivity {
                        TextField("Activity name", text: $activityName)
                    } else {
                        Picker("Activity", selection: $activityName) {
                            ForEach(commonActivities, id: \.self) { activity in
                                Label(activity, systemImage: ScheduleItem.icon(for: activity)).tag(activity)
                            }
                        }
                    }
                }

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
                    Text("Memory")
                } footer: {
                    Text("Optional—a snapshot tied to this event.")
                }

                Section("When") {
                    DatePicker("Start", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("End time", isOn: $hasEndTime.animation())
                        .tint(Color.appPink)
                    if hasEndTime {
                        DatePicker("End", selection: $endTime, in: eventDate..., displayedComponents: .hourAndMinute)
                    }
                }

                Section("Repeat") {
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
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let idx = viewModel.scheduleItems.firstIndex(where: { $0.id == item.id }) {
                            viewModel.scheduleItems[idx].activityName = activityName
                            viewModel.scheduleItems[idx].description = eventDescription
                            viewModel.scheduleItems[idx].time = eventDate
                            viewModel.scheduleItems[idx].endTime = hasEndTime ? endTime : nil
                            viewModel.scheduleItems[idx].repeatRule = repeatRule
                            viewModel.scheduleItems[idx].quickLogKind = item.quickLogKind
                            viewModel.scheduleItems[idx].petMood = item.quickLogKind == .mood ? mood : nil
                            viewModel.scheduleItems[idx].attachmentImageData = attachmentImageData
                        }
                        viewModel.syncWidgetSchedule()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(activityName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
