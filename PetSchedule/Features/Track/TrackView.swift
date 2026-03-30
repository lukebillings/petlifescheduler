import SwiftUI

struct TrackView: View {
    @Bindable var trackStore: TrackStore
    var petsViewModel: PetsViewModel

    @State private var showAddTodo = false
    @State private var newTodoTitle = ""
    @State private var showLogWellness = false
    @State private var showAddHabit = false
    @State private var newHabitTitle = ""
    @State private var newHabitDetail = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if trackStore.todos.isEmpty {
                        Text("No to-dos yet. Tap + to add one-off tasks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTodos) { todo in
                            todoRow(todo)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                trackStore.deleteTodo(id: sortedTodos[index].id)
                            }
                        }
                    }
                } header: {
                    Label("To-dos", systemImage: "checklist")
                }

                Section {
                    ForEach(trackStore.habits) { habit in
                        habitRow(habit)
                    }
                    .onDelete { idx in
                        let ids = idx.map { trackStore.habits[$0].id }
                        for id in ids {
                            trackStore.deleteHabit(id: id)
                        }
                    }
                    Button {
                        newHabitTitle = ""
                        newHabitDetail = ""
                        showAddHabit = true
                    } label: {
                        Label("Add habit", systemImage: "plus.circle")
                    }
                } header: {
                    Label("Habits", systemImage: "repeat.circle")
                } footer: {
                    Text("Tap the circle to mark today. Days reset automatically for new dates.")
                }

                Section {
                    Button {
                        showLogWellness = true
                    } label: {
                        Label("Log energy & mood", systemImage: "heart.text.square.fill")
                    }
                    if trackStore.wellnessLogs.isEmpty {
                        Text("Log how your pet is feeling—energy and happiness.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trackStore.wellnessLogs) { log in
                            wellnessRow(log)
                        }
                        .onDelete { idx in
                            let ids = idx.map { trackStore.wellnessLogs[$0].id }
                            for id in ids {
                                trackStore.deleteWellnessLog(id: id)
                            }
                        }
                    }
                } header: {
                    Label("States", systemImage: "heart.text.square")
                }
            }
            .navigationTitle("Track")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add to-do", systemImage: "plus") {
                        newTodoTitle = ""
                        showAddTodo = true
                    }
                }
            }
            .sheet(isPresented: $showAddTodo) {
                NavigationStack {
                    Form {
                        TextField("Title", text: $newTodoTitle)
                    }
                    .navigationTitle("New to-do")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddTodo = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                trackStore.addTodo(title: newTodoTitle)
                                showAddTodo = false
                            }
                            .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddHabit) {
                NavigationStack {
                    Form {
                        TextField("Name (e.g. Brush teeth)", text: $newHabitTitle)
                        TextField("Note (optional)", text: $newHabitDetail)
                    }
                    .navigationTitle("New habit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddHabit = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                trackStore.addHabit(title: newHabitTitle, detail: newHabitDetail)
                                showAddHabit = false
                            }
                            .disabled(newHabitTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showLogWellness) {
                LogWellnessSheet(trackStore: trackStore, petsViewModel: petsViewModel) {
                    showLogWellness = false
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var sortedTodos: [OneOffTodo] {
        trackStore.todos.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone && b.isDone }
            return a.createdAt > b.createdAt
        }
    }

    private func todoRow(_ todo: OneOffTodo) -> some View {
        Button {
            trackStore.toggleTodo(id: todo.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? Color.green : Color.secondary.opacity(0.45))
                Text(todo.title)
                    .foregroundStyle(todo.isDone ? .secondary : .primary)
                    .strikethrough(todo.isDone, color: .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func habitRow(_ habit: HabitTrack) -> some View {
        let done = habit.isCompleted(on: trackStore.todayDayKey)
        return Button {
            trackStore.toggleHabitToday(id: habit.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? Color.accentColor : Color.secondary.opacity(0.45))
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.headline)
                    if !habit.detail.isEmpty {
                        Text(habit.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(done ? "Done today" : "Not yet today")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(done ? .green : .secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func wellnessRow(_ log: WellnessStateLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.petName.isEmpty ? "Pet" : log.petName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(log.recordedAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(log.energy, systemImage: "bolt.fill")
                    .font(.caption)
                Label(log.happiness, systemImage: "face.smiling")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Log wellness sheet

private struct LogWellnessSheet: View {
    var trackStore: TrackStore
    var petsViewModel: PetsViewModel
    var onDismiss: () -> Void

    @State private var petName: String = ""
    @State private var energy: String = WellnessOptions.energyLevels[1]
    @State private var happiness: String = WellnessOptions.happinessLevels[2]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pet", selection: $petName) {
                        Text("Not specified").tag("")
                        ForEach(namedPets, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                } header: {
                    Text("Pet")
                }

                Section {
                    Picker("Energy", selection: $energy) {
                        ForEach(WellnessOptions.energyLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    Picker("Happy", selection: $happiness) {
                        ForEach(WellnessOptions.happinessLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                } header: {
                    Text("How are they?")
                }
            }
            .navigationTitle("Log state")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        trackStore.addWellnessLog(petName: petName, energy: energy, happiness: happiness)
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var namedPets: [String] {
        petsViewModel.pets.map(\.name).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

#Preview("Track") {
    TrackView(trackStore: TrackStore(), petsViewModel: PetsViewModel())
}
