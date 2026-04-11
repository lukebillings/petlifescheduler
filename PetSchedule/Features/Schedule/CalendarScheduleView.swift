import SwiftUI

struct CalendarScheduleView: View {
    @Bindable var viewModel: HomeViewModel

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 20) {
            // Month navigation header
            HStack {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.selectedCalendarDate = calendar.date(
                            byAdding: .month, value: -1, to: viewModel.selectedCalendarDate
                        ) ?? viewModel.selectedCalendarDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.bold())
                        .padding(10)
                        .glassEffect(in: Circle())
                }

                Spacer()

                Text(viewModel.selectedCalendarDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.bold())

                Spacer()

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        viewModel.selectedCalendarDate = calendar.date(
                            byAdding: .month, value: 1, to: viewModel.selectedCalendarDate
                        ) ?? viewModel.selectedCalendarDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.bold())
                        .padding(10)
                        .glassEffect(in: Circle())
                }
            }
            .padding(.horizontal)

            // Weekday symbols
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Day grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date {
                        CalendarDayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: viewModel.selectedCalendarDate),
                            isToday: calendar.isDateInToday(date),
                            hasItems: !viewModel.items(for: date).isEmpty
                        ) {
                            withAnimation(.spring(duration: 0.2)) {
                                viewModel.selectedCalendarDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal)

            // Items for selected date
            let selectedItems = viewModel.items(for: viewModel.selectedCalendarDate)
            if !selectedItems.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(viewModel.selectedCalendarDate.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.headline)

                        Spacer()
                    }
                    .padding(.horizontal)

                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            ForEach(selectedItems) { item in
                                ScheduleRowView(item: item) {
                                    viewModel.toggleCompletion(for: item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ContentUnavailableView(
                    "No activities",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("Nothing scheduled for this day.")
                )
                .padding(.vertical, 20)
            }
        }
    }

    private var weekdayLabels: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1
        return Array(symbols[firstWeekday...] + symbols[..<firstWeekday])
            .map { String($0.prefix(1)) }
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: viewModel.selectedCalendarDate) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - calendar.firstWeekday
        let leadingBlanks = (firstWeekday + 7) % 7
        let daysCount = calendar.range(of: .day, in: .month, for: viewModel.selectedCalendarDate)?.count ?? 0

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysCount {
            days.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return days
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasItems: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.callout.bold())
                    .foregroundStyle(isSelected ? Color.white : isToday ? Color.appPink : Color.primary)
                    .frame(width: 34, height: 34)
                    .background(
                        Group {
                            if isSelected {
                                Circle().fill(Color.appPink)
                            } else if isToday {
                                Circle().stroke(Color.appPink, lineWidth: 1.5)
                            }
                        }
                    )

                if hasItems {
                    Circle()
                        .fill(isSelected ? Color.white : Color.appPink)
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScrollView {
        CalendarScheduleView(viewModel: HomeViewModel.preview)
            .padding(.top)
    }
}
