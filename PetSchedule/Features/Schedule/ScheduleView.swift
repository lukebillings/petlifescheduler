import SwiftUI

struct ScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel

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
                    description: Text("No events today.")
                )
            } else {
                List {
                    ForEach(viewModel.eventsToday) { event in
                        ScheduleEventRow(event: event)
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
                    ScheduleDayBucket(day: day, events: viewModel.events(on: day))
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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let headers = weekdaySymbols()
        let cells = viewModel.monthGridDays()
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, sym in
                    Text(sym)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    ScheduleMonthDayCell(date: cell, viewModel: viewModel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
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

    var body: some View {
        Group {
            if let date {
                let day = Calendar.current.component(.day, from: date)
                let today = Calendar.current.isDateInToday(date)
                let has = viewModel.hasEvents(on: date)
                VStack(spacing: 4) {
                    Text("\(day)")
                        .font(.subheadline.weight(today ? .bold : .regular))
                        .foregroundStyle(today ? Color.accentColor : .primary)
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
                        .fill(today ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.45))
                )
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
                Text(event.timeString())
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 6 : 10)
    }
}

#Preview("Schedule") {
    ScheduleView(viewModel: ScheduleViewModel())
}
