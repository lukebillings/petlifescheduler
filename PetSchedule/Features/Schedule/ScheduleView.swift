import SwiftUI

struct ScheduleView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingAddEvent = false
    @State private var showingAddLog = false
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
                                    let pending = viewModel.pendingTodayTaskCount(for: pet)
                                    Button {
                                        HapticManager.impact(.light)
                                        withAnimation(.spring(duration: 0.25)) {
                                            viewModel.togglePetFilter(pet)
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack(alignment: .topTrailing) {
                                                PetAvatarView(pet: pet, size: 60)
                                                    .overlay {
                                                        if isSelected {
                                                            Circle()
                                                                .strokeBorder(Color.appPink, lineWidth: 3)
                                                        }
                                                    }
                                                    .scaleEffect(isSelected ? 1.05 : 1.0)

                                                if pending > 0 {
                                                    Text(pending > 99 ? "99+" : "\(pending)")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, pending > 9 ? 5 : 0)
                                                        .frame(minWidth: 18, minHeight: 18)
                                                        .background(Color.appPink, in: Capsule())
                                                        .overlay(
                                                            Capsule()
                                                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                                        )
                                                        .offset(x: 8, y: -8)
                                                }
                                            }
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
                        HStack(alignment: .center, spacing: 6) {
                            Text("Today")
                                .font(.title3.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Text(Date.now.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue, in: Capsule())
                                .layoutPriority(1)

                            Spacer(minLength: 4)

                            HStack(spacing: 4) {
                                scheduleHeaderCapsuleButton(title: "Event", tint: Color.appPink) {
                                    showingAddEvent = true
                                }
                                scheduleHeaderCapsuleButton(title: "Log", tint: Color.appPink.opacity(0.85)) {
                                    showingAddLog = true
                                }
                            }
                            .layoutPriority(1)

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
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
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
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }

                    // Calendar header — + Event button (calendar mode only)
                    if viewModel.selectedView == .calendar {
                        HStack(spacing: 6) {
                            Spacer()
                            scheduleHeaderCapsuleButton(title: "Event", tint: Color.appPink) {
                                showingAddEvent = true
                            }
                            scheduleHeaderCapsuleButton(title: "Log", tint: Color.appPink.opacity(0.85)) {
                                showingAddLog = true
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    }
                }
                .background(Color(.systemBackground))
                .modifier(InterfaceContentEntranceModifier(delay: 0))

                PostTutorialScheduleHintStack(viewModel: viewModel)

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
            .sheet(isPresented: $showingAddLog) {
                AddLogSheet(
                    viewModel: viewModel,
                    prefilledDate: viewModel.selectedView == .calendar ? viewModel.selectedCalendarDate : nil
                )
            }
        }
    }

    /// Header action chip: keep **+** and title on one line when horizontal space is tight.
    private func scheduleHeaderCapsuleButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption.bold())
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    ScheduleView(viewModel: HomeViewModel.preview)
}
