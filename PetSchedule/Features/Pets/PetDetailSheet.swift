import SwiftUI
import PhotosUI
import Charts
import UniformTypeIdentifiers

struct PetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var animalType: AnimalType
    @State private var customAnimalType: String
    @State private var dateOfBirth: Date?
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var weightHistory: [WeightEntry]
    @State private var weightInput: String = ""
    @State private var weightDate: Date = .now
    @State private var heightHistory: [HeightEntry]
    @State private var heightInput: String = ""
    @State private var heightDate: Date = .now
    @State private var notes: String
    @State private var vetDetails: VetDetails
    @State private var documents: [PetDocument]

    @AppStorage("weightUnit") private var weightUnitRaw = "kg"
    @AppStorage("heightUnit") private var heightUnitRaw = "cm"

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    private var heightUnit: HeightUnit { HeightUnit(rawValue: heightUnitRaw) ?? .cm }

    // Documents
    @State private var showingDocumentPicker = false
    @State private var documentPickerError: String? = nil

    // Export pet data (PDF)
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var exportPDFDocument: PetHealthPDFDocument?
    @State private var exportPDFFilename = "Pet_HealthRecord.pdf"
    @State private var showingPDFExporter = false
    private enum PDFExportActivity: Equatable {
        case idle
        case download
        case share
    }

    @State private var pdfExportActivity: PDFExportActivity = .idle

    private let petID: UUID
    private let isNew: Bool
    let onSave: (Pet) -> Void

    init(pet: Pet?, onSave: @escaping (Pet) -> Void) {
        self.isNew = pet == nil
        self.onSave = onSave
        self.petID = pet?.id ?? UUID()
        _name             = State(initialValue: pet?.name ?? "")
        _animalType       = State(initialValue: pet?.animalType ?? .dog)
        _customAnimalType = State(initialValue: pet?.customAnimalType ?? "")
        _dateOfBirth      = State(initialValue: pet?.dateOfBirth)
        _photoData        = State(initialValue: pet?.photoData)
        _weightHistory    = State(initialValue: pet?.weightHistory ?? [])
        _heightHistory    = State(initialValue: pet?.heightHistory ?? [])
        _notes            = State(initialValue: pet?.notes ?? "")
        _vetDetails       = State(initialValue: pet?.vetDetails ?? VetDetails())
        _documents        = State(initialValue: pet?.documents ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar preview
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                PetAvatarView(pet: previewPet, size: 90)
                                Circle()
                                    .fill(Color.appPink)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Image(systemName: "camera.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                            }
                        }
                        .onChange(of: photoItem) { _, item in
                            Task { photoData = try? await item?.loadTransferable(type: Data.self) }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    sectionHeader(
                        "Photo",
                        subtitle: "Optional picture so your pet is easy to recognise in lists and reminders."
                    )
                }

                Section {
                    TextField("Name", text: $name)

                    Picker("Animal type", selection: $animalType) {
                        ForEach(AnimalType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }

                    if animalType == .other {
                        TextField("e.g. Guinea pig, Gecko…", text: $customAnimalType)
                    }
                } header: {
                    sectionHeader(
                        "Details",
                        subtitle: "Your pet's name and type—the basics used everywhere in the app."
                    )
                }

                Section {
                    TextField("Allergies, vet info, behaviour tips…", text: $notes, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    sectionHeader(
                        "Notes",
                        subtitle: "Free-form notes—allergies, behaviour, care tips, or anything else to remember."
                    )
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "cross.case.fill")
                            .foregroundStyle(Color.appPink)
                            .frame(width: 22)
                        TextField("Organisation", text: $vetDetails.organisation)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Color.appPink)
                            .frame(width: 22)
                        TextField("Address", text: $vetDetails.address)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(Color.appPink)
                            .frame(width: 22)
                        TextField("Phone", text: $vetDetails.phone)
                            .keyboardType(.phonePad)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Color.appPink)
                            .frame(width: 22)
                        TextField("Email", text: $vetDetails.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    if !vetDetails.phone.isEmpty {
                        Button {
                            let tel = vetDetails.phone.filter { $0.isNumber || $0 == "+" }
                            if let url = URL(string: "tel://\(tel)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Call Vet", systemImage: "phone.arrow.up.right")
                                .foregroundStyle(Color.appPink)
                                .font(.subheadline.bold())
                        }
                    }
                    if !vetDetails.email.isEmpty {
                        Button {
                            if let url = URL(string: "mailto:\(vetDetails.email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("Email Vet", systemImage: "envelope.arrow.triangle.branch")
                                .foregroundStyle(Color.appPink)
                                .font(.subheadline.bold())
                        }
                    }

                    Button {
                        copyVetDetailsToClipboard()
                    } label: {
                        Label("Copy Vet Details to Clipboard", systemImage: "doc.on.doc")
                            .foregroundStyle(Color.appPink)
                            .font(.subheadline.bold())
                    }
                    .disabled(vetDetails.organisation.isEmpty && vetDetails.phone.isEmpty && vetDetails.email.isEmpty)

                } header: {
                    sectionHeaderWithLabel(
                        title: "Vet Details",
                        systemImage: "stethoscope",
                        subtitle: "Your clinic's name, address, phone, and email for quick contact."
                    )
                }

                // ── Documents ──────────────────────────────────────────────
                Section {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Add Document from Files", systemImage: "icloud.and.arrow.up")
                            .foregroundStyle(Color.appPink)
                            .font(.subheadline.bold())
                    }

                    ForEach(documents) { doc in
                        HStack(spacing: 12) {
                            Image(systemName: doc.iconName)
                                .font(.title3)
                                .foregroundStyle(Color.appPink)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text("\(doc.sizeString) · \(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Preview / share button
                            ShareLink(item: documentShareURL(for: doc), preview: SharePreview(doc.displayName)) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation { documents.removeAll { $0.id == doc.id } }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    if documents.isEmpty {
                        Text("No documents yet. Tap above to import from iCloud Drive or your device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    sectionHeaderWithLabel(
                        title: "Documents",
                        systemImage: "folder.fill",
                        subtitle: "Attach files such as lab results, vaccination records, or insurance—kept on this device."
                    )
                }

                Section {
                    Button {
                        downloadPetDataAsPDF()
                    } label: {
                        HStack {
                            if pdfExportActivity == .download {
                                ProgressView().tint(Color.appPink)
                            } else {
                                Image(systemName: "arrow.down.doc")
                                    .foregroundStyle(Color.appPink)
                            }
                            Text("Download data as PDF")
                                .foregroundStyle(Color.appPink)
                                .font(.subheadline.bold())
                        }
                    }
                    .disabled(pdfExportActivity != .idle)

                    Button {
                        sharePetDataWithVet()
                    } label: {
                        HStack {
                            if pdfExportActivity == .share {
                                ProgressView().tint(Color.appPink)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color.appPink)
                            }
                            Text("Share pet data with vet")
                                .foregroundStyle(Color.appPink)
                                .font(.subheadline.bold())
                        }
                    }
                    .disabled(pdfExportActivity != .idle)
                } header: {
                    sectionHeaderWithLabel(
                        title: "Export Pet Data",
                        systemImage: "square.and.arrow.up.on.square",
                        subtitle: "Save a health summary PDF to Files, or share it with your vet from the share sheet."
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a new weight reading")
                                .font(.subheadline.weight(.semibold))
                            Text("Enter the weight and the date it was taken, then tap + to save.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    TextField("0.0", text: $weightInput)
                                        .keyboardType(.decimalPad)
                                        .frame(maxWidth: .infinity)
                                    Text(weightUnit.label)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                                DatePicker("", selection: $weightDate, in: ...Date.now, displayedComponents: .date)
                                    .labelsHidden()

                                Button {
                                    guard let val = Double(weightInput.replacingOccurrences(of: ",", with: ".")),
                                          val > 0 else { return }
                                    withAnimation(.spring(duration: 0.3)) {
                                        weightHistory.append(WeightEntry(date: weightDate, kg: weightUnit.toKg(val)))
                                        weightHistory.sort { $0.date < $1.date }
                                    }
                                    weightInput = ""
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.appPink)
                                }
                                .buttonStyle(.plain)
                                .disabled(weightInput.isEmpty)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                        if !weightHistory.isEmpty {
                            Divider()
                        }

                    if weightHistory.count >= 2 {
                        WeightChartView(entries: weightHistory, unit: weightUnit)
                            .frame(height: 180)
                            .padding(.vertical, 8)

                        weightReadingsList(entries: weightHistory, unit: weightUnit)
                    } else if !weightHistory.isEmpty {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(Color.appPink)
                            Text("Latest: \(weightUnit.formatValue(weightHistory.last!.kg))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation { weightHistory.removeAll() }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if weightHistory.count >= 2 {
                        let sorted = weightHistory.sorted { $0.date < $1.date }
                        let diff = sorted.last!.kg - sorted.first!.kg
                        HStack(spacing: 6) {
                            Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(diff >= 0 ? .orange : .green)
                                .font(.caption.bold())
                            Text("\(weightUnit.formatChange(diff)) since first log")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation { weightHistory.removeAll() }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    }
                } header: {
                    sectionHeader(
                        "Weight",
                        subtitle: "Enter a value and date to build a history—charts appear after two or more entries."
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a new height reading")
                                .font(.subheadline.weight(.semibold))
                            Text("Enter the height and the date it was taken, then tap + to save.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                HStack(spacing: 6) {
                                    TextField("0.0", text: $heightInput)
                                        .keyboardType(.decimalPad)
                                        .frame(maxWidth: .infinity)
                                    Text(heightUnit.inputLabel)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                                DatePicker("", selection: $heightDate, in: ...Date.now, displayedComponents: .date)
                                    .labelsHidden()

                                Button {
                                    guard let val = Double(heightInput.replacingOccurrences(of: ",", with: ".")),
                                          val > 0 else { return }
                                    withAnimation(.spring(duration: 0.3)) {
                                        heightHistory.append(HeightEntry(date: heightDate, cm: heightUnit.toCm(val)))
                                        heightHistory.sort { $0.date < $1.date }
                                    }
                                    heightInput = ""
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.appPink)
                                }
                                .buttonStyle(.plain)
                                .disabled(heightInput.isEmpty)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                        if !heightHistory.isEmpty {
                            Divider()
                        }

                    if heightHistory.count >= 2 {
                        HeightChartView(entries: heightHistory, unit: heightUnit)
                            .frame(height: 180)
                            .padding(.vertical, 8)

                        heightReadingsList(entries: heightHistory, unit: heightUnit)
                    } else if !heightHistory.isEmpty {
                        HStack {
                            Image(systemName: "ruler.fill")
                                .foregroundStyle(Color.appPink)
                            Text("Latest: \(heightUnit.formatValue(heightHistory.last!.cm))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation { heightHistory.removeAll() }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if heightHistory.count >= 2 {
                        let sorted = heightHistory.sorted { $0.date < $1.date }
                        let diff = sorted.last!.cm - sorted.first!.cm
                        HStack(spacing: 6) {
                            Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(diff >= 0 ? .orange : .green)
                                .font(.caption.bold())
                            Text("\(heightUnit.formatChange(diff)) since first log")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                withAnimation { heightHistory.removeAll() }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    }
                } header: {
                    sectionHeader(
                        "Height",
                        subtitle: "Measure and log with a date to track growth or size changes over time."
                    )
                }

                Section {
                    if let dob = dateOfBirth {
                        DatePicker(
                            "Date of birth",
                            selection: Binding(
                                get: { dob },
                                set: { dateOfBirth = $0 }
                            ),
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                        if let age = petAgeDescription {
                            Text(age)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button("Remove date of birth", role: .destructive) {
                            dateOfBirth = nil
                        }
                    } else {
                        Button {
                            dateOfBirth = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
                        } label: {
                            HStack {
                                Text("Date of birth")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("—")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    sectionHeader(
                        "Birthday",
                        subtitle: "Optional—used for birthday reminders on your schedule when you add a date."
                    )
                }
            }
            .navigationTitle(isNew ? "New Pet" : name.trimmingCharacters(in: .whitespaces).isEmpty ? "Edit Pet" : name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { docs in
                    documents.append(contentsOf: docs)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if !shareItems.isEmpty {
                    ShareSheetView(activityItems: shareItems)
                }
            }
            .fileExporter(
                isPresented: $showingPDFExporter,
                document: exportPDFDocument,
                contentType: .pdf,
                defaultFilename: exportPDFFilename
            ) { result in
                exportPDFDocument = nil
                if case .success = result {
                    HapticManager.notification(.success)
                }
            }
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
                            customAnimalType: animalType == .other ? customAnimalType.trimmingCharacters(in: .whitespaces) : nil,
                            dateOfBirth: dateOfBirth,
                            photoData: photoData,
                            weightHistory: weightHistory,
                            heightHistory: heightHistory,
                            notes: notes,
                            vetDetails: vetDetails,
                            documents: documents
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                              (animalType == .other && customAnimalType.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
        }
    }

    private var previewPet: Pet {
        Pet(id: petID, name: name.isEmpty ? "Pet" : name, animalType: animalType, customAnimalType: customAnimalType, dateOfBirth: dateOfBirth, photoData: photoData)
    }

    /// Age string derived from the current birthday fields (updates as the user changes the date).
    private var petAgeDescription: String? {
        Pet(
            id: petID,
            name: "Pet",
            animalType: animalType,
            customAnimalType: animalType == .other ? customAnimalType : nil,
            dateOfBirth: dateOfBirth
        ).age
    }

    @ViewBuilder
    private func weightReadingsList(entries: [WeightEntry], unit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Date")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(unit.label)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(unit.formatValue(entry.kg))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func heightReadingsList(entries: [HeightEntry], unit: HeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Date")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(unit.inputLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(unit.formatValue(entry.cm))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func petSnapshotForPDF() -> Pet {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let displayName = trimmed.isEmpty ? "Pet" : trimmed
        return Pet(
            id: petID,
            name: displayName,
            animalType: animalType,
            customAnimalType: animalType == .other ? customAnimalType.trimmingCharacters(in: .whitespaces) : nil,
            dateOfBirth: dateOfBirth,
            photoData: photoData,
            weightHistory: weightHistory,
            heightHistory: heightHistory,
            notes: notes,
            vetDetails: vetDetails,
            documents: documents
        )
    }

    private func healthRecordPDFFilename(for pet: Pet) -> String {
        "\(pet.name.replacingOccurrences(of: " ", with: "_"))_HealthRecord.pdf"
    }

    private func downloadPetDataAsPDF() {
        pdfExportActivity = .download
        Task { @MainActor in
            let pet = petSnapshotForPDF()
            let data = PetPDFGenerator.generate(for: pet)
            exportPDFFilename = healthRecordPDFFilename(for: pet)
            exportPDFDocument = PetHealthPDFDocument(pdfData: data)
            pdfExportActivity = .idle
            showingPDFExporter = true
        }
    }

    private func sharePetDataWithVet() {
        pdfExportActivity = .share
        Task { @MainActor in
            let pet = petSnapshotForPDF()
            let pdfData = PetPDFGenerator.generate(for: pet)
            let filename = healthRecordPDFFilename(for: pet)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try? pdfData.write(to: url)
            shareItems = [url]
            pdfExportActivity = .idle
            showingShareSheet = true
        }
    }

    private func copyVetDetailsToClipboard() {
        var lines: [String] = []
        if !vetDetails.organisation.isEmpty {
            lines.append("Vet Name: \(vetDetails.organisation)")
        }
        if !vetDetails.phone.isEmpty {
            lines.append("Phone: \(vetDetails.phone)")
        }
        if !vetDetails.email.isEmpty {
            lines.append("Email: \(vetDetails.email)")
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        HapticManager.notification(.success)
    }

    private func documentShareURL(for doc: PetDocument) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(doc.displayName)
        try? doc.data.write(to: url)
        return url
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(nil)
    }

    @ViewBuilder
    private func sectionHeaderWithLabel(title: String, systemImage: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(nil)
    }

}

private struct PetHealthPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var pdfData: Data

    init(pdfData: Data) {
        self.pdfData = pdfData
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        pdfData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: pdfData)
    }
}

private struct WeightChartView: View {
    let entries: [WeightEntry]
    let unit: WeightUnit

    private var sorted: [WeightEntry] { entries.sorted { $0.date < $1.date } }
    private var displayValues: [Double] { sorted.map { unit.displayValue(fromKg: $0.kg) } }
    private var minY: Double { (displayValues.min() ?? 0) * 0.92 }
    private var maxY: Double { (displayValues.max() ?? 1) * 1.08 }

    var body: some View {
        Chart(sorted) { entry in
            let y = unit.displayValue(fromKg: entry.kg)
            LineMark(
                x: .value("Date", entry.date),
                y: .value(unit.label, y)
            )
            .foregroundStyle(Color.appPink)
            .interpolationMethod(.linear)

            AreaMark(
                x: .value("Date", entry.date),
                yStart: .value("Min", minY),
                yEnd: .value(unit.label, y)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appPink.opacity(0.25), Color.appPink.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.linear)

            PointMark(
                x: .value("Date", entry.date),
                y: .value(unit.label, y)
            )
            .foregroundStyle(Color.appPink)
            .symbolSize(30)
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: sorted.map(\.date)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(d, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

private struct HeightChartView: View {
    let entries: [HeightEntry]
    let unit: HeightUnit

    private var sorted: [HeightEntry] { entries.sorted { $0.date < $1.date } }
    private var displayValues: [Double] { sorted.map { unit.displayValue(fromCm: $0.cm) } }
    private var minY: Double { (displayValues.min() ?? 0) * 0.92 }
    private var maxY: Double { (displayValues.max() ?? 1) * 1.08 }

    var body: some View {
        Chart(sorted) { entry in
            let y = unit.displayValue(fromCm: entry.cm)
            LineMark(
                x: .value("Date", entry.date),
                y: .value(unit.inputLabel, y)
            )
            .foregroundStyle(Color.appPink)
            .interpolationMethod(.linear)

            AreaMark(
                x: .value("Date", entry.date),
                yStart: .value("Min", minY),
                yEnd: .value(unit.inputLabel, y)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appPink.opacity(0.25), Color.appPink.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.linear)

            PointMark(
                x: .value("Date", entry.date),
                y: .value(unit.inputLabel, y)
            )
            .foregroundStyle(Color.appPink)
            .symbolSize(30)
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: sorted.map(\.date)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text(d, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.1f", v))
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

// MARK: - Document Picker (UIDocumentPickerViewController wrapper)

private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([PetDocument]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .image, .text, .spreadsheet,
                               UTType("com.microsoft.word.doc") ?? .data,
                               UTType("org.openxmlformats.wordprocessingml.document") ?? .data]
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        vc.allowsMultipleSelection = true
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([PetDocument]) -> Void
        init(onPick: @escaping ([PetDocument]) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let docs: [PetDocument] = urls.compactMap { url in
                guard url.startAccessingSecurityScopedResource(),
                      let data = try? Data(contentsOf: url) else {
                    url.stopAccessingSecurityScopedResource()
                    return nil
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let ext = url.pathExtension
                let nameBase = url.deletingPathExtension().lastPathComponent
                return PetDocument(name: nameBase, data: data, fileExtension: ext)
            }
            onPick(docs)
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PetDetailSheet(pet: nil) { _ in }
}
