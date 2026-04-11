import SwiftUI

struct PetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var animalType: AnimalType
    @State private var dateOfBirth: Date
    @State private var hasDOB: Bool

    private let petID: UUID
    private let isNew: Bool
    let onSave: (Pet) -> Void

    init(pet: Pet?, onSave: @escaping (Pet) -> Void) {
        self.isNew = pet == nil
        self.onSave = onSave
        self.petID = pet?.id ?? UUID()
        _name        = State(initialValue: pet?.name ?? "")
        _animalType  = State(initialValue: pet?.animalType ?? .dog)
        _dateOfBirth = State(initialValue: pet?.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now)
        _hasDOB      = State(initialValue: pet?.dateOfBirth != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            PetAvatarView(pet: previewPet, size: 90)
                            Text(name.isEmpty ? "Your pet" : name)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        Spacer()
                    }
                }

                Section("Details") {
                    TextField("Name", text: $name)

                    Picker("Animal type", selection: $animalType) {
                        ForEach(AnimalType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                }

                Section("Birthday") {
                    Toggle("Add date of birth", isOn: $hasDOB.animation())
                    if hasDOB {
                        DatePicker(
                            "Date of birth",
                            selection: $dateOfBirth,
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(isNew ? "New Pet" : "Edit Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(Pet(
                            id: petID,
                            name: name.trimmingCharacters(in: .whitespaces),
                            animalType: animalType,
                            dateOfBirth: hasDOB ? dateOfBirth : nil
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var previewPet: Pet {
        Pet(id: petID, name: name.isEmpty ? "Pet" : name, animalType: animalType)
    }
}

#Preview {
    PetDetailSheet(pet: nil) { _ in }
}
