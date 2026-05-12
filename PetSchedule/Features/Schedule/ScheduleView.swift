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
                    // Title only — pets sit below the wave on the sheet background.
                    PinkWaveScreenHeader("Schedule")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.pets) { pet in
                                let isSelected = viewModel.selectedPet?.id == pet.id
                                let pending = viewModel.pendingTodayTaskCount(for: pet)
                                Button {
                                    HapticManager.impact(.light)
                                    withAnimation(.spring(duration: 0.25)) {
                                        viewModel.togglePetFilter(pet)
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        ZStack(alignment: .topTrailing) {
                                            PetAvatarView(pet: pet, size: 52)
                                                .overlay {
                                                    if isSelected {
                                                        Circle()
                                                            .strokeBorder(Color.appPink, lineWidth: 2.5)
                                                    } else {
                                                        Circle()
                                                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                                                    }
                                                }
                                                .scaleEffect(isSelected ? 1.04 : 1.0)

                                            if pending > 0 {
                                                Text(pending > 99 ? "99+" : "\(pending)")
                                                    .font(AppTypography.micro)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, pending > 9 ? 5 : 0)
                                                    .frame(minWidth: 17, minHeight: 17)
                                                    .background(Color.appPink, in: Capsule())
                                                    .overlay(
                                                        Capsule()
                                                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                                    )
                                                    .offset(x: 7, y: -7)
                                            }
                                        }
                                        Text(pet.name)
                                            .font(AppTypography.compactControl)
                                            .foregroundStyle(isSelected ? Color.appPink : Color.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0), location: 0),
                                .init(color: .black, location: 0.05),
                                .init(color: .black, location: 0.95),
                                .init(color: .black.opacity(0), location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .background(Color(.systemGroupedBackground))

                    ScheduleViewModeCapsule(selection: $viewModel.selectedView)
                        .padding(.horizontal)
                        .padding(.top, 12)

                    // Shared Today header — shown in both list and calendar modes.
                    scheduleDateHeaderBar
                }
                .background(Color(.systemGroupedBackground))
                .modifier(InterfaceContentEntranceModifier(delay: 0))

                if viewModel.selectedView == .list {
                    PostTutorialScheduleHintStack(viewModel: viewModel)
                }

                // ── Scrollable: events only ───────────────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        switch viewModel.selectedView {
                        case .list:
                            ScheduleListView(viewModel: viewModel, hideCompleted: $hideCompleted)
                        case .calendar:
                            CalendarScheduleView(viewModel: viewModel, hideCompleted: $hideCompleted)
                        }
                        Spacer(minLength: 100)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)

            }
            .background(Color(.systemGroupedBackground))
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

    /// Shared Today / date bar that appears above both list and calendar content.
    @ViewBuilder
    private var scheduleDateHeaderBar: some View {
        let isCalendar = viewModel.selectedView == .calendar
        let displayDate: Date = isCalendar ? viewModel.selectedCalendarDate : .now
        let isToday = Calendar.current.isDateInToday(displayDate)

        HStack(alignment: .center, spacing: 6) {
            HStack(spacing: 6) {
                Text(isToday ? "Today" : displayDate.formatted(.dateTime.weekday(.abbreviated)))
                    .font(AppTypography.sectionHeading)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                Text(displayDate.formatted(.dateTime.day().month(.abbreviated)))
                    .font(AppTypography.compactControl)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isToday ? .blue : Color.appPink, in: Capsule())
            }
            .layoutPriority(2)
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                scheduleHeaderCapsuleButton(title: "Event", systemImage: "calendar.badge.plus", tint: Color.appPink) {
                    showingAddEvent = true
                }
                scheduleHeaderCapsuleButton(title: "Log", systemImage: "doc.text", tint: Color.appPink) {
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
                        .font(AppTypography.navControl)
                    Text(hideCompleted ? "To Do" : "All")
                        .font(AppTypography.compactControl)
                        .lineLimit(1)
                        .minimumScaleFactor(1)
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

    /// Header action chip: keep **+** and title on one line when horizontal space is tight.
    private func scheduleHeaderCapsuleButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(AppTypography.compactControl)
                Text(title)
                    .font(AppTypography.compactControl)
                    .lineLimit(1)
                    .minimumScaleFactor(1)
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

/// List / month toggle on a material capsule (replaces the system segmented control).
private struct ScheduleViewModeCapsule: View {
    @Binding var selection: HomeViewModel.ViewMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HomeViewModel.ViewMode.allCases, id: \.self) { mode in
                let selected = selection == mode
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selection = mode
                    }
                    HapticManager.impact(.light)
                } label: {
                    Image(systemName: mode == .list ? "list.bullet.rectangle" : "calendar")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selected ? Color.appPink : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(mode.rawValue))
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    ScheduleView(viewModel: HomeViewModel.preview)
}
