import SwiftUI

struct PetsView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var editingPet: Pet? = nil
    @State private var showingAddPet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if viewModel.pets.isEmpty {
                        ContentUnavailableView(
                            "No pets yet",
                            systemImage: "pawprint.fill",
                            description: Text("Tap + to add your first pet.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(viewModel.pets.enumerated()), id: \.element.id) { index, pet in
                                    PetCard(pet: pet)
                                        .onTapGesture { editingPet = pet }
                                        .modifier(SlideInRowModifier(index: index))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                withAnimation { viewModel.deletePet(pet) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }

                                    if index == 0 {
                                        PostTutorialPetsHintStack(viewModel: viewModel)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("My Pets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddPet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $editingPet) { pet in
                PetDetailSheet(
                    pet: pet,
                    onSave: { viewModel.updatePet($0) },
                    onRemovePet: {
                        viewModel.deletePet(pet)
                        editingPet = nil
                    }
                )
            }
            .sheet(isPresented: $showingAddPet) {
                PetDetailSheet(pet: nil) { newPet in
                    viewModel.addPet(newPet)
                }
            }
        }
    }
}

private struct PetCard: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let data = pet.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Image(pet.animalType.placeholderImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(pet.name)
                .font(AppTypography.primaryLabel)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.compactControl)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    PetsView(viewModel: HomeViewModel.preview)
}
