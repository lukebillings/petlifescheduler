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
                    if !trackStore.habits.isEmpty {
                        HabitCheckeredBoard(trackStore: trackStore)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
                            .listRowSeparator(.hidden)
                    }
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
                    Text("Checkerboard: green = habit done that day, red = not done. Top row shows green only when every habit is done. Tap any square (except future days) to fix.")
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

// MARK: - Habit checkerboard

private struct HabitCheckeredBoard: View {
    var trackStore: TrackStore

    private let columnCount = 14
    private let cell: CGFloat = 22
    private let labelWidth: CGFloat = 78
    private let gap: CGFloat = 3

    private var dayKeys: [String] { trackStore.recentDayKeys(count: columnCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last \(columnCount) days · \(todayHint)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: gap + 2) {
                    headerRow
                    allHabitsRow
                    ForEach(trackStore.habits) { habit in
                        habitGridRow(habit)
                    }
                }
            }
            legendRow
        }
        .padding(.vertical, 6)
    }

    private var todayHint: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return "today \(df.string(from: Date()))"
    }

    private var headerRow: some View {
        habitBoardRow(spacing: gap) {
            Color.clear
                .frame(width: labelWidth, height: cell + 8)
            ForEach(Array(dayKeys.enumerated()), id: \.element) { _, key in
                VStack(spacing: 1) {
                    Text(weekdayLetter(key))
                        .font(.system(size: 8, weight: .bold))
                    Text(dayNumber(key))
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .opacity(trackStore.isFutureDayKey(key) ? 0.45 : 1)
                .frame(width: cell, height: cell + 10)
            }
        }
    }

    private var allHabitsRow: some View {
        habitBoardRow(spacing: gap) {
            Text("All habits")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(Array(dayKeys.enumerated()), id: \.element) { index, key in
                summaryCell(dayKey: key, columnIndex: index)
            }
        }
    }

    private func habitGridRow(_ habit: HabitTrack) -> some View {
        habitBoardRow(spacing: gap) {
            Text(habit.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)
            ForEach(Array(dayKeys.enumerated()), id: \.element) { index, key in
                habitCell(habit: habit, dayKey: key, columnIndex: index)
            }
        }
    }

    private func habitBoardRow<Content: View>(
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: spacing) {
            content()
        }
    }

    private func summaryCell(dayKey: String, columnIndex: Int) -> some View {
        let future = trackStore.isFutureDayKey(dayKey)
        let allDone = trackStore.allHabitsCompleted(on: dayKey)
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(summaryFill(allDone: allDone, future: future))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(checkerStroke(columnIndex), lineWidth: 1)
            )
            .frame(width: cell, height: cell)
            .accessibilityLabel(accessibilitySummary(dayKey: dayKey, allDone: allDone, future: future))
    }

    private func habitCell(habit: HabitTrack, dayKey: String, columnIndex: Int) -> some View {
        let future = trackStore.isFutureDayKey(dayKey)
        let done = habit.isCompleted(on: dayKey)
        return Button {
            trackStore.toggleHabit(id: habit.id, onDayKey: dayKey)
        } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(habitFill(done: done, future: future, columnIndex: columnIndex))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(checkerStroke(columnIndex), lineWidth: 1)
                )
                .frame(width: cell, height: cell)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .accessibilityLabel("\(habit.title), \(formattedDay(dayKey)), \(future ? "future day" : done ? "done" : "not done")")
    }

    private func summaryFill(allDone: Bool, future: Bool) -> Color {
        if future { return Color.gray.opacity(0.2) }
        return allDone ? Color.green.opacity(0.82) : Color.red.opacity(0.5)
    }

    private func habitFill(done: Bool, future: Bool, columnIndex: Int) -> Color {
        if future { return Color.gray.opacity(0.2) }
        let deep = columnIndex % 2 == 0
        if done {
            return Color.green.opacity(deep ? 0.78 : 0.62)
        }
        return Color.red.opacity(deep ? 0.52 : 0.38)
    }

    private func checkerStroke(_ columnIndex: Int) -> Color {
        Color.primary.opacity(columnIndex % 2 == 0 ? 0.1 : 0.05)
    }

    private var legendRow: some View {
        HStack(spacing: 12) {
            legendItem(color: Color.green.opacity(0.75), label: "Done")
            legendItem(color: Color.red.opacity(0.45), label: "Missed")
            legendItem(color: Color.gray.opacity(0.22), label: "Future")
            legendItem(color: Color.green.opacity(0.82), label: "All habits")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 11, height: 11)
            Text(label)
        }
    }

    private func weekdayLetter(_ dayKey: String) -> String {
        guard let date = dateFromDayKey(dayKey) else { return "" }
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "EEEEE"
        return df.string(from: date)
    }

    private func dayNumber(_ dayKey: String) -> String {
        guard let d = dayKey.split(separator: "-").last else { return "" }
        return String(d)
    }

    private func dateFromDayKey(_ dayKey: String) -> Date? {
        let p = dayKey.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var dc = DateComponents()
        dc.year = p[0]
        dc.month = p[1]
        dc.day = p[2]
        return Calendar.current.date(from: dc)
    }

    private func formattedDay(_ dayKey: String) -> String {
        guard let d = dateFromDayKey(dayKey) else { return dayKey }
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: d)
    }

    private func accessibilitySummary(dayKey: String, allDone: Bool, future: Bool) -> String {
        if future { return "All habits, \(formattedDay(dayKey)), future day" }
        return "All habits, \(formattedDay(dayKey)), \(allDone ? "every habit completed" : "not all completed")"
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
