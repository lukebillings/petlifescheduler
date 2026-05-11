import SwiftUI
import Charts
import UIKit

// MARK: - Supporting Types

private enum AnalyticsRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    /// Caps Chart X automatic ticks so labels stay readable on phone widths.
    var chartXAxisDesiredCount: Int {
        switch self {
        case .week: return 7
        case .month: return 5
        case .year: return 6
        }
    }

    var chartXAxisDateFormat: Date.FormatStyle {
        switch self {
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.month(.abbreviated).day(.defaultDigits)
        case .year: return .dateTime.month(.abbreviated)
        }
    }
}

private struct ComplianceLogSheetPayload: Identifiable {
    let kind: ScheduleComplianceKind
    let pet: Pet?
    var id: String { "\(kind)-\(pet?.id.uuidString ?? "all")" }
}

/// Opens `PetDetailSheet` from Analytics with an optional scroll target (Weight / Height).
private struct AnalyticsPetProfileLaunch: Identifiable {
    let id = UUID()
    let pet: Pet
    let initialScrollAnchor: PetDetailSheet.InitialScrollAnchor
}

/// Dots under swipeable trend carousels; tracks `page` as the user swipes.
private struct PetSwipePageIndicator: View {
    let count: Int
    let page: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == page ? Color(uiColor: .systemGray) : Color(uiColor: .systemGray5))
                    .frame(width: i == page ? 8 : 6, height: i == page ? 8 : 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pet chart page \(min(page + 1, count)) of \(count)")
    }
}

/// Horizontal swipe between pets for a single chart type (one full-width card per page).
private struct PetSwipePager<Content: View>: View {
    let pets: [Pet]
    @Binding var page: Int
    /// Height of each paged tab; short cards (e.g. compliance) should use a smaller value to avoid a tall empty band above the dots.
    var pageHeight: CGFloat = AnalyticsSwipeLayout.pageHeight
    @ViewBuilder let content: (Pet) -> Content

    var body: some View {
        Group {
            if pets.isEmpty {
                EmptyView()
            } else if pets.count == 1, let only = pets.first {
                content(only)
            } else {
                VStack(spacing: AnalyticsSwipeLayout.dotsSpacingFromPager) {
                    TabView(selection: $page) {
                        ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                            ScrollView {
                                content(pet)
                            }
                            .scrollBounceBehavior(.basedOnSize, axes: [.vertical])
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: pageHeight)

                    PetSwipePageIndicator(count: pets.count, page: page)
                }
            }
        }
        .onChange(of: pets.map(\.id)) { _, _ in page = 0 }
    }
}

/// Shared metrics so every trend carousel matches: same pager height + same gap above the dots.
private enum AnalyticsSwipeLayout {
    /// Tall sections (weight / height / mood) include a chart plus history table.
    static let pageHeight: CGFloat = 400
    /// Compliance charts are shorter (no history table); a smaller pager avoids a large blank strip above the dots.
    static let compliancePageHeight: CGFloat = 300
    /// Space between the bottom of the paged area and the page-indicator dots (all sections).
    static let dotsSpacingFromPager: CGFloat = 8
}

/// Quick-jump targets for the analytics pill bar (matches `.id` on each anchored block).
private enum AnalyticsJumpSection: String, CaseIterable, Hashable {
    case summary
    case weight
    case height
    case mood
    case medicine
    case feed
    case water

    var pillTitle: String {
        switch self {
        case .summary: return "Pets"
        case .weight: return "Weight"
        case .height: return "Height"
        case .mood: return "Mood"
        case .medicine: return "Medicine"
        case .feed: return "Feeding"
        case .water: return "Water"
        }
    }

    var pillSymbol: String {
        switch self {
        case .summary: return "pawprint.fill"
        case .weight: return "scalemass.fill"
        case .height: return "ruler.fill"
        case .mood: return "face.smiling"
        case .medicine: return "pill.fill"
        case .feed: return "fork.knife"
        case .water: return "drop.fill"
        }
    }

    static func compliance(_ kind: ScheduleComplianceKind) -> AnalyticsJumpSection {
        switch kind {
        case .medicine: return .medicine
        case .feed: return .feed
        case .water: return .water
        }
    }
}

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @Bindable var viewModel: HomeViewModel

    @AppStorage("pinkWaveHeaderEnabled") private var pinkWaveHeaderEnabled = true

    @State private var selectedRange: AnalyticsRange = .week
    @State private var selectedPetID: UUID? = nil
    @State private var selectedAnalyticsJumpSection: AnalyticsJumpSection?

    @State private var weightSwipePage = 0
    @State private var heightSwipePage = 0
    @State private var moodSwipePage = 0
    @State private var complianceSwipeMedicine = 0
    @State private var complianceSwipeFeed = 0
    @State private var complianceSwipeWater = 0

    /// Opens the pet editor from Analytics empty-state CTAs (weight / height), scrolled to the right section.
    @State private var analyticsPetProfileLaunch: AnalyticsPetProfileLaunch?

    @AppStorage("weightUnit") private var weightUnitRaw = "kg"
    @AppStorage("heightUnit") private var heightUnitRaw = "cm"

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    private var heightUnit: HeightUnit { HeightUnit(rawValue: heightUnitRaw) ?? .cm }

    @State private var complianceLogSheet: ComplianceLogSheetPayload?

    /// Opens Add Log from mood empty-state CTA (pet pre-selected).
    @State private var addLogSheetPet: Pet?

    /// Opens Add Event with a preset activity matching medicine / feeding / water compliance.
    @State private var addEventCompliancePayload: AddEventCompliancePayload?

    private struct AddEventCompliancePayload: Identifiable {
        let id = UUID()
        let pet: Pet
        let presetActivity: String
    }

    private let calendar = Calendar.current

    // MARK: - Derived data

    private var rangeStart: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -(selectedRange.days - 1), to: today) ?? today
    }

    /// Exclusive upper bound for analytics windows (start of tomorrow).
    private var rangeExclusiveEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
            ?? Date.now.addingTimeInterval(86_400)
    }

    /// Inclusive chart domain end so scales match the selected period.
    private var chartDomainEndInclusive: Date {
        rangeExclusiveEnd.addingTimeInterval(-1)
    }

    private var chartXDateDomain: ClosedRange<Date> {
        rangeStart...chartDomainEndInclusive
    }

    private func startOfMonth(for date: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
    }

    private func filteredWeightEntries(for pet: Pet) -> [WeightEntry] {
        pet.weightHistory
            .filter { $0.date >= rangeStart && $0.date < rangeExclusiveEnd }
            .sorted { $0.date < $1.date }
    }

    private func filteredHeightEntries(for pet: Pet) -> [HeightEntry] {
        pet.heightHistory
            .filter { $0.date >= rangeStart && $0.date < rangeExclusiveEnd }
            .sorted { $0.date < $1.date }
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

    /// Pets included when choosing **All** vs a single avatar filter.
    private var petsForAnalyticsContext: [Pet] {
        if let id = selectedPetID, let p = viewModel.pets.first(where: { $0.id == id }) {
            return [p]
        }
        return viewModel.pets
    }

    private var visibleAnalyticsJumpSections: [AnalyticsJumpSection] {
        var list: [AnalyticsJumpSection] = []
        if viewModel.pets.count > 1 {
            list.append(.summary)
        }
        guard !viewModel.pets.isEmpty else { return list }
        list.append(contentsOf: [.weight, .height, .mood, .medicine, .feed, .water])
        return list
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    PinkWaveScreenHeader("Analytics", accessory: {
                        Picker("Chart time range", selection: $selectedRange) {
                            ForEach(AnalyticsRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(pinkWaveHeaderEnabled ? .white : Color.appPink)
                        .padding(.horizontal)
                        .accessibilityLabel("Chart time range")
                    })
                    analyticsJumpPillBar(proxy: proxy)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if viewModel.pets.isEmpty {
                                emptyPlaceholder(
                                    icon: "chart.line.uptrend.xyaxis",
                                    text: "Add a pet under My Pets to unlock weight, height, mood, and schedule trends."
                                )
                                .padding(.horizontal)
                            } else {
                                if viewModel.pets.count > 1 {
                                    petFilterBar
                                        .id(AnalyticsJumpSection.summary.rawValue)
                                }

                                weightSection
                                    .padding(.horizontal)

                                heightSection
                                    .padding(.horizontal)

                                moodSection
                                    .padding(.horizontal)

                                complianceKindSections
                                    .padding(.horizontal)
                            }

                            Spacer(minLength: 32)
                        }
                        .padding(.top, 12)
                        .modifier(InterfaceContentEntranceModifier(delay: 0.06))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: selectedPetID) { _, _ in
                resetAnalyticsSwipePages()
                selectedAnalyticsJumpSection = nil
            }
            .onChange(of: selectedRange) { _, _ in
                resetAnalyticsSwipePages()
                selectedAnalyticsJumpSection = nil
            }
        }
        .sheet(item: $complianceLogSheet) { payload in
            ComplianceLogSheet(viewModel: viewModel, kind: payload.kind, petFilter: payload.pet)
        }
        .sheet(item: $analyticsPetProfileLaunch) { launch in
            PetDetailSheet(
                pet: launch.pet,
                initialScrollAnchor: launch.initialScrollAnchor,
                onSave: { viewModel.updatePet($0) },
                onRemovePet: nil
            )
        }
        .sheet(item: $addLogSheetPet) { pet in
            AddLogSheet(viewModel: viewModel, prefilledPet: pet)
        }
        .sheet(item: $addEventCompliancePayload) { payload in
            AddEventSheet(
                viewModel: viewModel,
                prefilledPet: payload.pet,
                prefilledPresetActivity: payload.presetActivity
            )
        }
    }

    /// Horizontal capsules matching `PetDetailSheet` — scrolls this screen to anchored sections.
    @ViewBuilder
    private func analyticsJumpPillBar(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleAnalyticsJumpSections, id: \.self) { section in
                    let sel = selectedAnalyticsJumpSection == section
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(.spring(duration: 0.25)) {
                            selectedAnalyticsJumpSection = section
                        }
                        withAnimation(.easeInOut(duration: 0.28)) {
                            proxy.scrollTo(section.rawValue, anchor: .top)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.pillSymbol)
                                .font(AppTypography.secondaryEmphasis)
                                .foregroundStyle(sel ? Color.white : Color.primary)
                            Text(section.pillTitle)
                                .font(AppTypography.secondaryEmphasis)
                                .foregroundStyle(sel ? Color.white : Color.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(sel ? Color.appPink : Color(.secondarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollClipDisabled()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Pet filter bar

    private var petFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Button {
                    HapticManager.impact(.light)
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
                                .font(AppTypography.sectionHeading)
                                .foregroundStyle(selectedPetID == nil ? Color.appPink : .secondary)
                        }
                        .overlay {
                            if selectedPetID == nil {
                                Circle()
                                    .strokeBorder(Color.appPink, lineWidth: 3)
                            }
                        }
                        Text("All")
                            .font(AppTypography.compactControl)
                            .foregroundStyle(selectedPetID == nil ? Color.appPink : .secondary)
                    }
                }
                .buttonStyle(.plain)

                ForEach(viewModel.pets) { pet in
                    let sel = selectedPetID == pet.id
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(.spring(duration: 0.25)) {
                            selectedPetID = sel ? nil : pet.id
                        }
                    } label: {
                        VStack(spacing: 6) {
                            PetAvatarView(pet: pet, size: 60)
                                .overlay {
                                    if sel {
                                        Circle()
                                            .strokeBorder(Color.appPink, lineWidth: 3)
                                    }
                                }
                                .scaleEffect(sel ? 1.05 : 1.0)
                            Text(pet.name)
                                .font(AppTypography.compactControl)
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

    // MARK: - Weight trends

    @ViewBuilder
    private var weightSection: some View {
        Group {
            if !viewModel.pets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text("Weight Trends")
                        .font(AppTypography.groupTitle)

                    PetSwipePager(pets: petsForAnalyticsContext, page: $weightSwipePage) { pet in
                        let windowed = filteredWeightEntries(for: pet)
                        if windowed.count >= 2 {
                            weightCard(for: pet, entries: windowed, color: petColor(for: pet.id))
                        } else if pet.weightHistory.count < 2 {
                            analyticsMeasurementEmptyCard(
                                pet: pet,
                                initialScrollAnchor: .weight,
                                icon: "scalemass.fill",
                                title: "No weight chart yet",
                                message:
                                    "Add two weigh-ins under Weight in \(pet.name)’s profile."
                            )
                        } else {
                            analyticsMeasurementSparsePeriodCard(
                                icon: "scalemass.fill",
                                title: "Need 2+ readings in this period",
                                message:
                                    "Switch to a wider range or log another weigh-in for \(pet.name) to see this chart."
                            )
                        }
                    }
                }
                .id(AnalyticsJumpSection.weight.rawValue)
            }
        }
    }

    private func weightCard(for pet: Pet, entries sorted: [WeightEntry], color: Color) -> some View {
        let diffKg = sorted.last!.kg - sorted[sorted.count - 2].kg
        let displayValues = sorted.map { weightUnit.displayValue(fromKg: $0.kg) }
        let minY   = (displayValues.min() ?? 0) * 0.92
        let maxY   = (displayValues.max() ?? 1) * 1.08

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(AppTypography.secondaryEmphasis)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: diffKg >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diffKg >= 0 ? .orange : .green)
                    Text(weightUnit.formatChange(diffKg))
                        .foregroundStyle(diffKg >= 0 ? .orange : .green)
                    Text("vs previous reading")
                        .font(.caption2)
                        .fontWeight(.regular)
                        .foregroundStyle(.tertiary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(weightUnit.formatValue(sorted.last!.kg)) now")
                        .foregroundStyle(.secondary)
                }
                .font(AppTypography.compactControl)
            }

            Chart(sorted) { e in
                let y = weightUnit.displayValue(fromKg: e.kg)
                LineMark(x: .value("Date", e.date), y: .value(weightUnit.label, y))
                    .foregroundStyle(color)
                    .interpolationMethod(.linear)
                AreaMark(
                    x: .value("Date", e.date),
                    yStart: .value("Min", minY),
                    yEnd: .value(weightUnit.label, y)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.linear)
                PointMark(x: .value("Date", e.date), y: .value(weightUnit.label, y))
                    .foregroundStyle(color)
                    .symbolSize(30)
            }
            .chartYScale(domain: minY...maxY)
            .chartXScale(domain: chartXDateDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: selectedRange.chartXAxisDesiredCount)) { value in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(centered: true) {
                        if let d = value.as(Date.self) {
                            Text(d, format: selectedRange.chartXAxisDateFormat)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(centered: false) {
                        if let v = v.as(Double.self) {
                            Text(String(format: "%.1f", v))
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .frame(height: 150)

            Divider().padding(.top, 4)
            historyTable(
                valueColumnTitle: "Weight",
                rows: sorted.reversed().map { (date: $0.date, value: weightUnit.formatValue($0.kg)) }
            )
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Height trends

    @ViewBuilder
    private var heightSection: some View {
        Group {
            if !viewModel.pets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text("Height Trends")
                        .font(AppTypography.groupTitle)

                    PetSwipePager(pets: petsForAnalyticsContext, page: $heightSwipePage) { pet in
                        let windowed = filteredHeightEntries(for: pet)
                        if windowed.count >= 2 {
                            heightCard(for: pet, entries: windowed, color: petColor(for: pet.id))
                        } else if pet.heightHistory.count < 2 {
                            analyticsMeasurementEmptyCard(
                                pet: pet,
                                initialScrollAnchor: .height,
                                icon: "ruler.fill",
                                title: "No height chart yet",
                                message:
                                    "Add two measurements under Height in \(pet.name)’s profile."
                            )
                        } else {
                            analyticsMeasurementSparsePeriodCard(
                                icon: "ruler.fill",
                                title: "Need 2+ readings in this period",
                                message:
                                    "Switch to a wider range or log another measurement for \(pet.name) to see this chart."
                            )
                        }
                    }
                }
                .id(AnalyticsJumpSection.height.rawValue)
            }
        }
    }

    private func heightCard(for pet: Pet, entries sorted: [HeightEntry], color: Color) -> some View {
        let diffCm = sorted.last!.cm - sorted[sorted.count - 2].cm
        let displayValues = sorted.map { heightUnit.displayValue(fromCm: $0.cm) }
        let minY   = (displayValues.min() ?? 0) * 0.92
        let maxY   = (displayValues.max() ?? 1) * 1.08

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(AppTypography.secondaryEmphasis)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: diffCm >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diffCm >= 0 ? .orange : .green)
                    Text(heightUnit.formatChange(diffCm))
                        .foregroundStyle(diffCm >= 0 ? .orange : .green)
                    Text("vs previous reading")
                        .font(.caption2)
                        .fontWeight(.regular)
                        .foregroundStyle(.tertiary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(heightUnit.formatValue(sorted.last!.cm)) now")
                        .foregroundStyle(.secondary)
                }
                .font(AppTypography.compactControl)
            }

            Chart(sorted) { e in
                let y = heightUnit.displayValue(fromCm: e.cm)
                LineMark(x: .value("Date", e.date), y: .value(heightUnit.inputLabel, y))
                    .foregroundStyle(color)
                    .interpolationMethod(.linear)
                AreaMark(
                    x: .value("Date", e.date),
                    yStart: .value("Min", minY),
                    yEnd: .value(heightUnit.inputLabel, y)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.linear)
                PointMark(x: .value("Date", e.date), y: .value(heightUnit.inputLabel, y))
                    .foregroundStyle(color)
                    .symbolSize(30)
            }
            .chartYScale(domain: minY...maxY)
            .chartXScale(domain: chartXDateDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: selectedRange.chartXAxisDesiredCount)) { value in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(centered: true) {
                        if let d = value.as(Date.self) {
                            Text(d, format: selectedRange.chartXAxisDateFormat)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(centered: false) {
                        if let v = v.as(Double.self) {
                            Text(String(format: "%.0f", v))
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .frame(height: 150)

            Divider().padding(.top, 4)
            historyTable(
                valueColumnTitle: "Height",
                rows: sorted.reversed().map { (date: $0.date, value: heightUnit.formatValue($0.cm)) }
            )
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Mood over time (quick logs)

    /// Keeps emoji in a fixed column so every row/axis tick shares the same horizontal start for the glyph.
    private func moodEmojiAlignedLabel(_ mood: PetMood, font: Font, valueSecondary: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(mood.emoji)
                .font(font)
                .frame(width: Self.moodEmojiColumnWidth, alignment: .leading)
                .multilineTextAlignment(.leading)
            Text(mood.rawValue)
                .font(font)
                .foregroundStyle(valueSecondary ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: Self.moodLabelLayoutWidth, alignment: .leading)
    }

    /// Fixed emoji column width (leading-aligned so each emoji’s box starts at the same x).
    private static let moodEmojiColumnWidth: CGFloat = 44

    /// One width for chart Y-axis ticks and table mood column so emojis line up on screen across the card.
    private static let moodLabelLayoutWidth: CGFloat = 128

    /// Mood quick logs in the selected analytics window for one pet.
    private func moodQuickLogs(for petID: UUID) -> [ScheduleItem] {
        viewModel.scheduleItems.filter {
            $0.pet.id == petID
                && $0.quickLogKind == .mood
                && $0.petMood != nil
                && $0.time >= rangeStart
                && $0.time < rangeExclusiveEnd
        }
        .sorted { $0.time < $1.time }
    }

    /// Match compliance spacing when every mood page is in empty-state mode.
    private var moodPagerHeight: CGFloat {
        let hasAnyTrendData = petsForAnalyticsContext.contains { moodQuickLogs(for: $0.id).count >= 2 }
        return hasAnyTrendData ? AnalyticsSwipeLayout.pageHeight : AnalyticsSwipeLayout.compliancePageHeight
    }

    @ViewBuilder
    private var moodSection: some View {
        Group {
            if !viewModel.pets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text("Mood Over Time")
                        .font(AppTypography.groupTitle)

                    Text("From Log → Mood entries in this period (higher is brighter mood).")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)

                    PetSwipePager(
                        pets: petsForAnalyticsContext,
                        page: $moodSwipePage,
                        pageHeight: moodPagerHeight
                    ) { pet in
                        if moodQuickLogs(for: pet.id).count >= 2 {
                            moodCard(for: pet, color: petColor(for: pet.id))
                        } else {
                            moodTrendEmptyCard(for: pet)
                        }
                    }
                }
                .id(AnalyticsJumpSection.mood.rawValue)
            }
        }
    }

    private func moodCard(for pet: Pet, color: Color) -> some View {
        let items = moodQuickLogs(for: pet.id)
        let last = items.last?.petMood
        let deltaFromPrevious: Double = {
            guard items.count >= 2,
                  let lastScore = items.last?.petMood?.wellbeingChartScore,
                  let prevScore = items[items.count - 2].petMood?.wellbeingChartScore
            else { return 0 }
            return lastScore - prevScore
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(AppTypography.secondaryEmphasis)
                }
                Spacer()
                if let last {
                    HStack(spacing: 8) {
                        moodEmojiAlignedLabel(last, font: AppTypography.compactControl, valueSecondary: true)
                        if items.count >= 2, abs(deltaFromPrevious) > 0.001 {
                            HStack(spacing: 4) {
                                Image(systemName: deltaFromPrevious >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .foregroundStyle(deltaFromPrevious >= 0 ? .green : .orange)
                                Text(deltaFromPrevious >= 0 ? "+\(String(format: "%.0f", deltaFromPrevious))" : String(format: "%.0f", deltaFromPrevious))
                                    .foregroundStyle(deltaFromPrevious >= 0 ? .green : .orange)
                                Text("vs previous log")
                                    .font(.caption2)
                                    .fontWeight(.regular)
                                    .foregroundStyle(.tertiary)
                            }
                            .font(AppTypography.compactControl)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            Chart(items) { item in
                let mood = item.petMood!
                let y = mood.wellbeingChartScore
                LineMark(x: .value("Date", item.time), y: .value("Mood", y))
                    .foregroundStyle(color)
                    .interpolationMethod(.linear)
                AreaMark(
                    x: .value("Date", item.time),
                    yStart: .value("Floor", 0.5),
                    yEnd: .value("Mood", y)
                )
                .foregroundStyle(LinearGradient(
                    colors: [color.opacity(0.22), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .interpolationMethod(.linear)
                PointMark(x: .value("Date", item.time), y: .value("Mood", y))
                    .foregroundStyle(color)
                    .symbolSize(28)
            }
            .chartYScale(domain: 0.5...5.5)
            .chartXScale(domain: chartXDateDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: selectedRange.chartXAxisDesiredCount)) { value in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(centered: true) {
                        if let d = value.as(Date.self) {
                            Text(d, format: selectedRange.chartXAxisDateFormat)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [1, 2, 3, 4, 5]) { value in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(multiLabelAlignment: .leading, horizontalSpacing: 0) {
                        if let i = value.as(Int.self), let m = PetMood.mood(forChartScore: i) {
                            moodEmojiAlignedLabel(m, font: .caption2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }
            .frame(height: 160)

            Divider().padding(.top, 4)
            moodEntriesHistoryTable(items: items.reversed())
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Date / mood rows for Mood Over Time — mood column aligns emoji + text like the chart axis.
    private func moodEntriesHistoryTable(items: [ScheduleItem]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Mood")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
                    .frame(width: Self.moodLabelLayoutWidth, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)

            ForEach(items) { item in
                Divider()
                HStack {
                    Text(item.time.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.primary)
                    Spacer()
                    if let mood = item.petMood {
                        moodEmojiAlignedLabel(mood, font: AppTypography.compactControl)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: - Medicine / feeding / water compliance

    private struct ComplianceRatePoint: Identifiable {
        let id = UUID()
        let date: Date
        let petName: String
        let petID: UUID
        let accepted: Int
        let total: Int
        var rate: Double { total > 0 ? Double(accepted) / Double(total) : 0 }
    }

    private func complianceRatePoints(for pet: Pet, kind: ScheduleComplianceKind) -> [ComplianceRatePoint] {
        let kindItems = viewModel.scheduleItems.filter { $0.pet.id == pet.id && $0.complianceKind == kind }
        guard !kindItems.isEmpty else { return [] }

        switch selectedRange {
        case .week:
            // Always emit all 7 days so the line spans the full x-axis.
            return (0..<7).reversed().compactMap { offset -> ComplianceRatePoint? in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: .now)),
                      let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
                else { return nil }
                let sliceEnd = min(nextDay, rangeExclusiveEnd)
                let sliceStart = max(day, rangeStart)
                let items = kindItems.filter { $0.time >= sliceStart && $0.time < sliceEnd }
                return ComplianceRatePoint(
                    date: day, petName: pet.name, petID: pet.id,
                    accepted: items.filter { $0.medicineAccepted == true }.count,
                    total: items.count
                )
            }

        case .month:
            return (0..<5).reversed().compactMap { weekOffset -> ComplianceRatePoint? in
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfDay(for: .now)),
                      let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
                else { return nil }
                let sliceStart = max(weekStart, rangeStart)
                let sliceEnd = min(weekEnd, rangeExclusiveEnd)
                guard sliceStart < sliceEnd else { return nil }
                let items = kindItems.filter { $0.time >= sliceStart && $0.time < sliceEnd }
                guard !items.isEmpty else { return nil }
                return ComplianceRatePoint(
                    date: sliceStart, petName: pet.name, petID: pet.id,
                    accepted: items.filter { $0.medicineAccepted == true }.count,
                    total: items.count
                )
            }

        case .year:
            return (0..<12).reversed().compactMap { monthsBack -> ComplianceRatePoint? in
                guard let ref = calendar.date(byAdding: .month, value: -monthsBack, to: calendar.startOfDay(for: .now))
                else { return nil }
                let monthStart = startOfMonth(for: ref)
                guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
                let sliceStart = max(monthStart, rangeStart)
                let sliceEnd = min(monthEnd, rangeExclusiveEnd)
                guard sliceStart < sliceEnd else { return nil }
                let items = kindItems.filter { $0.time >= sliceStart && $0.time < sliceEnd }
                guard !items.isEmpty else { return nil }
                return ComplianceRatePoint(
                    date: monthStart, petName: pet.name, petID: pet.id,
                    accepted: items.filter { $0.medicineAccepted == true }.count,
                    total: items.count
                )
            }
        }

    }

    @ViewBuilder
    private var complianceKindSections: some View {
        ForEach([ScheduleComplianceKind.medicine, .feed, .water], id: \.self) { kind in
            complianceSection(for: kind)
        }
    }

    @ViewBuilder
    private func complianceSection(for kind: ScheduleComplianceKind) -> some View {
        Group {
            if !viewModel.pets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text(kind.analyticsSectionTitle)
                        .font(AppTypography.groupTitle)

                    PetSwipePager(
                        pets: petsForAnalyticsContext,
                        page: complianceSwipeBinding(for: kind),
                        pageHeight: AnalyticsSwipeLayout.compliancePageHeight
                    ) { pet in
                        complianceRateCard(for: pet, kind: kind, color: petColor(for: pet.id)) {
                            complianceLogSheet = ComplianceLogSheetPayload(kind: kind, pet: pet)
                        }
                    }
                }
                .id(AnalyticsJumpSection.compliance(kind).rawValue)
            }
        }
    }

    private func complianceSwipeBinding(for kind: ScheduleComplianceKind) -> Binding<Int> {
        switch kind {
        case .medicine: return $complianceSwipeMedicine
        case .feed:     return $complianceSwipeFeed
        case .water:    return $complianceSwipeWater
        }
    }

    private func resetAnalyticsSwipePages() {
        weightSwipePage = 0
        heightSwipePage = 0
        moodSwipePage = 0
        complianceSwipeMedicine = 0
        complianceSwipeFeed = 0
        complianceSwipeWater = 0
    }

    private func complianceRateCard(for pet: Pet, kind: ScheduleComplianceKind, color: Color, onViewLog: @escaping () -> Void) -> some View {
        let hasScheduledItems = viewModel.scheduleItems.contains { $0.pet.id == pet.id && $0.complianceKind == kind }
        let points = complianceRatePoints(for: pet, kind: kind)
        let avg = points.isEmpty ? 0.0 : points.map(\.rate).reduce(0, +) / Double(points.count)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                if viewModel.pets.count > 1 {
                    PetAvatarView(pet: pet, size: 26)
                    Text(pet.name).font(AppTypography.secondaryEmphasis)
                }
                Spacer()
                if hasScheduledItems {
                    Text("\(Int(avg * 100))% avg compliance")
                        .font(AppTypography.compactControl)
                        .foregroundStyle(rateColor(avg))
                }
            }

            if !hasScheduledItems {
                complianceNeverScheduledPlaceholder(kind: kind, pet: pet)
            } else if points.isEmpty {
                Text(kind.analyticsPeriodEmptyMessage)
                    .font(AppTypography.supportingText)
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
                    .interpolationMethod(.linear)
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Rate", p.rate)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.linear)
                    PointMark(
                        x: .value("Date", p.date),
                        y: .value("Rate", p.rate)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
                .chartYScale(domain: 0...1)
                .chartXScale(domain: chartXDateDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: selectedRange.chartXAxisDesiredCount)) { value in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel(centered: true) {
                            if let d = value.as(Date.self) {
                                Text(d, format: selectedRange.chartXAxisDateFormat)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.62)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1.0]) { v in
                        AxisGridLine().foregroundStyle(Color(.separator).opacity(0.4))
                        AxisValueLabel(centered: false) {
                            if let d = v.as(Double.self) {
                                Text("\(Int(d * 100))%")
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
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
                            .font(AppTypography.compactControl)
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

    // MARK: - Helpers

    private static func compliancePresetActivity(_ kind: ScheduleComplianceKind) -> String {
        switch kind {
        case .medicine: return "Give Medication"
        case .feed: return "Feed"
        case .water: return "Give water"
        }
    }

    /// Pink capsule CTAs matching measurement empty-state buttons.
    private func analyticsCapsuleCTAButton(title: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(AppTypography.capsuleButton)
                Text(title)
                    .font(AppTypography.capsuleButton)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appPink, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Opens the pet profile so the guardian can add weight or height readings.
    private func analyticsMeasurementEmptyCard(
        pet: Pet,
        initialScrollAnchor: PetDetailSheet.InitialScrollAnchor,
        icon: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(AppTypography.emptyStateSymbol)
                .foregroundStyle(Color.appPink.opacity(0.45))
            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppTypography.supportingText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            analyticsCapsuleCTAButton(title: "Tap to add", accessibilityLabel: "Tap to add in \(pet.name)'s profile") {
                analyticsPetProfileLaunch = AnalyticsPetProfileLaunch(pet: pet, initialScrollAnchor: initialScrollAnchor)
            }
            .accessibilityHint("Opens this pet’s profile.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Weight / height history exists but fewer than two readings fall inside the selected chart window.
    private func analyticsMeasurementSparsePeriodCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(AppTypography.emptyStateSymbol)
                .foregroundStyle(Color.appPink.opacity(0.45))
            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppTypography.supportingText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func moodTrendEmptyCard(for pet: Pet) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "face.smiling")
                .font(AppTypography.emptyStateSymbol)
                .foregroundStyle(Color.appPink.opacity(0.45))
            Text("No mood chart yet")
                .font(AppTypography.cardTitle)
                .foregroundStyle(.primary)
            Text(
                "After two Mood logs for \(pet.name) in this \(selectedRange.rawValue.lowercased()), a trend appears here."
            )
            .font(AppTypography.supportingText)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            analyticsCapsuleCTAButton(title: "Tap to log", accessibilityLabel: "Tap to log mood for \(pet.name)") {
                addLogSheetPet = pet
            }
            .accessibilityHint("Opens Log with Mood selected.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func complianceNeverScheduledPlaceholder(kind: ScheduleComplianceKind, pet: Pet) -> some View {
        let noun: String = {
            switch kind {
            case .medicine: return "medicine"
            case .feed: return "feeding"
            case .water: return "water"
            }
        }()
        return VStack(spacing: 16) {
            Image(systemName: kind.logEmptySystemImage)
                .font(AppTypography.emptyStateSymbol)
                .foregroundStyle(Color.appPink.opacity(0.45))
            Text("No \(noun) tasks for \(pet.name)")
                .font(AppTypography.cardTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(
                "Add a repeating \(noun) reminder on your timeline. Analytics tracks yes/no once events appear."
            )
            .font(AppTypography.supportingText)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            analyticsCapsuleCTAButton(title: "Add 1st \(noun) event", accessibilityLabel: "Add first \(noun) event for \(pet.name)") {
                addEventCompliancePayload = AddEventCompliancePayload(
                    pet: pet,
                    presetActivity: Self.compliancePresetActivity(kind)
                )
            }
            .accessibilityHint("Opens New Event with a suggested activity.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
    }

    /// Renders a two-column history table (`Date` | labeled value) used for weight and height cards.
    private func historyTable(valueColumnTitle: String, rows: [(date: Date, value: String)]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Date")
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueColumnTitle)
                    .font(AppTypography.micro)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider()
                HStack {
                    Text(row.date.formatted(date: .abbreviated, time: .omitted))
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(row.value)
                        .font(AppTypography.compactControl)
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
                .font(AppTypography.emptyStateSymbol)
                    .foregroundStyle(Color.appPink.opacity(0.4))
                Text(text)
                    .font(AppTypography.secondaryLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
            Spacer()
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Compliance log sheets (medicine / feeding / water)

struct ComplianceLogSheet: View {
    let viewModel: HomeViewModel
    let kind: ScheduleComplianceKind
    /// Initial pet selection when the sheet opens (`nil` = all pets).
    private let petFilter: Pet?

    @State private var selectedPetID: UUID?

    @AppStorage("timeFormat") private var timeFormatRaw = "24h"
    @Environment(\.dismiss) private var dismiss

    private let cal = Calendar.current
    private var timeFormat: TimeFormat { TimeFormat(rawValue: timeFormatRaw) ?? .twelveHour }

    init(viewModel: HomeViewModel, kind: ScheduleComplianceKind, petFilter: Pet?) {
        self.viewModel = viewModel
        self.kind = kind
        self.petFilter = petFilter
        _selectedPetID = State(initialValue: petFilter?.id)
    }

    private var petsWithThisCompliance: [Pet] {
        viewModel.pets.filter { pet in
            viewModel.scheduleItems.contains { $0.pet.id == pet.id && $0.complianceKind == kind }
        }
    }

    private var showPetNameOnRows: Bool {
        selectedPetID == nil && petsWithThisCompliance.count > 1
    }

    private var filteredItems: [ScheduleItem] {
        viewModel.scheduleItems
            .filter { $0.complianceKind == kind }
            .filter { selectedPetID == nil || $0.pet.id == selectedPetID }
            .sorted { $0.time > $1.time }
    }

    /// All days from the earliest event to today, newest first.
    private var allDays: [(date: Date, items: [ScheduleItem])] {
        guard let firstDate = filteredItems.map({ cal.startOfDay(for: $0.time) }).min() else { return [] }
        let today = cal.startOfDay(for: .now)
        let grouped = Dictionary(grouping: filteredItems) { cal.startOfDay(for: $0.time) }

        var result: [(date: Date, items: [ScheduleItem])] = []
        var current = today
        while current >= firstDate {
            result.append((date: current, items: (grouped[current] ?? []).sorted { $0.time < $1.time }))
            current = cal.date(byAdding: .day, value: -1, to: current) ?? current.addingTimeInterval(-86400)
        }
        return result
    }

    private var navigationTitle: String {
        kind.logNavigationTitle(petName: selectedPetID.flatMap { id in viewModel.pets.first { $0.id == id }?.name })
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        kind.logEmptyTitle,
                        systemImage: kind.logEmptySystemImage,
                        description: Text(kind.logEmptyDescription)
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if petsWithThisCompliance.count > 1 {
                                complianceLogPetPicker
                                    .padding(.bottom, 16)
                            }

                            LazyVStack(alignment: .leading, spacing: 20) {
                                ForEach(allDays, id: \.date) { group in
                                    complianceDayCard(group: group)
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

    private var complianceLogPetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                let allSelected = selectedPetID == nil
                Button {
                    HapticManager.impact(.light)
                    withAnimation(.spring(duration: 0.25)) { selectedPetID = nil }
                } label: {
                    Text("All pets")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(allSelected ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(allSelected ? Color.appPink : Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)

                ForEach(petsWithThisCompliance) { pet in
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
                                .font(AppTypography.secondaryEmphasis)
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

    private func complianceDayCard(group: (date: Date, items: [ScheduleItem])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                .font(AppTypography.secondaryEmphasis)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if group.items.isEmpty {
                    HStack {
                        Text(kind.logDayEmptyRowLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("—")
                            .font(AppTypography.compactControl)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                } else {
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                        ComplianceLogRow(
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

private struct ComplianceLogRow: View {
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
                    .font(AppTypography.rowIcon)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.activityName)
                        .font(AppTypography.secondaryEmphasis)
                    if showPetName {
                        Text("· \(item.pet.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !item.description.isEmpty {
                    Text(item.description)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                }
                Text(timeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(statusText)
                .font(AppTypography.compactControl)
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
        case true:
            switch item.complianceKind {
            case .medicine: return "Yes — taken"
            case .feed:     return "Yes — ate"
            case .water:    return "Yes — drank water"
            case nil:        return "Yes"
            }
        case false: return "No — skipped"
        case nil:   return item.isCompleted ? "Done" : "To Do"
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(viewModel: .analyticsPreview)
}
