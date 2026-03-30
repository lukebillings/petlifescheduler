import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                HomeBackgroundView()

                VStack(spacing: 10) {
                    compactHeader

                    HStack(alignment: .top, spacing: 10) {
                        compactSection(title: "Today", systemImage: "calendar") {
                            if viewModel.todayCalendarItems.isEmpty {
                                HomeEmptyHint("Nothing today.")
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(viewModel.todayCalendarItems.enumerated()), id: \.element.id) { index, item in
                                        compactCalendarRow(item)
                                        if index < viewModel.todayCalendarItems.count - 1 {
                                            Divider().padding(.leading, 22)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        compactSection(title: "To-dos", systemImage: "checklist") {
                            if viewModel.todos.isEmpty {
                                HomeEmptyHint("Add tasks in Track.")
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(viewModel.todos.enumerated()), id: \.element.id) { index, todo in
                                        compactTodoRow(todo)
                                        if index < viewModel.todos.count - 1 {
                                            Divider().padding(.leading, 28)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        compactSection(title: "Habits", systemImage: "repeat.circle") {
                            if viewModel.habits.isEmpty {
                                HomeEmptyHint("Habits live in Track.")
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { index, habit in
                                        compactHabitRow(habit)
                                        if index < viewModel.habits.count - 1 {
                                            Divider().padding(.leading, 28)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        compactSection(title: "States", systemImage: "heart.text.square") {
                            if viewModel.petStates.isEmpty {
                                HomeEmptyHint("Log energy & mood in Track.")
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(viewModel.petStates) { state in
                                        compactStateRow(state)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    compactSection(title: "Age year", systemImage: "hourglass.bottomhalf.filled") {
                        if viewModel.dogs.isEmpty {
                            HomeEmptyHint("Add a pet with birthday in Pets.")
                        } else {
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(viewModel.dogs) { dog in
                                    compactDogAgeCell(dog)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 6)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private var compactHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Pet Schedule")
                .font(.title2.weight(.bold))
            Spacer(minLength: 8)
            Text(formattedToday)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var formattedToday: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date())
    }

    private func compactCalendarRow(_ item: HomeCalendarItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: item.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.45, blue: 0.85))
                .frame(width: 16, alignment: .center)
            Text(item.timeString())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            Text(item.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
    }

    private func compactTodoRow(_ todo: HomeTodo) -> some View {
        Button {
            viewModel.toggleTodo(id: todo.id)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(todo.isDone ? Color.green : Color.secondary.opacity(0.45))
                Text(todo.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                    .strikethrough(todo.isDone, color: .secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func compactHabitRow(_ habit: HomeHabit) -> some View {
        Button {
            viewModel.toggleHabit(id: habit.id)
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: habit.completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(habit.completedToday ? Color.accentColor : Color.secondary.opacity(0.45))
                VStack(alignment: .leading, spacing: 0) {
                    Text(habit.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(habit.targetSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func compactStateRow(_ state: PetStateItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: state.symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(state.petName)
                .font(.caption2.weight(.semibold))
            Text("·")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(state.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(state.value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 2)
    }

    private func compactDogAgeCell(_ dog: HomeDog) -> some View {
        let progress = viewModel.ageYearProgress(for: dog)
        let years = viewModel.chronologicalAge(for: dog)
        let pct = Int((progress * 100).rounded())
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dog.name)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(pct)%")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(Color(red: 0.25, green: 0.45, blue: 0.85))
            Text("\(years) yrs · last birthday → next")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .imageScale(.small)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
        )
    }
}

private struct HomeEmptyHint: View {
    let message: String
    init(_ message: String) { self.message = message }
    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeBackgroundView: View {
    var body: some View {
        LinearGradient(
          colors: [
            Color(red: 0.97, green: 0.98, blue: 1.0),
            Color(red: 0.93, green: 0.96, blue: 0.99)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview("Home") {
    HomeView(viewModel: HomeViewModel(trackStore: TrackStore()))
}
