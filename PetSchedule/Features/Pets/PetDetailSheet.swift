import SwiftUI
import PhotosUI
import Charts
import UniformTypeIdentifiers

struct PetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var animalType: AnimalType
    @State private var customAnimalType: String
    @State private var dateOfBirth: Date
    @State private var hasDOB: Bool
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

    // Documents
    @State private var showingDocumentPicker = false
    @State private var documentPickerError: String? = nil

    // Share with Vet
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var isGeneratingPDF = false

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
        _dateOfBirth      = State(initialValue: pet?.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now)
        _hasDOB           = State(initialValue: pet?.dateOfBirth != nil)
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
                }

                Section("Details") {
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
                }

                Section("Notes") {
                    TextField("Allergies, vet info, behaviour tips…", text: $notes, axis: .vertical)
                        .lineLimit(4...10)
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

                    // Share with Vet — generates a PDF of the pet's full profile
                    Button {
                        isGeneratingPDF = true
                        Task {
                            let currentPet = Pet(
                                id: petID, name: name, animalType: animalType,
                                customAnimalType: animalType == .other ? customAnimalType : nil,
                                dateOfBirth: hasDOB ? dateOfBirth : nil,
                                photoData: photoData,
                                weightHistory: weightHistory,
                                heightHistory: heightHistory,
                                notes: notes,
                                vetDetails: vetDetails,
                                documents: documents
                            )
                            let pdfData = PetPDFGenerator.generate(for: currentPet)
                            let url = FileManager.default.temporaryDirectory
                                .appendingPathComponent("\(currentPet.name.replacingOccurrences(of: " ", with: "_"))_HealthRecord.pdf")
                            try? pdfData.write(to: url)
                            shareItems = [url]
                            isGeneratingPDF = false
                            showingShareSheet = true
                        }
                    } label: {
                        HStack {
                            if isGeneratingPDF {
                                ProgressView().tint(Color.appPink)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color.appPink)
                            }
                            Text("Share with Vet")
                                .foregroundStyle(Color.appPink)
                                .font(.subheadline.bold())
                        }
                    }
                    .disabled(isGeneratingPDF)

                } header: {
                    Label("Vet Details", systemImage: "stethoscope")
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
                    Label("Documents", systemImage: "folder.fill")
                }

                Section("Weight") {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            TextField("0.0", text: $weightInput)
                                .keyboardType(.decimalPad)
                                .frame(maxWidth: .infinity)
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        DatePicker("", selection: $weightDate, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()

                        Button {
                            guard let kg = Double(weightInput.replacingOccurrences(of: ",", with: ".")),
                                  kg > 0 else { return }
                            withAnimation(.spring(duration: 0.3)) {
                                weightHistory.append(WeightEntry(date: weightDate, kg: kg))
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

                    if weightHistory.count >= 2 {
                        WeightChartView(entries: weightHistory)
                            .frame(height: 180)
                            .padding(.vertical, 8)
                    } else if !weightHistory.isEmpty {
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(Color.appPink)
                            Text("Latest: \(weightHistory.last!.kg, specifier: "%.1f") kg")
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
                            Text(String(format: "%+.1f kg since first log", diff))
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

                Section("Height") {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            TextField("0.0", text: $heightInput)
                                .keyboardType(.decimalPad)
                                .frame(maxWidth: .infinity)
                            Text("cm")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

                        DatePicker("", selection: $heightDate, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()

                        Button {
                            guard let cm = Double(heightInput.replacingOccurrences(of: ",", with: ".")),
                                  cm > 0 else { return }
                            withAnimation(.spring(duration: 0.3)) {
                                heightHistory.append(HeightEntry(date: heightDate, cm: cm))
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

                    if heightHistory.count >= 2 {
                        HeightChartView(entries: heightHistory)
                            .frame(height: 180)
                            .padding(.vertical, 8)
                    } else if !heightHistory.isEmpty {
                        HStack {
                            Image(systemName: "ruler.fill")
                                .foregroundStyle(Color.appPink)
                            Text("Latest: \(heightHistory.last!.cm, specifier: "%.1f") cm")
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
                            Text(String(format: "%+.1f cm since first log", diff))
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

                Section("Birthday") {
                    Toggle("Add date of birth", isOn: $hasDOB.animation())
                    if hasDOB {
                        DatePicker(
                            "Date of birth",
                            selection: $dateOfBirth,
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                        HStack {
                            Image(systemName: "birthday.cake.fill")
                                .foregroundStyle(Color.appPink)
                            Text(calculatedAge)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
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
                            dateOfBirth: hasDOB ? dateOfBirth : nil,
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
        Pet(id: petID, name: name.isEmpty ? "Pet" : name, animalType: animalType, customAnimalType: customAnimalType, photoData: photoData)
    }

    private func documentShareURL(for doc: PetDocument) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(doc.displayName)
        try? doc.data.write(to: url)
        return url
    }

    private var calculatedAge: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: dateOfBirth, to: .now)
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years > 0 {
            return months > 0
                ? "\(years) yr\(years == 1 ? "" : "s"), \(months) mo — \(ageLabel)"
                : "\(years) yr\(years == 1 ? "" : "s") old — \(ageLabel)"
        } else if months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") old — \(ageLabel)"
        }
        let days = components.day ?? 0
        return days > 0 ? "\(days) day\(days == 1 ? "" : "s") old" : "Born today"
    }

    private var ageLabel: String {
        let components = Calendar.current.dateComponents([.year], from: dateOfBirth, to: .now)
        let years = components.year ?? 0
        switch years {
        case 0..<2:   return "puppy/kitten"
        case 2..<7:   return "young adult"
        case 7..<11:  return "adult"
        default:      return "senior"
        }
    }
}

private struct WeightChartView: View {
    let entries: [WeightEntry]

    private var sorted: [WeightEntry] { entries.sorted { $0.date < $1.date } }
    private var minY: Double { (sorted.map(\.kg).min() ?? 0) * 0.92 }
    private var maxY: Double { (sorted.map(\.kg).max() ?? 1) * 1.08 }

    var body: some View {
        Chart(sorted) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("kg", entry.kg)
            )
            .foregroundStyle(Color.appPink)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", entry.date),
                yStart: .value("Min", minY),
                yEnd: .value("kg", entry.kg)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appPink.opacity(0.25), Color.appPink.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", entry.date),
                y: .value("kg", entry.kg)
            )
            .foregroundStyle(Color.appPink)
            .symbolSize(30)
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel {
                    if let kg = value.as(Double.self) {
                        Text("\(kg, specifier: "%.1f")")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

private struct HeightChartView: View {
    let entries: [HeightEntry]

    private var sorted: [HeightEntry] { entries.sorted { $0.date < $1.date } }
    private var minY: Double { (sorted.map(\.cm).min() ?? 0) * 0.92 }
    private var maxY: Double { (sorted.map(\.cm).max() ?? 1) * 1.08 }

    var body: some View {
        Chart(sorted) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("cm", entry.cm)
            )
            .foregroundStyle(Color.appPink)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", entry.date),
                yStart: .value("Min", minY),
                yEnd: .value("cm", entry.cm)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appPink.opacity(0.25), Color.appPink.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", entry.date),
                y: .value("cm", entry.cm)
            )
            .foregroundStyle(Color.appPink)
            .symbolSize(30)
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                AxisValueLabel {
                    if let cm = value.as(Double.self) {
                        Text("\(cm, specifier: "%.1f")")
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
