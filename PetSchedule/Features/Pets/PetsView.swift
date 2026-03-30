import PhotosUI
import SwiftUI
import UIKit

struct PetsView: View {
    @Bindable var viewModel: PetsViewModel
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pets.isEmpty {
                    ContentUnavailableView(
                        "No pets yet",
                        systemImage: "pawprint.fill",
                        description: Text("Add a profile with name, species, photo, birthday, size, and notes.")
                    )
                } else {
                    List {
                        ForEach(viewModel.pets) { pet in
                            NavigationLink {
                                PetDetailView(petId: pet.id, viewModel: viewModel)
                            } label: {
                                PetRowLabel(pet: pet)
                            }
                        }
                        .onDelete(perform: deleteAtOffsets)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(petsBackground)
            .navigationTitle("Pets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        showCreate = true
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                NavigationStack {
                    PetProfileEditorView(mode: .create, viewModel: viewModel)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func deleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            let id = viewModel.pets[index].id
            viewModel.delete(id: id)
        }
    }

    private var petsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.93, green: 0.96, blue: 0.99),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Row

private struct PetRowLabel: View {
    let pet: PetProfile

    var body: some View {
        HStack(spacing: 14) {
            PetPhotoView(data: pet.photoData, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name.isEmpty ? "Unnamed" : pet.name)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !pet.animalSpecies.isEmpty { parts.append(pet.animalSpecies) }
        if !pet.breed.isEmpty { parts.append(pet.breed) }
        if let dob = pet.dateOfBirth {
            let f = DateFormatter()
            f.dateStyle = .medium
            parts.append("b. \(f.string(from: dob))")
        }
        return parts.isEmpty ? "Tap to add details" : parts.joined(separator: " · ")
    }
}

// MARK: - Detail

private struct PetDetailView: View {
    let petId: UUID
    var viewModel: PetsViewModel

    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var exportShareItems: ExportSharePayload?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let pet = viewModel.profile(id: petId) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Spacer()
                            PetPhotoView(data: pet.photoData, size: 140)
                            Spacer()
                        }

                        detailSection("Basics") {
                            detailLine("Name", pet.name.isEmpty ? "—" : pet.name)
                            detailLine("Animal", pet.animalSpecies.isEmpty ? "—" : pet.animalSpecies)
                            detailLine("Breed", pet.breed.isEmpty ? "—" : pet.breed)
                            detailLine("Date of birth", formattedDOB(pet.dateOfBirth))
                        }

                        detailSection("Size") {
                            detailLine("Height", formatCm(pet.heightCm))
                            detailLine("Weight", formatKg(pet.weightKg))
                        }

                        detailSection("Insurance") {
                            detailMultiline(pet.insuranceDetails)
                        }

                        detailSection("Vet") {
                            detailMultiline(pet.vetDetails)
                        }

                        detailSection("Groomers") {
                            detailMultiline(pet.groomerDetails)
                        }

                        detailSection("Notes") {
                            Text(pet.notes.isEmpty ? "—" : pet.notes)
                                .font(.body)
                                .foregroundStyle(pet.notes.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            exportShareItems = Self.makeCSVSharePayload(for: pet)
                        } label: {
                            Label("Export pet data to CSV", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                .background(petsBackground)
                .navigationTitle(pet.name.isEmpty ? "Pet" : pet.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit") { showEdit = true }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                }
                .confirmationDialog(
                    "Delete \(pet.name.isEmpty ? "this pet" : pet.name)?",
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        viewModel.delete(id: petId)
                        dismiss()
                    }
                }
                .sheet(isPresented: $showEdit) {
                    NavigationStack {
                        PetProfileEditorView(mode: .edit(pet), viewModel: viewModel)
                    }
                }
                .sheet(item: $exportShareItems) { payload in
                    ActivityView(activityItems: [payload.fileURL])
                        .onDisappear {
                            try? FileManager.default.removeItem(at: payload.fileURL)
                        }
                }
            } else {
                ContentUnavailableView("Pet removed", systemImage: "pawprint")
                    .onAppear { dismiss() }
            }
        }
    }

    private func formattedDOB(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }

    private func detailSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
            )
        }
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
        }
    }

    private func detailMultiline(_ text: String?) -> some View {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Text(trimmed.isEmpty ? "—" : trimmed)
            .font(.body)
            .foregroundStyle(trimmed.isEmpty ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatCm(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f cm", value)
    }

    private func formatKg(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f kg", value)
    }

    private var petsBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.93, green: 0.96, blue: 0.99),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private static func makeCSVSharePayload(for pet: PetProfile) -> ExportSharePayload? {
        let csv = pet.csvExportDocument()
        guard let data = csv.data(using: .utf8) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(pet.suggestedCSVFileName(), isDirectory: false)
        do {
            try data.write(to: url, options: .atomic)
            return ExportSharePayload(fileURL: url)
        } catch {
            return nil
        }
    }
}

// MARK: - CSV share sheet

private struct ExportSharePayload: Identifiable {
    let id = UUID()
    let fileURL: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Photo

private struct PetPhotoView: View {
    let data: Data?
    var size: CGFloat = 96

    var body: some View {
        Group {
            if let data, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.15)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}

// MARK: - Editor

private struct PetProfileEditorView: View {
    enum Mode {
        case create
        case edit(PetProfile)
    }

    let mode: Mode
    var viewModel: PetsViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var draft: PetProfile
    @State private var heightText: String
    @State private var weightText: String
    @State private var pickerItem: PhotosPickerItem?

    init(mode: Mode, viewModel: PetsViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        let initial: PetProfile
        switch mode {
        case .create:
            initial = PetProfile()
        case .edit(let pet):
            initial = pet
        }
        _draft = State(initialValue: initial)
        _heightText = State(initialValue: Self.formatOptionalDouble(initial.heightCm))
        _weightText = State(initialValue: Self.formatOptionalDouble(initial.weightKg))
    }

    private var isSaveDisabled: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    PetPhotoView(data: draft.photoData, size: 120)
                    Spacer()
                }
                .listRowBackground(Color.clear)

                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose photo", systemImage: "photo.on.rectangle.angled")
                }
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await MainActor.run { draft.photoData = data }
                        }
                    }
                }

                if draft.photoData != nil {
                    Button("Remove photo", role: .destructive) {
                        draft.photoData = nil
                        pickerItem = nil
                    }
                }
            } header: {
                Text("Photo")
            }

            Section {
                TextField("Name", text: $draft.name)
                    .textContentType(.nickname)
                TextField("Animal (e.g. Dog, Cat, Rabbit)", text: $draft.animalSpecies)
                TextField("Breed (optional)", text: $draft.breed)
                Toggle("Birthday on file", isOn: Binding(
                    get: { draft.dateOfBirth != nil },
                    set: { known in
                        if known {
                            draft.dateOfBirth = draft.dateOfBirth ?? Date()
                        } else {
                            draft.dateOfBirth = nil
                        }
                    }
                ))
                if draft.dateOfBirth != nil {
                    DatePicker(
                        "Date of birth",
                        selection: Binding(
                            get: { draft.dateOfBirth ?? Date() },
                            set: { draft.dateOfBirth = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            } header: {
                Text("Basics")
            }

            Section {
                TextField("Height (cm)", text: $heightText)
                    .keyboardType(.decimalPad)
                TextField("Weight (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
            } header: {
                Text("Measurements")
            } footer: {
                Text("Leave blank if you do not track height or weight yet.")
            }

            Section {
                TextField("Insurance", text: optionalStringBinding(\.insuranceDetails), axis: .vertical)
                    .lineLimit(3 ... 12)
            } header: {
                Text("Insurance")
            } footer: {
                Text("Provider, policy number, renewal date, claims contact.")
            }

            Section {
                TextField("Vet", text: optionalStringBinding(\.vetDetails), axis: .vertical)
                    .lineLimit(3 ... 12)
            } header: {
                Text("Vet")
            } footer: {
                Text("Clinic, veterinarian, phone, address.")
            }

            Section {
                TextField("Groomers", text: optionalStringBinding(\.groomerDetails), axis: .vertical)
                    .lineLimit(3 ... 12)
            } header: {
                Text("Groomers")
            } footer: {
                Text("Salon or mobile groomer, contact, notes.")
            }

            Section {
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(3 ... 8)
            } header: {
                Text("Notes")
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    applyMeasurementsFromText()
                    viewModel.upsert(draft)
                    dismiss()
                }
                .disabled(isSaveDisabled)
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: "New pet"
        case .edit: "Edit pet"
        }
    }

    private func applyMeasurementsFromText() {
        draft.heightCm = Self.parseDouble(heightText)
        draft.weightKg = Self.parseDouble(weightText)
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<PetProfile, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draft[keyPath: keyPath] = t.isEmpty ? nil : t
            }
        )
    }

    private static func formatOptionalDouble(_ value: Double?) -> String {
        guard let value else { return "" }
        let formatted = String(format: "%g", value)
        return formatted
    }

    private static func parseDouble(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }
}

#Preview("Pets") {
    PetsView(viewModel: PetsViewModel())
}
