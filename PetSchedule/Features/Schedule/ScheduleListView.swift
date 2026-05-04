import SwiftUI

struct ScheduleListView: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var hideCompleted: Bool
    @State private var editingItem: ScheduleItem? = nil
    @State private var viewingPet: Pet? = nil
    @State private var confettiTrigger = 0
    @State private var now: Date = .now

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var allItems: [ScheduleItem] {
        viewModel.todayItems
    }

    private var displayedItems: [ScheduleItem] {
        hideCompleted ? allItems.filter { !$0.isCompleted } : allItems
    }

    /// All-day items (birthdays etc.) shown at the top
    private var allDayItems: [ScheduleItem] {
        displayedItems.filter { $0.isAllDay }
    }

    /// Timed items sorted by time
    private var timedItems: [ScheduleItem] {
        displayedItems.filter { !$0.isAllDay }
    }

    /// Index in timedItems where "now" falls — items before this are in the past
    private var nowInsertionIndex: Int {
        timedItems.firstIndex { $0.time > now } ?? timedItems.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if displayedItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.appPink.opacity(0.5))
                        Text("All done for today!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    // ── All-day events (birthdays) ────────────────────────────
                    if !allDayItems.isEmpty {
                        ForEach(Array(allDayItems.enumerated()), id: \.element.id) { dayIndex, item in
                            BirthdayRowView(item: item) {
                                viewingPet = item.pet
                            }
                            .modifier(SlideInRowModifier(index: dayIndex))
                        }
                    }

                    // ── Timed items with "NOW" bar ────────────────────────────
                    if !timedItems.isEmpty {
                        ForEach(Array(timedItems.enumerated()), id: \.element.id) { index, item in
                            let isPast = index < nowInsertionIndex

                            // Insert "NOW" divider before the first future event
                            if index == nowInsertionIndex {
                                NowDivider(time: now)
                            }

                            ScheduleRowView(item: item) {
                                let wasCompleted = item.isCompleted
                                viewModel.toggleCompletion(for: item)
                                if !wasCompleted {
                                    HapticManager.playCompletion()
                                    HapticManager.notification(.success)
                                    confettiTrigger += 1
                                }
                            } onTap: {
                                editingItem = item
                            } onPetTap: {
                                viewingPet = item.pet
                            } onMedicineAccept: { accepted in
                                viewModel.setMedicineAccepted(accepted, for: item)
                                HapticManager.notification(.success)
                            }
                            .opacity(isPast ? 0.82 : 1.0)
                            .saturation(isPast ? 0.88 : 1.0)
                            .modifier(SlideInRowModifier(index: allDayItems.count + index))
                        }

                        // If all events are in the past, show NOW bar after last item
                        if nowInsertionIndex == timedItems.count && !timedItems.isEmpty {
                            NowDivider(time: now)
                        }
                    }
                }
                .overlay(ConfettiView(trigger: confettiTrigger).allowsHitTesting(false))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onReceive(timer) { t in now = t }
        .sheet(item: $editingItem) { item in
            Group {
                if item.quickLogKind != nil {
                    EditLogSheet(viewModel: viewModel, item: item)
                } else {
                    EditEventSheet(viewModel: viewModel, item: item)
                }
            }
        }
        .sheet(item: $viewingPet) { pet in
            PetDetailSheet(
                pet: pet,
                onSave: { viewModel.updatePet($0) },
                onRemovePet: {
                    viewModel.deletePet(pet)
                    viewingPet = nil
                }
            )
        }
    }
}

// MARK: - Now Divider

private struct NowDivider: View {
    let time: Date

    var body: some View {
        HStack(spacing: 8) {
            // Dot
            Circle()
                .fill(Color.appPink)
                .frame(width: 10, height: 10)

            // Line
            Rectangle()
                .fill(
                    LinearGradient(colors: [Color.appPink, Color.appPink.opacity(0.15)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(height: 2)
                .overlay(alignment: .leading) {
                    // Time label
                    Text(time.formatted(.dateTime.hour().minute()))
                        .font(.caption2.bold())
                        .foregroundStyle(Color.appPink)
                        .padding(.leading, 4)
                        .offset(y: -14)
                }
        }
        .padding(.vertical, 2)
        .animation(.none, value: time)
    }
}

// MARK: - Birthday Row

private struct BirthdayRowView: View {
    let item: ScheduleItem
    let onPetTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            PetAvatarView(pet: item.pet, size: 52)
                .onTapGesture { onPetTap() }
                .overlay(alignment: .bottomTrailing) {
                    Text("🎂")
                        .font(.title3)
                        .offset(x: 4, y: 4)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("All Day")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(item.activityName)
                    .font(.subheadline.bold())
            }

            Spacer()

            Image(systemName: "gift.fill")
                .font(.title3)
                .foregroundStyle(Color.appPink)
                .symbolEffect(.pulse)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.appPink.opacity(0.15), Color.appPink.opacity(0.05)],
                startPoint: .leading, endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.appPink.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    ScheduleListView(viewModel: HomeViewModel.preview, hideCompleted: .constant(false))
        .padding(.top)
}
