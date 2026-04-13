import SwiftUI

struct ScheduleView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingAddEvent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // My pets
                    VStack(alignment: .leading, spacing: 14) {
                        Text("My pets")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(viewModel.pets) { pet in
                                    let isSelected = viewModel.selectedPet?.id == pet.id
                                    Button {
                                        withAnimation(.spring(duration: 0.25)) {
                                            viewModel.togglePetFilter(pet)
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            PetAvatarView(pet: pet, size: 60)
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
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        }
                        .scrollClipDisabled()
                    }

                    // List / Calendar picker
                    Picker("View", selection: $viewModel.selectedView) {
                        ForEach(HomeViewModel.ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Content
                    switch viewModel.selectedView {
                    case .list:
                        ScheduleListView(viewModel: viewModel)
                    case .calendar:
                        CalendarScheduleView(viewModel: viewModel)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                Button {
                    showingAddEvent = true
                } label: {
                    Label("Add Event", systemImage: "plus")
                        .font(.body.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.white)
                .glassEffect(.regular.tint(.appPink).interactive(), in: Capsule())
                .padding(.bottom, 16)
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventSheet(viewModel: viewModel)
            }
        }
    }
}

#Preview {
    ScheduleView(viewModel: HomeViewModel.preview)
}
