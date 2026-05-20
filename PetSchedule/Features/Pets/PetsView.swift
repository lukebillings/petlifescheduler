import SwiftUI

struct PetsView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var editingPet: Pet? = nil
    @State private var showingAddPet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PinkWaveScreenHeader("My Pets", trailing: {
                    Button {
                        showingAddPet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 4)
                    .accessibilityLabel("Add pet")
                })

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
                        .scrollEdgeEffectStyle(.soft, for: .top)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
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
            PetAvatarView(pet: pet, size: 78, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(AppTypography.primaryLabel)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: pet.animalType.systemImage)
                        .font(AppTypography.compactControl)
                        .foregroundStyle(pet.animalType.color)
                    Text(pet.animalType.displayName)
                        .font(AppTypography.compactControl)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(AppTypography.compactControl)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    PetsView(viewModel: HomeViewModel.preview)
}
