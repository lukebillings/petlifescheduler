import SwiftUI

struct PetsView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var editingPet: Pet? = nil
    @State private var showingAddPet = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.pets.isEmpty {
                    ContentUnavailableView(
                        "No pets yet",
                        systemImage: "pawprint.fill",
                        description: Text("Tap + to add your first pet.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.pets) { pet in
                                PetCard(pet: pet)
                                    .onTapGesture { editingPet = pet }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation { viewModel.deletePet(pet) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
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
                PetDetailSheet(pet: pet) { updated in
                    viewModel.updatePet(updated)
                }
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
        VStack(spacing: 0) {
            // Animal illustration area
            Group {
                if let data = pet.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(pet.color.opacity(0.12))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: pet.systemImage)
                                .resizable()
                                .scaledToFit()
                                .padding(32)
                                .foregroundStyle(pet.color.gradient)
                        }
                }
            }

            // Info row
            VStack(spacing: 2) {
                Text(pet.name)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)

                if let age = pet.age {
                    Text(age)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    PetsView(viewModel: HomeViewModel.preview)
}
