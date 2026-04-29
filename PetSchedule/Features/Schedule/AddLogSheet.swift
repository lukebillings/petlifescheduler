import SwiftUI
import PhotosUI
import UIKit

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

    private var resolvedTitle: String {
        switch logKind {
        case .poo, .wee: return logKind.rawValue
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
                        ForEach(QuickLogKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.iconName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if logKind == .custom {
                        TextField("What happened?", text: $customTitle)
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

#Preview {
    AddLogSheet(viewModel: HomeViewModel.preview)
}
