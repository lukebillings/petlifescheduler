import SwiftUI
import UIKit

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                HomeBackgroundView()

                ScrollView {
                    VStack(spacing: 12) {
                        compactHeader

                        if viewModel.homePets.isEmpty {
                            ContentUnavailableView(
                                "No pet profiles",
                                systemImage: "pawprint.fill",
                                description: Text("Add pets in the Pets tab to see their cards here.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        } else {
                            ForEach(Array(viewModel.homePets.enumerated()), id: \.element.id) { index, pet in
                                petBrandedCard(pet: pet, accent: petAccentColor(index: index))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private var compactHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("My Pets")
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

    private func petBrandedCard(pet: PetProfile, accent: Color) -> some View {
        let states = viewModel.wellnessStateItems(forPet: pet)
        let todayItems = viewModel.todayCalendarItems(forPet: pet)
        let dog = viewModel.homeDog(for: pet)
        let displayName = pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pet" : pet.name

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                HomePetAvatar(photoData: pet.photoData, accent: accent, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    if !pet.animalSpecies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(pet.animalSpecies)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                ageYearProgressRing(dog: dog)
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    petInnerBlock(title: "Today", systemImage: "calendar") {
                        if todayItems.isEmpty {
                            HomeEmptyHint("Nothing today. Add in Schedule.")
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(todayItems.enumerated()), id: \.element.id) { index, item in
                                    compactCalendarRow(item)
                                    if index < todayItems.count - 1 {
                                        Divider().padding(.leading, 22)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    petInnerBlock(title: "To-dos", systemImage: "checklist") {
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
                    petInnerBlock(title: "Habits", systemImage: "repeat.circle") {
                        if viewModel.habits.isEmpty {
                            HomeEmptyHint("Add habits in Track.")
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

                    petInnerBlock(title: "States", systemImage: "heart.text.square") {
                        if states.isEmpty {
                            HomeEmptyHint("Log in Track.")
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(states) { state in
                                    compactStateRow(state)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(accent.opacity(0.55), lineWidth: 3)
        )
        .shadow(color: accent.opacity(0.12), radius: 10, y: 4)
    }

    private func petInnerBlock(title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func petAccentColor(index: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.22, green: 0.52, blue: 0.88),
            Color(red: 0.92, green: 0.38, blue: 0.48),
            Color(red: 0.32, green: 0.62, blue: 0.48),
            Color(red: 0.62, green: 0.42, blue: 0.88),
            Color(red: 0.95, green: 0.58, blue: 0.18),
            Color(red: 0.18, green: 0.58, blue: 0.72),
        ]
        return palette[index % palette.count]
    }

    private func compactCalendarRow(_ item: HomeCalendarItem) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: item.symbolName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.45, blue: 0.85))
                .frame(width: 14, alignment: .center)
            Text(item.timeString())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 36, maxWidth: 44, alignment: .leading)
            Text(item.title)
                .font(.caption2.weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
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

    /// Green ring = progress through current “age year”; center shows chronological age (yrs / mos / days).
    private func ageYearProgressRing(dog: HomeDog?) -> some View {
        let ringSize: CGFloat = 54
        let lineWidth: CGFloat = 5

        return Group {
            if let dog {
                let progress = viewModel.ageYearProgress(for: dog)
                let age = viewModel.ageRingDisplay(for: dog)
                let primarySize: CGFloat = age.primary.count >= 3 ? 15 : 17
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: lineWidth)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                        .stroke(
                            Color.green,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(age.primary)
                            .font(.system(size: primarySize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        if !age.secondary.isEmpty {
                            Text(age.secondary)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(age.accessibility)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(width: ringSize, height: ringSize)
                .accessibilityLabel("Add birthday in Pets to see age")
            }
        }
    }
}

private struct HomePetAvatar: View {
    let photoData: Data?
    var accent: Color
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let photoData, let ui = UIImage(data: photoData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(accent, lineWidth: 3)
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
    let store = TrackStore()
    let schedule = ScheduleViewModel()
    HomeView(viewModel: HomeViewModel(trackStore: store, scheduleViewModel: schedule))
}
