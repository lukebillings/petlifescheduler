import SwiftUI
import UIKit
import WidgetKit

struct TodayEventsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayEventsWidget.kind, provider: TodayEventsProvider()) { entry in
            TodayEventsWidgetView(entry: entry)
                .containerBackground(Color(.systemGroupedBackground), for: .widget)
        }
        .configurationDisplayName("Today's schedule")
        .description("Next upcoming events for your pets today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    static let kind = "com.lukebillings.PetSchedule.todayEvents"
}

struct TodayEventsEntry: TimelineEntry {
    let date: Date
    let events: [WidgetScheduleEventDTO]
    let timeFormat24h: Bool
    /// Total events on this calendar day (used for empty vs all-done).
    let totalTodayEventCount: Int
}

struct TodayEventsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEventsEntry {
        TodayEventsEntry(
            date: Date(),
            events: [
                sampleEvent(activity: "Walk", icon: "figure.walk", quickLog: false),
                sampleEvent(activity: "Feed", icon: "fork.knife", quickLog: false),
            ],
            timeFormat24h: true,
            totalTodayEventCount: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEventsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEventsEntry>) -> Void) {
        let entry = loadEntry()
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let nextDay = cal.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(86_400)
        let timeline = Timeline(entries: [entry], policy: .after(nextDay))
        completion(timeline)
    }

    private func loadEntry() -> TodayEventsEntry {
        let payload = ScheduleWidgetShared.loadPayload()
        return TodayEventsEntry(
            date: Date(),
            events: payload?.events ?? [],
            timeFormat24h: payload?.timeFormat24h ?? true,
            totalTodayEventCount: payload?.totalTodayEventCount ?? 0
        )
    }

    private func sampleEvent(activity: String, icon: String, quickLog: Bool) -> WidgetScheduleEventDTO {
        WidgetScheduleEventDTO(
            id: UUID(),
            time: Date(),
            isAllDay: false,
            activityName: activity,
            petName: "Max",
            isCompleted: false,
            petPhotoJPEGData: nil,
            activitySystemImage: icon,
            petSystemImage: "dog.fill",
            isQuickLog: quickLog
        )
    }
}

struct TodayEventsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayEventsEntry

    private var compactCards: Bool { family == .systemSmall }

    private var isLargeFamily: Bool { family == .systemLarge }

    /// Up to four in the payload for the large widget; small/medium show two.
    private var displayedEvents: [WidgetScheduleEventDTO] {
        let cap = isLargeFamily ? 4 : 2
        return Array(entry.events.prefix(cap))
    }

    /// Tighter layout when the widget is small or showing several rows.
    private var cardLayoutCompact: Bool {
        if compactCards { return true }
        if isLargeFamily { return displayedEvents.count >= 3 }
        return family == .systemMedium && displayedEvents.count >= 2
    }

    /// Second-line pet name (matches schedule row detail line); skipped on smallest dense layout.
    private var showPetSubtitle: Bool { !cardLayoutCompact }

    private var noEventsToday: Bool {
        entry.totalTodayEventCount == 0 && entry.events.isEmpty
    }

    private var allDoneToday: Bool {
        entry.events.isEmpty && entry.totalTodayEventCount > 0
    }

    /// Same card spacing as `GlassEffectContainer` in `ScheduleListView`.
    private var eventListSpacing: CGFloat { 12 }

    var body: some View {
        VStack(alignment: .leading, spacing: compactCards ? 8 : 10) {
            WidgetScheduleDateHeader(referenceDate: entry.date, compact: compactCards)

            if noEventsToday {
                Text("No events today")
                    .font(compactCards ? AppTypography.cardTitle : AppTypography.sectionHeading)
                    .foregroundStyle(.primary)
                Text("Add some in PetLifeScheduler")
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.secondary)
            } else if allDoneToday {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(compactCards ? AppTypography.groupTitle : AppTypography.emptyStateSymbol)
                            .foregroundStyle(Color.appPink.opacity(0.5))
                        Text("All done for today!")
                            .font(AppTypography.secondaryLabel)
                            .foregroundStyle(.secondary)
                        Text("\(entry.totalTodayEventCount) completed")
                            .font(AppTypography.supportingText)
                            .foregroundStyle(.tertiary)
                    }
                    .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.vertical, compactCards ? 4 : 8)
            } else {
                VStack(alignment: .leading, spacing: eventListSpacing) {
                    ForEach(displayedEvents) { ev in
                        WidgetScheduleEventRow(
                            event: ev,
                            timeFormat24h: entry.timeFormat24h,
                            compact: cardLayoutCompact,
                            showPetSubtitle: showPetSubtitle
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Schedule header parity (`ScheduleView.scheduleDateHeaderBar`)

private struct WidgetScheduleDateHeader: View {
    var referenceDate: Date
    var compact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("Today")
                .font(compact ? AppTypography.cardTitle : AppTypography.sectionHeading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(referenceDate.formatted(.dateTime.day().month(.abbreviated)))
                .font(AppTypography.compactControl)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue, in: Capsule())

            Spacer(minLength: 0)
        }
    }
}

#Preview(as: .systemSmall) {
    TodayEventsWidget()
} timeline: {
    TodayEventsEntry(
        date: Date(),
        events: [
            WidgetScheduleEventDTO(
                id: UUID(),
                time: Date(),
                isAllDay: false,
                activityName: "Walk",
                petName: "Max",
                isCompleted: false,
                petPhotoJPEGData: nil,
                activitySystemImage: "figure.walk",
                petSystemImage: "dog.fill",
                isQuickLog: false
            ),
            WidgetScheduleEventDTO(
                id: UUID(),
                time: Date(),
                isAllDay: false,
                activityName: "Poo",
                petName: "Max",
                isCompleted: false,
                petPhotoJPEGData: nil,
                activitySystemImage: "toilet.fill",
                petSystemImage: "dog.fill",
                isQuickLog: true
            ),
        ],
        timeFormat24h: true,
        totalTodayEventCount: 4
    )
}

// MARK: - Schedule row parity (`ScheduleRowView`)

private struct WidgetPetAvatar: View {
    let jpegData: Data?
    let systemImageName: String?
    let size: CGFloat

    /// Matches `PetAvatarView` — zooms slightly before crop so JPEG edges don’t read as a white ring.
    private static let cropOverscale: CGFloat = 1.14

    var body: some View {
        ZStack {
            if let jpegData, let ui = UIImage(data: jpegData) {
                Image(uiImage: ui)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Image(systemName: systemImageName ?? "pawprint.fill")
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(Self.cropOverscale)
        .clipShape(Circle())
    }
}

/// Mirrors `ScheduleRowView`: avatar, secondary activity icon, time + title (+ optional pet line), completion; quick log tint matches in-app cards.
private struct WidgetScheduleEventRow: View {
    let event: WidgetScheduleEventDTO
    let timeFormat24h: Bool
    var compact: Bool
    var showPetSubtitle: Bool = true

    private var isQuickLog: Bool { event.isQuickLog == true }

    private var avatarSize: CGFloat { compact ? 44 : 48 }

    private var rowVerticalPadding: CGFloat { compact ? 12 : 16 }

    private var activityIconName: String {
        if let name = event.activitySystemImage, !name.isEmpty { return name }
        return "calendar"
    }

    private var trimmedPetName: String {
        event.petName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            WidgetPetAvatar(
                jpegData: event.petPhotoJPEGData,
                systemImageName: event.petSystemImage,
                size: avatarSize
            )

            Image(systemName: activityIconName)
                .font(AppTypography.rowIcon)
                .foregroundStyle(Color.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.timeLabel(timeFormat24h: timeFormat24h))
                        .font(AppTypography.primaryLabel)
                        .lineLimit(1)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)

                    Text(event.activityName)
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .minimumScaleFactor(compact ? 0.8 : 1)

                if showPetSubtitle, !trimmedPetName.isEmpty {
                    Text(trimmedPetName)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 0)

            Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(AppTypography.completionControl)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(event.isCompleted ? Color.complianceAccept : Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, rowVerticalPadding)
        .background {
            if isQuickLog {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.appPink.opacity(0.08))
            }
        }
        .overlay {
            if isQuickLog {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.appPink.opacity(0.32), lineWidth: 1)
            }
        }
        .modifier(WidgetScheduleRowGlassModifier(isQuickLog: isQuickLog))
        .opacity(event.isCompleted ? 0.74 : 1.0)
        .saturation(event.isCompleted ? 0.9 : 1.0)
    }
}

private struct WidgetScheduleRowGlassModifier: ViewModifier {
    let isQuickLog: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isQuickLog {
            content
        } else {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
