import SwiftUI
import Charts

// MARK: - Supporting Types

private enum AnalyticsRange: String, CaseIterable {
    case day   = "Day"
    case week  = "Week"
    case month = "Month"
    var days: Int {
        switch self {
        case .day:   return 1
        case .week:  return 7
        case .month: return 30
        }
    }
}

private enum ChartDisplayMode: String, CaseIterable {
    case combined  = "Combined"
    case separate  = "Separate"
}

private struct DayCompletion: Identifiable {
    let id        = UUID()
    let date:      Date
    let completed: Int
    let total:     Int
    var rate:    Double { total > 0 ? Double(completed) / Double(total) : 0 }
    var isEmpty: Bool   { total == 0 }
}

private struct Insight: Identifiable {
    enum Tone { case positive, warning }
    let id      = UUID()
    let icon:    String
    let message: String
    let tone:    Tone
}

// MARK: - AnalyticsView

struct AnalyticsView: View {
    let viewModel: HomeViewModel

    @State private var selectedRange: AnalyticsRange = .week
    @State private var selectedPetID: UUID? = nil
    @State private var weightChartMode: ChartDisplayMode = .combined
    @State private var heightChartMode: ChartDisplayMode = .combined
    @State private var medicineChartMode: ChartDisplayMode = .combined

    @AppStorage("weightUnit") private var weightUnitRaw = "kg"
    @AppStorage("heightUnit") private var heightUnitRaw = "cm"

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    private var heightUnit: HeightUnit { HeightUnit(rawValue: heightUnitRaw) ?? .cm }

    @State private var showingMedicineLog = false
    @State private var medicineLogPet: Pet? = nil

    private let calendar = Calendar.current

    // MARK: - Derived data

    private var rangeStart: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -(selectedRange.days - 1), to: today) ?? today
    }

    // Per-pet color palette for multi-series charts
    private static let petColors: [Color] = [.appPink, .blue, .orange, .purple, .teal, .indigo]
    private func petColor(at index: Int) -> Color {
        Self.petColors[index % Self.petColors.count]
    }
    private func petColor(for petID: UUID) -> Color {
        let index = viewModel.pets.firstIndex(where: { $0.id == petID }) ?? 0
        return petColor(at: index)
    }

    private var rangeItems: [ScheduleItem] {
        viewModel.scheduleItems.filter {
            $0.time >= rangeStart && (selectedPetID == nil || $0.pet.id == selectedPetID)
        }
    }

    private var completionByDay: [DayCompletion] {
        (0..<selectedRange.days).reversed().compactMap { offset in
            guard let day = calendar.date(
                byAdding: .day,
                value: -offset,
                to: calendar.startOfDay(for: .now)
            ) else { return nil }
            let items = rangeItems.filter { calendar.isDate($0.time, inSameDayAs: day) }
            return DayCompletion(
                date: day,
                completed: items.filter(\.isCompleted).count,
                total: items.count
            )
        }
    }

    private var overallRate: Double {
        let active = completionByDay.filter { !$0.isEmpty }
        guard !active.isEmpty else { return 0 }
        return active.map(\.rate).reduce(0, +) / Double(active.count)
    }

    private var insights: [Insight] {
        var list: [Insight] = []
        let allItems = viewModel.scheduleItems.filter {
            selectedPetID == nil || $0.pet.id == selectedPetID
        }

        guard !allItems.isEmpty else {
            return [Insight(
                icon: "calendar.badge.plus",
                message: "Add events to your schedule to start seeing insights here.",
                tone: .warning
            )]
        }

        let todayItems = allItems.filter { calendar.isDateInToday($0.time) }
        let todayDone  = todayItems.filter(\.isCompleted).count
        let todayTotal = todayItems.count

        if todayTotal > 0 && todayDone == todayTotal {
            list.append(Insight(
                icon: "checkmark.seal.fill",
                message: "All \(todayTotal) event\(todayTotal == 1 ? "" : "s") completed today!",
                tone: .positive
            ))
        } else if todayTotal > 0 && todayDone == 0 {
            list.append(Insight(
                icon: "exclamationmark.circle.fill",
                message: "\(todayTotal) event\(todayTotal == 1 ? "" : "s") scheduled today — none completed yet.",
                tone: .warning
            ))
        }

        let twoDaysAgo   = calendar.date(byAdding: .day, value: -2, to: .now) ?? .now
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recentPool   = allItems.filter { $0.time >= sevenDaysAgo }

        func matches(_ item: ScheduleItem, _ kws: [String]) -> Bool {
            let n = item.activityName.lowercased()
            return kws.contains { n.contains($0) }
        }

        let targetPets = selectedPetID != nil
            ? viewModel.pets.filter { $0.id == selectedPetID }
            : viewModel.pets

        for pet in targetPets {
            let petItems = recentPool.filter { $0.pet.id == pet.id }

            // Walk / run gap
            let walks = petItems.filter { matches($0, ["walk", "run"]) }
            if walks.count >= 3, let lastWalk = walks.map(\.time).max(), lastWalk < twoDaysAgo {
                let days = calendar.dateComponents([.day], from: lastWalk, to: .now).day ?? 0
                list.append(Insight(
                    icon: "figure.walk",
                    message: "\(pet.name) hasn't been walked in \(days) day\(days == 1 ? "" : "s").",
                    tone: .warning
                ))
            }

            // Feeding gap
            let feeds             = petItems.filter { matches($0, ["feed", "meal", "food", "eat"]) }
            let recentDoneFeeds   = feeds.filter { $0.isCompleted && $0.time >= twoDaysAgo }
            if feeds.count >= 3 && recentDoneFeeds.isEmpty {
                list.append(Insight(
                    icon: "fork.knife",
                    message: "\(pet.name)'s feeding hasn't been logged recently.",
                    tone: .warning
                ))
            }

            // Missed medications today
            let missedMeds = allItems.filter {
                matches($0, ["medic", "tablet", "pill"])
                    && $0.pet.id == pet.id
                    && calendar.isDateInToday($0.time)
                    && !$0.isCompleted
            }
            if !missedMeds.isEmpty {
                list.append(Insight(
                    icon: "pill.fill",
                    message: "\(pet.name) has \(missedMeds.count) missed medication\(missedMeds.count == 1 ? "" : "s") today.",
                    tone: .warning
                ))
            }
        }

        // Completion rate trend
        if completionByDay.count >= 4 {
            let half   = completionByDay.count / 2
            let recent = Array(completionByDay.suffix(half)).filter { !$0.isEmpty }
            let older  = Array(completionByDay.prefix(half)).filter { !$0.isEmpty }
            if !recent.isEmpty && !older.isEmpty {
                let rAvg = recent.map(\.rate).reduce(0, +) / Double(recent.count)
                let oAvg = older.map(\.rate).reduce(0, +)  / Double(older.count)
                if rAvg < oAvg - 0.20 {
                    list.append(Insight(
                        icon: "arrow.down.circle.fill",
                        message: "Completion rate is down \(Int((oAvg - rAvg) * 100))% compared to earlier in this period.",
                        tone: .warning
                    ))
                } else if rAvg > oAvg + 0.15 {
                    list.append(Insight(
                        icon: "arrow.up.circle.fill",
                        message: "Completion rate is up \(Int((rAvg - oAvg) * 100))% — momentum is building!",
                        tone: .positive
                    ))
                }
            }
        }

        if list.isEmpty {
            list.append(Insight(
                icon: "checkmark.circle.fill",
                message: "Everything looks on track. Keep it up!",
                tone: .positive
            ))
        }
        return list
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if viewModel.pets.count > 1 {
                        petFilterBar
                    }

                    Picker("Range", selection: $selectedRange) {
                        ForEach(AnalyticsRange.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.2), value: selectedRange)

                    summaryRow
                        .padding(.horizontal)

                    insightsSection
                        .padding(.horizontal)

                    Divider().padding(.horizontal)

                    completionSection
                        .padding(.horizontal)

                    weightSection
                        .padding(.horizontal)

                    heightSection
                        .padding(.horizontal)

                    medicineComplianceSection
                        .padding(.horizontal)

                    Spacer(minLength: 32)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingMedicineLog) {
            MedicineLogSheet(viewModel: viewModel, petFilter: medicineLogPet)
        }
    }

    // MARK: - Pet filter bar

    private var petFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Button {
                    withAnimation(.spring(duration: 0.25)) { selectedPetID = nil }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(selectedPetID == nil
                                      ? Color.appPink.opacity(0.15)
                                      : Color(.secondarySystemBackground))
                                .frame(width: 60, height: 60)
                            Image(systemName: "pawprint.fill")
                                .font(.title3)
                                .foregroundStyle(selectedPetID == nil ? Color.appPink : .secondary)
                        }
                        .overlay {
                            Circle()
                                .stroke(Color.appPink, lineWidth: 3)
                                .opacity(selectedPetID == nil ? 1 : 0)
                        }
                        Text("All")
                            .font(.caption.bold())
                            .foregroundStyle(selectedPetID == nil ? Color.appPink : .secondary)
                    }
                }
                .buttonStyle(.plain)

                ForEach(viewModel.pets) { pet in
                    let sel = selectedPetID == pet.id
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedPetID = sel ? nil : pet.id
                        }
                    } label: {
                        VStack(spacing: 6) {
                            PetAvatarView(pet: pet, size: 60)
                                .overlay {
                                    Circle()
                                        .stroke(Color.appPink, lineWidth: 3)
                                        .opacity(sel ? 1 : 0)
                                }
                                .scaleEffect(sel ? 1.08 : 1.0)
                            Text(pet.name)
                                .font(.caption.bold())
                                .foregroundStyle(sel ? Color.appPink : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }

    // MARK: - Summary stats row

    private var completionRateCaption: String {
        // Two short lines fit narrow columns; avoids single-line truncation ("…").
        switch selectedRange {
        case .day:   return "Today's\nscheduled tasks completed"
        case .week:  return "This week's\nscheduled tasks completed"
        case .month: return "This month's\nscheduled tasks completed"
        }
    }

    private var summaryRow: some View {
        let total = rangeItems.count
        let done  = rangeItems.filter(\.isCompleted).count

        return HStack(alignment: .top, spacing: 10) {
            miniStat(value: "\(Int(overallRate * 100))%", label: completionRateCaption, accent: rateColor(overallRate))
            miniStat(value: "\(done)/\(total)",           label: "Tasks done / scheduled", accent: .primary)
        }
    }

    private func miniStat(value: String, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.headline)

            ForEach(insights) { insight in
                HStack(spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.body.bold())
                        .foregroundStyle(insight.tone == .warning ? .orange : Color.appPink)
                        .frame(width: 28)
                    Text(insight.message)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(12)
                .background(
                    insight.tone == .warning
                        ? Color.orange.opacity(0.10)
                        : Color.appPink.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
        }
    }

    // MARK: - Completion rate chart

    private var completionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Completion Rate")
                .font(.headline)

            if completionByDay.allSatisfy(\.isEmpty) {
                emptyPlaceholder(icon: "chart.bar", text: "No scheduled events in this period.")
            } else {
                Chart(completionByDay) { day in
                    BarMark(
                        x: .value("Day",  day.date, unit: .day),
                        y: .value("Rate", day.isEmpty ? 0 : day.rate)
                    )
                    .foregroundStyle(
                        day.isEmpty
                            ? AnyShapeStyle(Color(.tertiarySystemFill))
                            : AnyShapeStyle(rateColor(day.rate).gradient)
                    )
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: selectedRange == .week ? 1 : 5)) { _ in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%").font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Weight trends

    @ViewBuilder
    private var weightSection: some View {
        let petsToShow: [Pet] = {
            if let id = selectedPetID, let p = viewModel.pets.first(where: { $0.id == id }) {
                return p.weightHistory.count >= 2 ? [p] : []
            }
            return viewModel.pets.filter { $0.weightHistory.count >= 2 }
        }()

        if !petsToShow.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                chartSectionHeader(
                    title: "Weight Trends",
                    mode: $weightChartMode,
                    showModeToggle: petsToShow.count > 1
                )

                if weightChartMode == .combined && petsToShow.count > 1 {
                    combinedWeightChart(pets: petsToShow)
                } else {
                    ForEach(petsToShow) { pet in
                        weightCard(for: pet, color: petColor(for: pet.id))
                    }
                }
            }
        }
    }

    private func combinedWeightChart(pets: [Pet]) -> some View {
        let allDisplayValues: [Double] = pets.flatMap { $0.weightHistory.map { weightUnit.displayValue(fromKg: $0.kg) } }
        let minY = (allDisplayValues.min() ?? 0) * 0.92
        let maxY = (allDisplayValues.max() ?? 1) * 1.08

        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(Array(pets.enumerated()), id: \.element.id) { idx, pet in
                    let sorted = pet.weightHistory.sorted { $0.date < $1.date }
                    ForEach(sorted) { e in
                        LineMark(
                            x: .value("Date", e.date),
                            y: .value(weightUnit.label, weightUnit.displayValue(fromKg: e.kg))
                        )
                        .foregroundStyle(by: .value("Pet", pet.name))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Date", e.date),
                            y: .value(weightUnit.label, weightUnit.displayValue(fromKg: e.kg))
                        )
                        .foregroundStyle(by: .value("Pet", pet.name))
                        .symbolSize(25)
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: pets.map(\.name),
                range: pets.enumerated().map { petColor(at: $0.offset) }
            )
            .chartLegend(position: .top, alignment: .leading)
            .chartYScale(domain: minY...maxY)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel {
                        if let v = v.as(Double.self) { Text(String(format: "%.1f", v)).font(.caption2) }
                    }
                }
            }
            .frame(height: 180)

            Divider().padding(.top, 4)
            ForEach(pets) { pet in
                if viewModel.pets.count > 1 {
                    HStack(spacing: 6) {
                        PetAvatarView(pet: pet, size: 18)
                        Text(pet.name).font(.caption.bold())
                    }
                    .padding(.top, 8)
                }
                historyTable(
                    rows: pet.weightHistory.sorted { $0.date > $1.date }
                        .map { (date: $0.date, value: weightUnit.formatValue($0.kg)) }
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func weightCard(for pet: Pet, color: Color) -> some View {
        let sorted = pet.weightHistory.sorted { $0.date < $1.date }
        let diff   = sorted.last!.kg - sorted.first!.kg
        let displayValues = sorted.map { weightUnit.displayValue(fromKg: $0.kg) }
        let minY   = (displayValues.min() ?? 0) * 0.92
        let maxY   = (displayValues.max() ?? 1) * 1.08

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(.subheadline.bold())
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diff >= 0 ? .orange : .green)
                    Text(weightUnit.formatChange(diff))
                        .foregroundStyle(diff >= 0 ? .orange : .green)
                    Text("· \(weightUnit.formatValue(sorted.last!.kg)) now")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.bold())
            }

            Chart(sorted) { e in
                let y = weightUnit.displayValue(fromKg: e.kg)
                LineMark(x: .value("Date", e.date), y: .value(weightUnit.label, y))
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Date", e.date),
                    yStart: .value("Min", minY),
                    yEnd: .value(weightUnit.label, y)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", e.date), y: .value(weightUnit.label, y))
                    .foregroundStyle(color)
                    .symbolSize(30)
            }
            .chartYScale(domain: minY...maxY)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel {
                        if let v = v.as(Double.self) {
                            Text(String(format: "%.1f", v)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 150)

            Divider().padding(.top, 4)
            historyTable(
                rows: sorted.reversed().map { (date: $0.date, value: weightUnit.formatValue($0.kg)) }
            )
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Height trends

    @ViewBuilder
    private var heightSection: some View {
        let petsToShow: [Pet] = {
            if let id = selectedPetID, let p = viewModel.pets.first(where: { $0.id == id }) {
                return p.heightHistory.count >= 2 ? [p] : []
            }
            return viewModel.pets.filter { $0.heightHistory.count >= 2 }
        }()

        if !petsToShow.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                chartSectionHeader(
                    title: "Height Trends",
                    mode: $heightChartMode,
                    showModeToggle: petsToShow.count > 1
                )

                if heightChartMode == .combined && petsToShow.count > 1 {
                    combinedHeightChart(pets: petsToShow)
                } else {
                    ForEach(petsToShow) { pet in
                        heightCard(for: pet, color: petColor(for: pet.id))
                    }
                }
            }
        }
    }

    private func combinedHeightChart(pets: [Pet]) -> some View {
        let allDisplayValues: [Double] = pets.flatMap { $0.heightHistory.map { heightUnit.displayValue(fromCm: $0.cm) } }
        let minY = (allDisplayValues.min() ?? 0) * 0.92
        let maxY = (allDisplayValues.max() ?? 1) * 1.08

        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(Array(pets.enumerated()), id: \.element.id) { idx, pet in
                    let sorted = pet.heightHistory.sorted { $0.date < $1.date }
                    ForEach(sorted) { e in
                        LineMark(
                            x: .value("Date", e.date),
                            y: .value(heightUnit.inputLabel, heightUnit.displayValue(fromCm: e.cm))
                        )
                        .foregroundStyle(by: .value("Pet", pet.name))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Date", e.date),
                            y: .value(heightUnit.inputLabel, heightUnit.displayValue(fromCm: e.cm))
                        )
                        .foregroundStyle(by: .value("Pet", pet.name))
                        .symbolSize(25)
                    }
                }
            }
            .chartForegroundStyleScale(
                domain: pets.map(\.name),
                range: pets.enumerated().map { petColor(at: $0.offset) }
            )
            .chartLegend(position: .top, alignment: .leading)
            .chartYScale(domain: minY...maxY)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel {
                        if let v = v.as(Double.self) { Text(String(format: "%.0f \(heightUnit.inputLabel)", v)).font(.caption2) }
                    }
                }
            }
            .frame(height: 180)

            Divider().padding(.top, 4)
            ForEach(pets) { pet in
                if viewModel.pets.count > 1 {
                    HStack(spacing: 6) {
                        PetAvatarView(pet: pet, size: 18)
                        Text(pet.name).font(.caption.bold())
                    }
                    .padding(.top, 8)
                }
                historyTable(
                    rows: pet.heightHistory.sorted { $0.date > $1.date }
                        .map { (date: $0.date, value: heightUnit.formatValue($0.cm)) }
                )
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func heightCard(for pet: Pet, color: Color) -> some View {
        let sorted = pet.heightHistory.sorted { $0.date < $1.date }
        let diff   = sorted.last!.cm - sorted.first!.cm
        let displayValues = sorted.map { heightUnit.displayValue(fromCm: $0.cm) }
        let minY   = (displayValues.min() ?? 0) * 0.92
        let maxY   = (displayValues.max() ?? 1) * 1.08

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(.subheadline.bold())
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diff >= 0 ? .orange : .green)
                    Text(heightUnit.formatChange(diff))
                        .foregroundStyle(diff >= 0 ? .orange : .green)
                    Text("· \(heightUnit.formatValue(sorted.last!.cm)) now")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.bold())
            }

            Chart(sorted) { e in
                let y = heightUnit.displayValue(fromCm: e.cm)
                LineMark(x: .value("Date", e.date), y: .value(heightUnit.inputLabel, y))
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Date", e.date),
                    yStart: .value("Min", minY),
                    yEnd: .value(heightUnit.inputLabel, y)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", e.date), y: .value(heightUnit.inputLabel, y))
                    .foregroundStyle(color)
                    .symbolSize(30)
            }
            .chartYScale(domain: minY...maxY)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel {
                        if let v = v.as(Double.self) {
                            Text(String(format: "%.0f", v)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 150)

            Divider().padding(.top, 4)
            historyTable(
                rows: sorted.reversed().map { (date: $0.date, value: heightUnit.formatValue($0.cm)) }
            )
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Medicine compliance

    private struct MedicineCompliancePoint: Identifiable {
        let id = UUID()
        let date: Date
        let petName: String
        let petID: UUID
        let accepted: Int
        let total: Int
        var rate: Double { total > 0 ? Double(accepted) / Double(total) : 0 }
    }

    private func medicineCompliance(for pet: Pet) -> [MedicineCompliancePoint] {
        let medItems = viewModel.scheduleItems.filter { $0.pet.id == pet.id && $0.isMedicineEvent }
        guard !medItems.isEmpty else { return [] }

        switch selectedRange {
        case .day:
            let todayItems = medItems.filter { calendar.isDateInToday($0.time) }
            guard !todayItems.isEmpty else { return [] }
            let accepted = todayItems.filter { $0.medicineAccepted == true }.count
            return [MedicineCompliancePoint(
                date: calendar.startOfDay(for: .now),
                petName: pet.name, petID: pet.id,
                accepted: accepted, total: todayItems.count
            )]

        case .week:
            // Always emit all 7 days so the line spans the full x-axis.
            // Days with no scheduled medicine are shown at 0% to keep the line continuous.
            return (0..<7).reversed().compactMap { offset -> MedicineCompliancePoint? in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)) else { return nil }
                let items = medItems.filter { calendar.isDate($0.time, inSameDayAs: day) }
                return MedicineCompliancePoint(
                    date: day, petName: pet.name, petID: pet.id,
                    accepted: items.filter { $0.medicineAccepted == true }.count,
                    total: items.count
                )
            }

        case .month:
            // Group by week — 5 windows to fill a 30-day range.
            return (0..<5).reversed().compactMap { weekOffset -> MedicineCompliancePoint? in
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfDay(for: .now)),
                      let weekEnd   = calendar.date(byAdding: .day, value: 7, to: weekStart)
                else { return nil }
                let items = medItems.filter { $0.time >= weekStart && $0.time < weekEnd }
                guard !items.isEmpty else { return nil }
                return MedicineCompliancePoint(
                    date: weekStart, petName: pet.name, petID: pet.id,
                    accepted: items.filter { $0.medicineAccepted == true }.count,
                    total: items.count
                )
            }
        }
    }

    @ViewBuilder
    private var medicineComplianceSection: some View {
        let petsWithMeds: [Pet] = {
            if let id = selectedPetID, let p = viewModel.pets.first(where: { $0.id == id }) {
                let hasMeds = viewModel.scheduleItems.contains { $0.pet.id == p.id && $0.isMedicineEvent }
                return hasMeds ? [p] : []
            }
            return viewModel.pets.filter { pet in
                viewModel.scheduleItems.contains { $0.pet.id == pet.id && $0.isMedicineEvent }
            }
        }()

        if !petsWithMeds.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                chartSectionHeader(
                    title: "Medicine Compliance",
                    mode: $medicineChartMode,
                    showModeToggle: petsWithMeds.count > 1
                )

                if medicineChartMode == .combined && petsWithMeds.count > 1 {
                    combinedMedicineChart(pets: petsWithMeds) {
                        medicineLogPet = nil
                        showingMedicineLog = true
                    }
                } else {
                    ForEach(petsWithMeds) { pet in
                        medicineCard(for: pet, color: petColor(for: pet.id)) {
                            medicineLogPet = pet
                            showingMedicineLog = true
                        }
                    }
                }
            }
        }
    }

    private func combinedMedicineChart(pets: [Pet], onViewLog: @escaping () -> Void) -> some View {
        let allPoints = pets.flatMap { medicineCompliance(for: $0) }

        return VStack(alignment: .leading, spacing: 8) {
            if allPoints.isEmpty {
                emptyPlaceholder(icon: "pill.fill", text: "No medicine events in this period.")
            } else {
                Chart {
                    ForEach(allPoints) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("Rate", p.rate)
                        )
                        .foregroundStyle(by: .value("Pet", p.petName))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("Rate", p.rate)
                        )
                        .foregroundStyle(by: .value("Pet", p.petName))
                        .symbolSize(25)
                    }
                }
                .chartForegroundStyleScale(
                    domain: pets.map(\.name),
                    range: pets.enumerated().map { petColor(at: $0.offset) }
                )
                .chartLegend(position: .top, alignment: .leading)
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: selectedRange == .week ? 7 : 4)) { _ in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel(
                            format: selectedRange == .month
                                ? .dateTime.month(.abbreviated).day()
                                : .dateTime.month(.abbreviated).day()
                        ).font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel {
                            if let d = v.as(Double.self) { Text("\(Int(d * 100))%").font(.caption2) }
                        }
                    }
                }
                .frame(height: 180)

                Button {
                    onViewLog()
                } label: {
                    HStack {
                        Spacer()
                        Label("View Full Log", systemImage: "list.bullet.clipboard")
                            .font(.caption.bold())
                            .foregroundStyle(Color.appPink)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func medicineCard(for pet: Pet, color: Color, onViewLog: @escaping () -> Void) -> some View {
        let points = medicineCompliance(for: pet)
        let avg = points.isEmpty ? 0.0 : points.map(\.rate).reduce(0, +) / Double(points.count)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(.subheadline.bold())
                }
                Spacer()
                Text("\(Int(avg * 100))% avg compliance")
                    .font(.caption.bold())
                    .foregroundStyle(rateColor(avg))
            }

            if points.isEmpty {
                Text("No medicine events in this period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Chart(points) { p in
                    AreaMark(
                        x: .value("Date", p.date),
                        yStart: .value("Min", 0.0),
                        yEnd: .value("Rate", p.rate)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.03)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Rate", p.rate)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Rate", p.rate)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: selectedRange == .week ? 7 : 4)) { _ in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel {
                            if let d = v.as(Double.self) { Text("\(Int(d * 100))%").font(.caption2) }
                        }
                    }
                }
                .frame(height: 150)

                Button {
                    onViewLog()
                } label: {
                    HStack {
                        Spacer()
                        Label("View Full Log", systemImage: "list.bullet.clipboard")
                            .font(.caption.bold())
                            .foregroundStyle(Color.appPink)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Shared chart section header

    private func chartSectionHeader(
        title: String,
        mode: Binding<ChartDisplayMode>,
        showModeToggle: Bool
    ) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if showModeToggle {
                Picker("", selection: mode) {
                    ForEach(ChartDisplayMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
        }
    }

    // MARK: - Helpers

    /// Renders a two-column (Date | Value) history table used for weight and height cards.
    private func historyTable(rows: [(date: Date, value: String)]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Value")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider()
                HStack {
                    Text(row.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(row.value)
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
            }
        }
    }

    private func rateColor(_ rate: Double) -> Color {
        rate >= 0.8 ? .green : rate >= 0.5 ? .orange : .red
    }

    private func emptyPlaceholder(icon: String, text: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(Color.appPink.opacity(0.4))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            Spacer()
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Medicine Log Sheet

struct MedicineLogSheet: View {
    let viewModel: HomeViewModel
    /// Initial pet selection when the sheet opens (`nil` = all pets).
    private let petFilter: Pet?

    @State private var selectedPetID: UUID?

    @AppStorage("timeFormat") private var timeFormatRaw = "12h"
    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current
    private var timeFormat: TimeFormat { TimeFormat(rawValue: timeFormatRaw) ?? .twelveHour }

    init(viewModel: HomeViewModel, petFilter: Pet?) {
        self.viewModel = viewModel
        self.petFilter = petFilter
        _selectedPetID = State(initialValue: petFilter?.id)
    }

    /// Pets that have at least one medicine event in the schedule.
    private var petsWithMedicine: [Pet] {
        viewModel.pets.filter { pet in
            viewModel.scheduleItems.contains { $0.pet.id == pet.id && $0.isMedicineEvent }
        }
    }

    private var showPetNameOnRows: Bool {
        selectedPetID == nil && petsWithMedicine.count > 1
    }

    private var medicineItems: [ScheduleItem] {
        viewModel.scheduleItems
            .filter { $0.isMedicineEvent }
            .filter { selectedPetID == nil || $0.pet.id == selectedPetID }
            .sorted { $0.time > $1.time }
    }

    /// All days from the earliest medicine event to today, newest first.
    /// Days with no events are included so the user can see the full history.
    private var allDays: [(date: Date, items: [ScheduleItem])] {
        guard let firstDate = medicineItems.map({ cal.startOfDay(for: $0.time) }).min() else { return [] }
        let today = cal.startOfDay(for: .now)
        let grouped = Dictionary(grouping: medicineItems) { cal.startOfDay(for: $0.time) }

        var result: [(date: Date, items: [ScheduleItem])] = []
        var current = today
        while current >= firstDate {
            result.append((date: current, items: (grouped[current] ?? []).sorted { $0.time < $1.time }))
            current = cal.date(byAdding: .day, value: -1, to: current) ?? current.addingTimeInterval(-86400)
        }
        return result
    }

    private var navigationTitle: String {
        if let id = selectedPetID, let name = viewModel.pets.first(where: { $0.id == id })?.name {
            return "\(name)'s Medicine Log"
        }
        return "Medicine Log"
    }

    var body: some View {
        NavigationStack {
            Group {
                if medicineItems.isEmpty {
                    ContentUnavailableView(
                        "No Medicine Events",
                        systemImage: "pill.fill",
                        description: Text("No medicine events have been logged yet.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if petsWithMedicine.count > 1 {
                                medicineLogPetPicker
                                    .padding(.bottom, 16)
                            }

                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(allDays, id: \.date) { group in
                                    medicineDayCard(group: group)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var medicineLogPetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                let allSelected = selectedPetID == nil
                Button {
                    HapticManager.impact(.light)
                    withAnimation(.spring(duration: 0.25)) { selectedPetID = nil }
                } label: {
                    Text("All pets")
                        .font(.subheadline.bold())
                        .foregroundStyle(allSelected ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(allSelected ? Color.appPink : Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)

                ForEach(petsWithMedicine) { pet in
                    let sel = selectedPetID == pet.id
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(.spring(duration: 0.25)) {
                            selectedPetID = sel ? nil : pet.id
                        }
                    } label: {
                        HStack(spacing: 8) {
                            PetAvatarView(pet: pet, size: 28)
                            Text(pet.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(sel ? .white : .primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(sel ? Color.appPink : Color(.secondarySystemGroupedBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private func medicineDayCard(group: (date: Date, items: [ScheduleItem])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if group.items.isEmpty {
                    HStack {
                        Text("No medicine scheduled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("—")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                } else {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        MedicineLogRow(
                            item: item,
                            showPetName: showPetNameOnRows,
                            timeFormat: timeFormat
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < group.items.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct MedicineLogRow: View {
    let item: ScheduleItem
    let showPetName: Bool
    let timeFormat: TimeFormat

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: statusIconName)
                    .font(.body.bold())
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.activityName)
                        .font(.subheadline.bold())
                    if showPetName {
                        Text("· \(item.pet.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(timeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(statusText)
                .font(.caption.bold())
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 2)
    }

    private var timeLabel: String {
        guard !item.isAllDay else { return "All day" }
        let f = DateFormatter()
        f.dateFormat = timeFormat.dateFormat
        return f.string(from: item.time).lowercased()
    }

    private var statusColor: Color {
        switch item.medicineAccepted {
        case true:  return .green
        case false: return .red
        case nil:   return item.isCompleted ? .orange : Color(.tertiaryLabel)
        }
    }

    private var statusIconName: String {
        switch item.medicineAccepted {
        case true:  return "checkmark"
        case false: return "xmark"
        case nil:   return item.isCompleted ? "checkmark.circle" : "clock"
        }
    }

    private var statusText: String {
        switch item.medicineAccepted {
        case true:  return "Yes — taken"
        case false: return "No — skipped"
        case nil:   return item.isCompleted ? "Done" : "Pending"
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(viewModel: .analyticsPreview)
}
