import SwiftUI

struct ScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel
    var petsViewModel: PetsViewModel

    @State private var showAddEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Scope", selection: $viewModel.scope) {
                    ForEach(ScheduleScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if viewModel.scope != .today {
                    periodChrome
                }

                Group {
                    switch viewModel.scope {
                    case .today:
                        ScheduleTodayPanel(viewModel: viewModel)
                    case .week:
                        ScheduleWeekPanel(viewModel: viewModel)
                    case .month:
                        ScheduleMonthPanel(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(scheduleBackground)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        showAddEvent = true
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddScheduleEventSheet(
                    scheduleViewModel: viewModel,
                    petsViewModel: petsViewModel,
                    onDismiss: { showAddEvent = false }
                )
            }
        }
        .preferredColorScheme(.light)
    }

    private var periodChrome: some View {
        VStack(spacing: 8) {
            Text(periodSubtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            HStack {
                Button {
                    stepPeriod(-1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Previous \(viewModel.scope.title.lowercased())")

                Spacer()

                Button("Today") {
                    viewModel.jumpAnchorToToday()
                }
                .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    stepPeriod(1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("Next \(viewModel.scope.title.lowercased())")
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 6)
    }

    private var periodSubtitle: String {
        let cal = Calendar.current
        switch viewModel.scope {
        case .today:
            return ""
        case .week:
            guard let interval = viewModel.weekInterval else { return "" }
            let endDay = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            let y = DateFormatter()
            y.dateFormat = "yyyy"
            let startStr = f.string(from: interval.start)
            let endStr = f.string(from: endDay)
            let yearStr = y.string(from: interval.start)
            if cal.isDate(interval.start, equalTo: endDay, toGranularity: .year) {
                return "\(startStr) – \(endStr), \(yearStr)"
            }
            return "\(startStr) – \(endStr)"
        case .month:
            let f = DateFormatter()
            f.dateFormat = "LLLL yyyy"
            return f.string(from: viewModel.anchorDate)
        }
    }

    private func stepPeriod(_ delta: Int) {
        switch viewModel.scope {
        case .today:
            break
        case .week:
            viewModel.shiftWeek(by: delta)
        case .month:
            viewModel.shiftMonth(by: delta)
        }
    }

    private var scheduleBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.98, blue: 1.0),
                Color(red: 0.93, green: 0.96, blue: 0.99),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Today

private struct ScheduleTodayPanel: View {
    var viewModel: ScheduleViewModel

    var body: some View {
        Group {
            if viewModel.eventsToday.isEmpty {
                ContentUnavailableView(
                    "Nothing scheduled",
                    systemImage: "calendar",
                    description: Text("Tap + to add an event and choose a pet or All pets.")
                )
            } else {
                List {
                    ForEach(viewModel.eventsToday) { event in
                        ScheduleEventRow(event: event)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteEvent(id: event.id)
                                }
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteEvent(id: viewModel.eventsToday[index].id)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: - Week

private struct ScheduleWeekPanel: View {
    var viewModel: ScheduleViewModel

    var body: some View {
        let days = viewModel.daysInDisplayedWeek
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(days, id: \.self) { day in
                    ScheduleDayBucket(day: day, events: viewModel.events(on: day)) { id in
                        viewModel.deleteEvent(id: id)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

private struct ScheduleDayBucket: View {
    let day: Date
    let events: [ScheduleEvent]
    var onDeleteEvent: (UUID) -> Void

    private var header: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Calendar.current.isDateInToday(day) ? Color.accentColor : .primary)

            if events.isEmpty {
                Text("No events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        ScheduleEventRow(event: event, compact: true)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    onDeleteEvent(event.id)
                                }
                            }
                        if index < events.count - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }
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
    }
}

// MARK: - Month

private struct ScheduleMonthPanel: View {
    var viewModel: ScheduleViewModel

    @State private var selectedDate: Date = Date()

    var body: some View {
        let headers = weekdaySymbols()
        let cells = viewModel.monthGridDays()
        let dayEvents = viewModel.events(on: selectedDate)
        let rows = stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<min(start + 7, cells.count)])
        }

        ScrollView {
            // Non-lazy grid avoids self-sizing loops with nested collection-style layouts.
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, sym in
                        Text(sym)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            ScheduleMonthDayCell(
                                date: cell,
                                viewModel: viewModel,
                                selectedDate: selectedDate,
                                onSelect: { selectedDate = $0 }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            monthDayAgenda(selectedDate: selectedDate, events: dayEvents)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 20)
        }
        .onAppear {
            alignSelectedDateToDisplayedMonth()
        }
        .onChange(of: viewModel.anchorDate) { _, _ in
            alignSelectedDateToDisplayedMonth()
        }
    }

    private func alignSelectedDateToDisplayedMonth() {
        let cal = Calendar.current
        guard let interval = viewModel.monthInterval else { return }
        if cal.isDate(selectedDate, equalTo: interval.start, toGranularity: .month) {
            return
        }
        let today = Date()
        if cal.isDate(today, equalTo: interval.start, toGranularity: .month) {
            selectedDate = today
        } else {
            selectedDate = interval.start
        }
    }

    @ViewBuilder
    private func monthDayAgenda(selectedDate: Date, events: [ScheduleEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthDayHeader(for: selectedDate))
                .font(.headline.weight(.semibold))
            if events.isEmpty {
                Text("Nothing scheduled this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        ScheduleEventRow(event: event, compact: true)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteEvent(id: event.id)
                                }
                            }
                        if index < events.count - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                )
            }
        }
    }

    private func monthDayHeader(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private func weekdaySymbols() -> [String] {
        let cal = Calendar.current
        let syms = cal.shortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return (0..<7).map { syms[(first + $0) % syms.count] }
    }
}

private struct ScheduleMonthDayCell: View {
    let date: Date?
    var viewModel: ScheduleViewModel
    var selectedDate: Date
    var onSelect: (Date) -> Void

    var body: some View {
        Group {
            if let date {
                let cal = Calendar.current
                let day = cal.component(.day, from: date)
                let today = cal.isDateInToday(date)
                let has = viewModel.hasEvents(on: date)
                let selected = cal.isDate(date, inSameDayAs: selectedDate)

                let fill: Color = {
                    if selected { return Color.accentColor.opacity(0.26) }
                    if today { return Color.accentColor.opacity(0.12) }
                    return Color.white.opacity(0.45)
                }()

                Button {
                    onSelect(date)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(day)")
                            .font(.subheadline.weight(today || selected ? .bold : .regular))
                            .foregroundStyle(selected || today ? Color.accentColor : .primary)
                        if has {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                        } else {
                            Color.clear.frame(width: 5, height: 5)
                        }
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
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }
}

// MARK: - Row

private struct ScheduleEventRow: View {
    let event: ScheduleEvent
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: event.symbolName)
                .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.45, blue: 0.85))
                .frame(width: compact ? 22 : 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(compact ? .caption.weight(.medium) : .body.weight(.medium))
                Text(event.petLabel)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.tertiary)
                Text(event.timeString())
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 6 : 10)
    }
}

// MARK: - Add event

private enum ScheduleGlyph: String, CaseIterable, Identifiable {
    case walk = "figure.walk"
    case meal = "leaf.fill"
    case vet = "cross.case.fill"
    case meds = "pills.fill"
    case training = "graduationcap.fill"
    case groom = "sparkles"
    case play = "hare.fill"
    case weigh = "scalemass.fill"
    case other = "calendar"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk: "Walk"
        case .meal: "Meal"
        case .vet: "Vet"
        case .meds: "Medicine"
        case .training: "Training"
        case .groom: "Grooming"
        case .play: "Play / social"
        case .weigh: "Weigh-in"
        case .other: "Other"
        }
    }
}

private struct AddScheduleEventSheet: View {
    var scheduleViewModel: ScheduleViewModel
    var petsViewModel: PetsViewModel
    var onDismiss: () -> Void

    @State private var titleText = ""
    @State private var startTime = Date()
    @State private var glyph: ScheduleGlyph = .walk
    @State private var selectedPetId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pet", selection: $selectedPetId) {
                        Text("All pets").tag(nil as UUID?)
                        ForEach(petsViewModel.pets) { pet in
                            Text(petDisplayName(pet)).tag(Optional(pet.id))
                        }
                    }
                    if petsViewModel.pets.isEmpty {
                        Text("Add pets under the Pets tab to assign this event to a specific animal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Animal")
                }

                Section {
                    TextField("Title", text: $titleText)
                    DatePicker("Date & time", selection: $startTime)
                    Picker("Type", selection: $glyph) {
                        ForEach(ScheduleGlyph.allCases) { g in
                            Label(g.label, systemImage: g.rawValue).tag(g)
                        }
                    }
                } header: {
                    Text("Event")
                }
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let pet = petsViewModel.pets.first { $0.id == selectedPetId }
                        scheduleViewModel.addEvent(
                            title: titleText,
                            startTime: startTime,
                            symbolName: glyph.rawValue,
                            pet: pet
                        )
                        onDismiss()
                    }
                    .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func petDisplayName(_ pet: PetProfile) -> String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Unnamed pet" : n
    }
}

#Preview("Schedule") {
    ScheduleView(viewModel: ScheduleViewModel(), petsViewModel: PetsViewModel())
}
