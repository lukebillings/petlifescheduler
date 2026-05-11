import SwiftUI
import PhotosUI
import Charts
import UniformTypeIdentifiers
import UIKit

struct PetDetailSheet: View {
    /// Quick-jump targets for the section pill bar (matches `.id` on each `Section` below).
    private enum JumpSection: String, CaseIterable, Hashable {
        case age, photo, details, notes, vet, documents, export, weight, height, birthday, data

        var pillTitle: String {
            switch self {
            case .age: return "Age"
            case .photo: return "Photo"
            case .details: return "Details"
            case .notes: return "Notes"
            case .vet: return "Vet"
            case .documents: return "Documents"
            case .export: return "Export"
            case .weight: return "Weight"
            case .height: return "Height"
            case .birthday: return "Birthday"
            case .data: return "Pet data"
            }
        }

        func isVisible(isNewPet: Bool, previewPet: Pet) -> Bool {
            switch self {
            case .age: return previewPet.ageYearsAndDaysSummary != nil
            case .data: return !isNewPet
            default: return true
            }
        }

        var pillSymbol: String {
            switch self {
            case .age: return "hourglass.bottomhalf.filled"
            case .photo: return "camera.fill"
            case .details: return "list.bullet.rectangle"
            case .notes: return "note.text"
            case .vet: return "cross.case.fill"
            case .documents: return "doc.fill"
            case .export: return "square.and.arrow.up"
            case .weight: return "scalemass.fill"
            case .height: return "ruler.fill"
            case .birthday: return "gift.fill"
            case .data: return "chart.bar.doc.horizontal"
            }
        }
    }

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
    @State private var weightEntryPhotoItem: PhotosPickerItem?
    @State private var weightEntryImageData: Data?
    @State private var heightHistory: [HeightEntry]
    @State private var heightInput: String = ""
    @State private var heightDate: Date = .now
    @State private var heightEntryPhotoItem: PhotosPickerItem?
    @State private var heightEntryImageData: Data?
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
    @State private var showClearPetDataConfirm = false
    @State private var showRemovePetConfirm = false
    @State private var showVetDetailsCopiedToast = false
    @State private var selectedJumpSection: JumpSection?

    private let petID: UUID
    private let isNew: Bool
    let onSave: (Pet) -> Void
    /// When set, shows “Remove pet from My Pets” and calls this before dismiss (e.g. `viewModel.deletePet`).
    var onRemovePet: (() -> Void)?

    init(pet: Pet?, onSave: @escaping (Pet) -> Void, onRemovePet: (() -> Void)? = nil) {
        self.isNew = pet == nil
        self.onSave = onSave
        self.onRemovePet = onRemovePet
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
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    jumpSectionPillBar(proxy: proxy)

                    Form {
                if let ageLine = previewPet.ageYearsAndDaysSummary {
                    Section {
                        HStack(alignment: .center, spacing: 14) {
                            Image(systemName: "hourglass.bottomhalf.filled")
                                .font(AppTypography.sectionHeading)
                                .foregroundStyle(Color.appPink)
                                .frame(width: 36, height: 36)
                                .background(Color.appPink.opacity(0.12), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Age")
                                    .font(AppTypography.compactControl)
                                    .foregroundStyle(.secondary)
                                Text(ageLine)
                                    .font(AppTypography.sectionHeading)
                                    .foregroundStyle(.primary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .id(JumpSection.age.rawValue)
                }

                Section {
                    Picker("Animal type", selection: $animalType) {
                        ForEach(AnimalType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }

                    TextField("Name", text: $name)

                    if animalType == .other {
                        TextField("e.g. Guinea pig, Gecko…", text: $customAnimalType)
                    }
                } header: {
                    sectionHeader(
                        "Details",
                        subtitle: "Your pet's name and type—the basics used everywhere in the app."
                    )
                }
                .id(JumpSection.details.rawValue)

                // Profile cover photo
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            petProfileCoverImage

                            Circle()
                                .fill(Color.appPink)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                .overlay {
                                    Image(systemName: "camera.fill")
                                        .font(AppTypography.primaryLabel)
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                        }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: photoItem) { _, item in
                        Task { photoData = try? await item?.loadTransferable(type: Data.self) }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    sectionHeader(
                        "Photo",
                        subtitle: "Optional picture so your pet is easy to recognise in lists and reminders."
                    )
                }
                .id(JumpSection.photo.rawValue)

                Section {
                    TextField("Allergies, vet info, behaviour tips…", text: $notes, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    sectionHeader(
                        "Notes",
                        subtitle: "Free-form notes—allergies, behaviour, care tips, or anything else to remember."
                    )
                }
                .id(JumpSection.notes.rawValue)

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
                                .font(AppTypography.secondaryEmphasis)
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
                                .font(AppTypography.secondaryEmphasis)
                        }
                    }

                    Button {
                        copyVetDetailsToClipboard()
                    } label: {
                        Label("Copy Vet Details to Clipboard", systemImage: "doc.on.doc")
                            .foregroundStyle(Color.appPink)
                            .font(AppTypography.secondaryEmphasis)
                    }
                    .disabled(vetDetails.organisation.isEmpty && vetDetails.phone.isEmpty && vetDetails.email.isEmpty)

                } header: {
                    sectionHeaderWithLabel(
                        title: "Vet Details",
                        systemImage: "stethoscope",
                        subtitle: "Your clinic's name, address, phone, and email for quick contact."
                    )
                }
                .id(JumpSection.vet.rawValue)

                // ── Documents ──────────────────────────────────────────────
                Section {
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("Add Document from Files", systemImage: "icloud.and.arrow.up")
                            .foregroundStyle(Color.appPink)
                            .font(AppTypography.secondaryEmphasis)
                    }

                    ForEach(documents) { doc in
                        HStack(spacing: 12) {
                            Image(systemName: doc.iconName)
                                .font(.title3)
                                .foregroundStyle(Color.appPink)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.displayName)
                                    .font(AppTypography.secondaryLabel)
                                    .lineLimit(1)
                                Text("\(doc.sizeString) · \(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                                    .font(AppTypography.supportingText)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Preview / share button
                            ShareLink(item: documentShareURL(for: doc), preview: SharePreview(doc.displayName)) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(AppTypography.compactControl)
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
                            .font(AppTypography.supportingText)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    sectionHeaderWithLabel(
                        title: "Documents",
                        systemImage: "folder.fill",
                        subtitle: "Attach files such as lab results, vaccination records, or insurance—kept on this device."
                    )
                }
                .id(JumpSection.documents.rawValue)

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
                                .font(AppTypography.secondaryEmphasis)
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
                                .font(AppTypography.secondaryEmphasis)
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
                .id(JumpSection.export.rawValue)

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a new weight reading")
                                .font(AppTypography.secondaryEmphasis)
                            Text("Enter the weight and the date it was taken, then tap + to save. You can attach a photo (optional).")
                                .font(AppTypography.supportingText)
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
                                        weightHistory.append(WeightEntry(
                                            date: weightDate,
                                            kg: weightUnit.toKg(val),
                                            imageData: weightEntryImageData
                                        ))
                                        weightHistory.sort { $0.date < $1.date }
                                    }
                                    weightInput = ""
                                    weightEntryImageData = nil
                                    weightEntryPhotoItem = nil
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.appPink)
                                }
                                .buttonStyle(.plain)
                                .disabled(weightInput.isEmpty)
                            }
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $weightEntryPhotoItem, matching: .images) {
                                    Label(
                                        weightEntryImageData == nil ? "Attach photo" : "Change photo",
                                        systemImage: "photo.badge.plus"
                                    )
                                    .font(AppTypography.compactControl)
                                    .foregroundStyle(Color.appPink)
                                }
                                .buttonStyle(.plain)
                                if weightEntryImageData != nil {
                                    Button {
                                        weightEntryImageData = nil
                                        weightEntryPhotoItem = nil
                                    } label: {
                                        Text("Remove")
                                            .font(AppTypography.compactControl)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let data = weightEntryImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: weightEntryPhotoItem) { _, item in
                            Task { weightEntryImageData = try? await item?.loadTransferable(type: Data.self) }
                        }

                    if !weightHistory.isEmpty {
                        if weightHistory.count >= 2 {
                            WeightChartView(entries: weightHistory, unit: weightUnit)
                                .frame(height: 180)
                                .padding(.vertical, 8)
                        }

                        weightReadingsList(entries: weightHistory, unit: weightUnit)

                        Button {
                            withAnimation { weightHistory.removeAll() }
                        } label: {
                            Text("Clear all readings")
                                .font(AppTypography.compactControl)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    }
                } header: {
                    sectionHeader(
                        "Weight",
                        subtitle: "Enter a value and date to build a history—charts appear after two or more entries."
                    )
                }
                .id(JumpSection.weight.rawValue)
                .listRowSeparator(.hidden)

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add a new height reading")
                                .font(AppTypography.secondaryEmphasis)
                            Text("Enter the height and the date it was taken, then tap + to save. You can attach a photo (optional).")
                                .font(AppTypography.supportingText)
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
                                        heightHistory.append(HeightEntry(
                                            date: heightDate,
                                            cm: heightUnit.toCm(val),
                                            imageData: heightEntryImageData
                                        ))
                                        heightHistory.sort { $0.date < $1.date }
                                    }
                                    heightInput = ""
                                    heightEntryImageData = nil
                                    heightEntryPhotoItem = nil
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.appPink)
                                }
                                .buttonStyle(.plain)
                                .disabled(heightInput.isEmpty)
                            }
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $heightEntryPhotoItem, matching: .images) {
                                    Label(
                                        heightEntryImageData == nil ? "Attach photo" : "Change photo",
                                        systemImage: "photo.badge.plus"
                                    )
                                    .font(AppTypography.compactControl)
                                    .foregroundStyle(Color.appPink)
                                }
                                .buttonStyle(.plain)
                                if heightEntryImageData != nil {
                                    Button {
                                        heightEntryImageData = nil
                                        heightEntryPhotoItem = nil
                                    } label: {
                                        Text("Remove")
                                            .font(AppTypography.compactControl)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let data = heightEntryImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: heightEntryPhotoItem) { _, item in
                            Task { heightEntryImageData = try? await item?.loadTransferable(type: Data.self) }
                        }

                    if !heightHistory.isEmpty {
                        if heightHistory.count >= 2 {
                            HeightChartView(entries: heightHistory, unit: heightUnit)
                                .frame(height: 180)
                                .padding(.vertical, 8)
                        }

                        heightReadingsList(entries: heightHistory, unit: heightUnit)

                        Button {
                            withAnimation { heightHistory.removeAll() }
                        } label: {
                            Text("Clear all readings")
                                .font(AppTypography.compactControl)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    }
                } header: {
                    sectionHeader(
                        "Height",
                        subtitle: "Measure and log with a date to track growth or size changes over time."
                    )
                }
                .id(JumpSection.height.rawValue)
                .listRowSeparator(.hidden)

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
                .id(JumpSection.birthday.rawValue)

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            showClearPetDataConfirm = true
                        } label: {
                            Label("Delete pet data", systemImage: "trash.slash")
                        }

                        if onRemovePet != nil {
                            Button(role: .destructive) {
                                showRemovePetConfirm = true
                            } label: {
                                Label("Remove pet from My Pets", systemImage: "rectangle.badge.xmark")
                            }
                        }
                    } header: {
                        Text("Data & list")
                    } footer: {
                        Text("Delete pet data clears weight and height logs, notes, vet details, and documents—your pet’s name, photo, type, and birthday stay. Remove pet deletes this profile and all scheduled events for them.")
                            .font(AppTypography.supportingText)
                    }
                    .id(JumpSection.data.rawValue)
                }
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
            .alert("Delete pet data?", isPresented: $showClearPetDataConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete data", role: .destructive) {
                    performClearPetData()
                }
            } message: {
                Text("This removes weight and height history, notes, vet details, and documents. Name, photo, animal type, and birthday are kept.")
            }
            .alert("Remove from My Pets?", isPresented: $showRemovePetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Remove pet", role: .destructive) {
                    onRemovePet?()
                    dismiss()
                }
            } message: {
                Text("This deletes the pet from your list and removes all scheduled events for them. This cannot be undone.")
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
            .overlay(alignment: .bottom) {
                if showVetDetailsCopiedToast {
                    Text("Copied to clipboard")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                        .padding(.bottom, 28)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showVetDetailsCopiedToast)
        }
    }

    private func performClearPetData() {
        weightHistory = []
        heightHistory = []
        notes = ""
        vetDetails = VetDetails()
        documents = []
        weightInput = ""
        heightInput = ""
        weightEntryImageData = nil
        weightEntryPhotoItem = nil
        heightEntryImageData = nil
        heightEntryPhotoItem = nil
        onSave(Pet(
            id: petID,
            name: name.trimmingCharacters(in: .whitespaces),
            animalType: animalType,
            customAnimalType: animalType == .other ? customAnimalType.trimmingCharacters(in: .whitespaces) : nil,
            dateOfBirth: dateOfBirth,
            photoData: photoData,
            weightHistory: [],
            heightHistory: [],
            notes: "",
            vetDetails: VetDetails(),
            documents: []
        ))
        HapticManager.notification(.success)
    }

    private var previewPet: Pet {
        Pet(id: petID, name: name.isEmpty ? "Pet" : name, animalType: animalType, customAnimalType: customAnimalType, dateOfBirth: dateOfBirth, photoData: photoData)
    }

    private var visibleJumpSections: [JumpSection] {
        JumpSection.allCases.filter { $0.isVisible(isNewPet: isNew, previewPet: previewPet) }
    }

    /// Horizontal capsules above the form; scrolls the grouped list to matching section anchors.
    @ViewBuilder
    private func jumpSectionPillBar(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleJumpSections, id: \.self) { section in
                    let sel = selectedJumpSection == section
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(.spring(duration: 0.25)) {
                            selectedJumpSection = section
                        }
                        withAnimation(.easeInOut(duration: 0.28)) {
                            proxy.scrollTo(section.rawValue, anchor: .top)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.pillSymbol)
                                .font(AppTypography.secondaryEmphasis)
                                .foregroundStyle(sel ? Color.white : Color.black)
                            Text(section.pillTitle)
                                .font(AppTypography.secondaryEmphasis)
                                .foregroundStyle(sel ? Color.white : Color.black)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(sel ? Color.appPink : Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    /// Square tile — user photos fill every pixel inside the rounded rect (aspect fill); placeholder stays padded on gray.
    @ViewBuilder
    private var petProfileCoverImage: some View {
        Group {
            if let data = photoData, let uiImage = UIImage(data: data) {
                GeometryReader { proxy in
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else {
                ZStack {
                    Color(.secondarySystemFill)
                    Image(animalType.placeholderImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func weightReadingsList(entries: [WeightEntry], unit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Date")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Weight")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                HStack(alignment: .center, spacing: 10) {
                    if let data = entry.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(unit.formatValue(entry.kg))
                        .font(AppTypography.compactControl)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Date")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Height")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 2)

            ForEach(entries.sorted { $0.date > $1.date }) { entry in
                HStack(alignment: .center, spacing: 10) {
                    if let data = entry.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(unit.formatValue(entry.cm))
                        .font(AppTypography.compactControl)
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
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showVetDetailsCopiedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                showVetDetailsCopiedToast = false
            }
        }
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
                .font(AppTypography.secondaryEmphasis)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(AppTypography.supportingText)
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
                .font(AppTypography.secondaryEmphasis)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(AppTypography.supportingText)
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
