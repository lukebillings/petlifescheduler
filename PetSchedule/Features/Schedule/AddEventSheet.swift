import SwiftUI

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel

    @State private var selectedPet: Pet?
    @State private var activityName = ""
    @State private var eventDate = Date.now
    @State private var customActivity = false

    private let commonActivities = ["Walk", "Eat", "Sleep", "Play", "Vet", "Groom", "Medicine"]

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
                                Text(activity).tag(activity)
                            }
                        }
                        .onAppear {
                            if activityName.isEmpty { activityName = commonActivities[0] }
                        }
                    }
                }

                Section("When") {
                    DatePicker("Date & time", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
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
                            ScheduleItem(time: eventDate, activityName: activityName, pet: pet)
                        )
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
