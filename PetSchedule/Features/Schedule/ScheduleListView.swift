import SwiftUI
import AudioToolbox

struct ScheduleListView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var hideCompleted = false
    @State private var editingItem: ScheduleItem? = nil
    @State private var viewingPet: Pet? = nil
    @State private var confettiTrigger = 0

    private var displayedItems: [ScheduleItem] {
        hideCompleted ? viewModel.todayItems.filter { !$0.isCompleted } : viewModel.todayItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                GlassEffectContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(displayedItems) { item in
                            ScheduleRowView(item: item) {
                                let wasCompleted = item.isCompleted
                                viewModel.toggleCompletion(for: item)
                                if !wasCompleted {
                                    AudioServicesPlaySystemSound(1322)
                                    HapticManager.notification(.success)
                                    confettiTrigger += 1
                                }
                            } onTap: {
                                editingItem = item
                            } onPetTap: {
                                viewingPet = item.pet
                            }
                        }
                    }
                }
                .overlay(ConfettiView(trigger: confettiTrigger).allowsHitTesting(false))
            }
        }
        .padding(.horizontal)
        .sheet(item: $editingItem) { item in
            EditEventSheet(viewModel: viewModel, item: item)
        }
        .sheet(item: $viewingPet) { pet in
            PetDetailSheet(pet: pet) { updated in
                viewModel.updatePet(updated)
            }
        }
    }
}

#Preview {
    ScheduleListView(viewModel: HomeViewModel.preview)
        .padding(.top)
}
