import SwiftUI

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel
    var prefilledDate: Date? = nil

    @State private var selectedPet: Pet?
    @State private var activityName = ""
    @State private var eventDescription = ""
    @State private var eventDate = Date.now
    @State private var hasEndTime = false
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
    @State private var repeatRule: RepeatRule = .never
    @State private var customActivity = false

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
                                                    Circle()
                                                        .stroke(Color.appPink, lineWidth: 3)
                                                        .opacity(isSelected ? 1 : 0)
                                                }
                                                .scaleEffect(isSelected ? 1.08 : 1.0)
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
                        .onAppear {
                            if activityName.isEmpty { activityName = commonActivities[0] }
                        }
                    }
                }

                Section("Description") {
                    TextField("Optional notes…", text: $eventDescription, axis: .vertical)
                        .lineLimit(3...6)
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
            .onAppear {
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
                                pet: pet
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
