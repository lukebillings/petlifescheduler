import SwiftUI

struct ScheduleView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingAddEvent = false
    @State private var hideCompleted = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // ── Sticky header (never scrolls) ─────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    // My Pets row
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
                    .padding(.top, 20)

                    // View mode picker
                    Picker("View", selection: $viewModel.selectedView) {
                        ForEach(HomeViewModel.ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .onChange(of: viewModel.selectedView) {
                        HapticManager.impact(.light)
                    }

                    // Today header (list mode only)
                    if viewModel.selectedView == .list {
                        HStack(alignment: .center, spacing: 10) {
                            Text("Today")
                                .font(.title3.bold())

                            Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue, in: Capsule())

                            Spacer()

                            Button { showingAddEvent = true } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                    Text("Event")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.appPink, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    hideCompleted.toggle()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: hideCompleted ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                        .font(.body.bold())
                                    Text(hideCompleted ? "Pending" : "All")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(hideCompleted ? Color.appPink : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(hideCompleted ? Color.appPink.opacity(0.12) : Color(.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }

                    // Calendar header — + Event button (calendar mode only)
                    if viewModel.selectedView == .calendar {
                        HStack {
                            Spacer()
                            Button { showingAddEvent = true } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                    Text("Event")
                                        .font(.caption.bold())
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.appPink, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    }
                }
                .background(Color(.systemBackground))

                // ── Scrollable: events only ───────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch viewModel.selectedView {
                        case .list:
                            ScheduleListView(viewModel: viewModel, hideCompleted: $hideCompleted)
                        case .calendar:
                            CalendarScheduleView(viewModel: viewModel)
                        }
                        Spacer(minLength: 100)
                    }
                }


            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddEvent) {
                AddEventSheet(
                    viewModel: viewModel,
                    prefilledDate: viewModel.selectedView == .calendar ? viewModel.selectedCalendarDate : nil
                )
            }
        }
    }
}

#Preview {
    ScheduleView(viewModel: HomeViewModel.preview)
}
