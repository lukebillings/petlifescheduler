import SwiftUI
import Charts

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
                    HabitMonthCalendarView(trackStore: trackStore)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
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
                    Text("Full month: tap a day to see habits below the grid. Dot colors — green: all done, orange: some done, red: none, gray: future. Use arrows to change month.")
                }

                Section {
                    Button {
                        showLogWellness = true
                    } label: {
                        Label("Log state", systemImage: "heart.text.square.fill")
                    }
                    if trackStore.wellnessLogs.isEmpty {
                        Text("Log energy, mood, and optional weight (kg) and height (cm) over time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(wellnessByPet, id: \.bucketKey) { bucket in
                            WellnessPetStateCharts(
                                displayName: bucket.displayName,
                                logsOldestFirst: bucket.logs,
                                onDeleteLog: { trackStore.deleteWellnessLog(id: $0) }
                            )
                            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            .listRowSeparator(.hidden)
                        }
                    }
                } header: {
                    Label("States", systemImage: "heart.text.square")
                } footer: {
                    if !trackStore.wellnessLogs.isEmpty {
                        Text("Charts group logs by pet. Weight and height charts appear when you log those fields. Open Log history on a card to delete entries.")
                    }
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

    /// One row per pet (or “unspecified”), logs chronological for chart X-axis.
    private var wellnessByPet: [(bucketKey: String, displayName: String, logs: [WellnessStateLog])] {
        var map: [String: (displayName: String, logs: [WellnessStateLog])] = [:]
        for log in trackStore.wellnessLogs {
            let trimmed = log.petName.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.isEmpty ? "_" : trimmed.lowercased()
            let display = trimmed.isEmpty ? "Pet (unspecified)" : trimmed
            if var existing = map[key] {
                existing.logs.append(log)
                map[key] = existing
            } else {
                map[key] = (display, [log])
            }
        }
        return map
            .map { key, value in
                (bucketKey: key, displayName: value.displayName, logs: value.logs.sorted { $0.recordedAt < $1.recordedAt })
            }
            .sorted { a, b in
                if a.bucketKey == "_" { return false }
                if b.bucketKey == "_" { return true }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
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

}

// MARK: - Wellness charts (per pet)

private struct WellnessPetStateCharts: View {
    var displayName: String
    /// Oldest → newest for readable left-to-right charts.
    var logsOldestFirst: [WellnessStateLog]
    var onDeleteLog: (UUID) -> Void

    @State private var showLogHistory = false

    private var historyNewestFirst: [WellnessStateLog] {
        logsOldestFirst.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(displayName)
                .font(.headline.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Label("Energy", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                wellnessLineChart(
                    logs: logsOldestFirst,
                    yField: "Energy",
                    value: { WellnessOptions.energyIndex($0.energy) },
                    yDomain: 0 ... Double(WellnessOptions.energyLevels.count - 1),
                    yLabels: WellnessOptions.energyLevels,
                    lineColor: .orange
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Mood", systemImage: "face.smiling")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                wellnessLineChart(
                    logs: logsOldestFirst,
                    yField: "Mood",
                    value: { WellnessOptions.happinessIndex($0.happiness) },
                    yDomain: 0 ... Double(WellnessOptions.happinessLevels.count - 1),
                    yLabels: WellnessOptions.happinessLevels,
                    lineColor: .purple
                )
            }

            if logsOldestFirst.contains(where: { $0.weightKg != nil }) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Weight", systemImage: "scalemass.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    measurementLineChart(
                        logs: logsOldestFirst.filter { $0.weightKg != nil },
                        yField: "kg",
                        keyPath: \.weightKg,
                        lineColor: .teal
                    )
                }
            }

            if logsOldestFirst.contains(where: { $0.heightCm != nil }) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Height", systemImage: "ruler.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    measurementLineChart(
                        logs: logsOldestFirst.filter { $0.heightCm != nil },
                        yField: "cm",
                        keyPath: \.heightCm,
                        lineColor: .indigo
                    )
                }
            }

            Button {
                showLogHistory.toggle()
            } label: {
                HStack {
                    Text("Log history")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showLogHistory ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if showLogHistory {
                ForEach(historyNewestFirst) { log in
                    wellnessHistoryRow(log)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                onDeleteLog(log.id)
                            }
                        }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func wellnessLineChart(
        logs: [WellnessStateLog],
        yField: String,
        value: @escaping (WellnessStateLog) -> Double,
        yDomain: ClosedRange<Double>,
        yLabels: [String],
        lineColor: Color
    ) -> some View {
        Chart {
            ForEach(logs) { log in
                LineMark(
                    x: .value("Time", log.recordedAt),
                    y: .value(yField, value(log))
                )
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Time", log.recordedAt),
                    y: .value(yField, value(log))
                )
            }
        }
        .foregroundStyle(lineColor)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(logs.count, 5))) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day().hour().minute())
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(values: (0 ..< yLabels.count).map(Double.init)) { v in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let i = v.as(Int.self), yLabels.indices.contains(i) {
                        Text(yLabels[i])
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 140)
    }

    private func measurementLineChart(
        logs: [WellnessStateLog],
        yField: String,
        keyPath: KeyPath<WellnessStateLog, Double?>,
        lineColor: Color
    ) -> some View {
        Chart {
            ForEach(logs) { log in
                if let y = log[keyPath: keyPath] {
                    LineMark(
                        x: .value("Time", log.recordedAt),
                        y: .value(yField, y)
                    )
                    .interpolationMethod(.monotone)
                    PointMark(
                        x: .value("Time", log.recordedAt),
                        y: .value(yField, y)
                    )
                }
            }
        }
        .foregroundStyle(lineColor)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(logs.count, 5))) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day().hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading)
        }
        .frame(height: 140)
    }

    private func wellnessHistoryRow(_ log: WellnessStateLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.medium))
                Spacer()
            }
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label(log.energy, systemImage: "bolt.fill")
                    .font(.caption)
                Label(log.happiness, systemImage: "face.smiling")
                    .font(.caption)
            }
            if log.weightKg != nil || log.heightCm != nil {
                HStack(spacing: 12) {
                    if let w = log.weightKg {
                        Label(String(format: "%.1f kg", w), systemImage: "scalemass.fill")
                            .font(.caption)
                    }
                    if let h = log.heightCm {
                        Label(String(format: "%.1f cm", h), systemImage: "ruler.fill")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Habit month calendar

private struct HabitMonthCalendarView: View {
    var trackStore: TrackStore

    private var cal: Calendar { .current }

    @State private var anchorMonth: Date = HabitMonthCalendarView.startOfMonth(for: Date())
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthChrome
            // Eager VStack/HStack grid avoids LazyVGrid-in-List layout feedback loops (UICollectionView).
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(weekdaySymbols().enumerated()), id: \.offset) { _, sym in
                        Text(sym)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(cellRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            dayCell(date: cell)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            selectedDayAgenda
            legendRow
        }
        .padding(.vertical, 6)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { alignSelectionToMonth() }
        .onChange(of: anchorMonth) { _, _ in alignSelectionToMonth() }
    }

    private var cells: [Date?] {
        TrackStore.monthGridCells(forMonthContaining: anchorMonth, calendar: cal)
    }

    private var cellRows: [[Date?]] {
        stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }
    }

    private var monthChrome: some View {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return HStack {
            Button { stepMonth(-1) } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(df.string(from: anchorMonth))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { stepMonth(1) } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func stepMonth(_ delta: Int) {
        let start = Self.startOfMonth(for: anchorMonth)
        anchorMonth = cal.date(byAdding: .month, value: delta, to: start) ?? start
    }

    private func alignSelectionToMonth() {
        guard let interval = cal.dateInterval(of: .month, for: anchorMonth) else { return }
        if cal.isDate(selectedDate, equalTo: interval.start, toGranularity: .month) {
            return
        }
        let today = Date()
        if cal.isDate(today, equalTo: interval.start, toGranularity: .month) {
            selectedDate = cal.startOfDay(for: today)
        } else {
            selectedDate = interval.start
        }
    }

    private func weekdaySymbols() -> [String] {
        let syms = cal.shortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return (0..<7).map { syms[(first + $0) % syms.count] }
    }

    @ViewBuilder
    private func dayCell(date: Date?) -> some View {
        if let date {
            let state = trackStore.habitCalendarDayState(for: date)
            let selected = cal.isDate(date, inSameDayAs: selectedDate)
            let today = cal.isDateInToday(date)
            let dayNum = cal.component(.day, from: date)

            let fill: Color = {
                if selected { return Color.accentColor.opacity(0.26) }
                if today { return Color.accentColor.opacity(0.12) }
                return Color.white.opacity(0.45)
            }()

            Button {
                selectedDate = cal.startOfDay(for: date)
            } label: {
                VStack(spacing: 4) {
                    Text("\(dayNum)")
                        .font(.subheadline.weight(today || selected ? .bold : .regular))
                        .foregroundStyle(selected || today ? Color.accentColor : .primary)
                    Circle()
                        .fill(indicatorColor(state))
                        .frame(width: 6, height: 6)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityDayLabel(date: date, state: state))
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func indicatorColor(_ state: HabitCalendarDayState) -> Color {
        switch state {
        case .future: return Color.gray.opacity(0.45)
        case .noHabits: return Color.secondary.opacity(0.22)
        case .allComplete: return Color.green.opacity(0.85)
        case .partial: return Color.orange.opacity(0.9)
        case .missed: return Color.red.opacity(0.55)
        }
    }

    private func accessibilityDayLabel(date: Date, state: HabitCalendarDayState) -> String {
        let header = monthDayHeader(for: date)
        switch state {
        case .future: return "\(header), future"
        case .noHabits: return "\(header), no habits"
        case .allComplete: return "\(header), all habits done"
        case .partial: return "\(header), some habits done"
        case .missed: return "\(header), no habits done"
        }
    }

    private var selectedDayAgenda: some View {
        let key = TrackStore.dayKey(for: selectedDate, calendar: cal)
        let future = trackStore.isFutureDayKey(key)

        return VStack(alignment: .leading, spacing: 10) {
            Text(monthDayHeader(for: selectedDate))
                .font(.headline.weight(.semibold))

            if trackStore.habits.isEmpty {
                Text("Add a habit below to see it in this calendar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if future {
                Text("Future day — you can check off habits when that day arrives.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                allHabitsSummaryRow(dayKey: key)
                ForEach(trackStore.habits) { habit in
                    habitAgendaRow(habit: habit, dayKey: key)
                }
            }
        }
        .padding(.top, 4)
    }

    private func allHabitsSummaryRow(dayKey: String) -> some View {
        let all = trackStore.allHabitsCompleted(on: dayKey)
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(all ? Color.green.opacity(0.75) : Color.red.opacity(0.45))
                .frame(width: 12, height: 12)
            Text("All habits")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(all ? "Complete" : "Incomplete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func habitAgendaRow(habit: HabitTrack, dayKey: String) -> some View {
        let done = habit.isCompleted(on: dayKey)
        return Button {
            trackStore.toggleHabit(id: habit.id, onDayKey: dayKey)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(done ? Color.green : Color.secondary.opacity(0.45))
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if !habit.detail.isEmpty {
                        Text(habit.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private func monthDayHeader(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private var legendRow: some View {
        HStack(spacing: 10) {
            legendDot(color: Color.green.opacity(0.85), label: "All")
            legendDot(color: Color.orange.opacity(0.9), label: "Some")
            legendDot(color: Color.red.opacity(0.55), label: "None")
            legendDot(color: Color.gray.opacity(0.45), label: "Future")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    private static func startOfMonth(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
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
    @State private var weightText: String = ""
    @State private var heightText: String = ""

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

                Section {
                    TextField("Weight (kg)", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("Height (cm)", text: $heightText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Size (optional)")
                } footer: {
                    Text("Add a snapshot to plot weight and height over time in States.")
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
                        trackStore.addWellnessLog(
                            petName: petName,
                            energy: energy,
                            happiness: happiness,
                            weightKg: Self.parseDouble(weightText),
                            heightCm: Self.parseDouble(heightText)
                        )
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

    private static func parseDouble(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }
}

#Preview("Track") {
    TrackView(trackStore: TrackStore(), petsViewModel: PetsViewModel())
}
