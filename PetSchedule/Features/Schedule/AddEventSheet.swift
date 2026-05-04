import PhotosUI
import SwiftUI
import UIKit

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel
    var prefilledDate: Date? = nil
    var prefilledPet: Pet? = nil
    /// Must match `commonActivities` for the preset picker.
    var prefilledPresetActivity: String? = nil

    @State private var selectedPet: Pet?
    @State private var activityName = ""
    @State private var eventDescription = ""
    @State private var eventDate = Date.now
    @State private var hasEndTime = false
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
    @State private var repeatRule: RepeatRule = .never
    @State private var customActivity = false
    @State private var attachmentPhotoItem: PhotosPickerItem?
    @State private var attachmentImageData: Data?

    private let commonActivities = ["Walk", "Feed", "Give water", "Sleep", "Play", "Vet", "Groom", "Give Medication"]

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
                    Toggle("Add end time", isOn: $hasEndTime.animation())
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
            }
            .onChange(of: attachmentPhotoItem) { _, pickerItem in
                Task { attachmentImageData = try? await pickerItem?.loadTransferable(type: Data.self) }
            }
            .onAppear {
                if selectedPet == nil {
                    if let prefilledPet {
                        selectedPet = prefilledPet
                    } else if viewModel.pets.count == 1 {
                        selectedPet = viewModel.pets.first
                    }
                }
                if let preset = prefilledPresetActivity, commonActivities.contains(preset) {
                    customActivity = false
                    activityName = preset
                } else if activityName.isEmpty {
                    activityName = commonActivities[0]
                }
                if let date = prefilledDate {
                    eventDate = date
                    endTime = Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        guard let pet = selectedPet, !activityName.isEmpty else { return }
                        viewModel.scheduleItems.append(
                            ScheduleItem(
                                time: eventDate,
                                endTime: hasEndTime ? endTime : nil,
                                activityName: activityName,
                                description: eventDescription,
                                repeatRule: repeatRule,
                                pet: pet,
                                attachmentImageData: attachmentImageData
                            )
                        )
                        viewModel.syncWidgetSchedule()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedPet == nil || activityName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddEventSheet(viewModel: HomeViewModel.preview)
}
