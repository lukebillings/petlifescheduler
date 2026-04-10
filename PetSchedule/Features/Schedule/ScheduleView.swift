import SwiftUI

struct ScheduleView: View {
    @Bindable var viewModel: HomeViewModel

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
                                    VStack(spacing: 6) {
                                        PetAvatarView(pet: pet, size: 60)
                                        Text(pet.name)
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
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
        }
    }
}

#Preview {
    ScheduleView(viewModel: HomeViewModel())
}
