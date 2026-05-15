import SwiftUI
import UIKit
import WidgetKit

struct TodayEventsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ScheduleWidgetShared.todayEventsWidgetKind, provider: TodayEventsProvider()) { entry in
            TodayEventsWidgetView(entry: entry)
                .containerBackground(Color(.systemGroupedBackground), for: .widget)
        }
        .configurationDisplayName("Today's schedule")
        .description("Next upcoming events for your pets today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

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
        let now = Date()
        let entry = loadEntry(at: now)
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let nextDay = cal.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
        let nextRefresh = min(nextDay, now.addingTimeInterval(30 * 60))
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func loadEntry(at date: Date = .now) -> TodayEventsEntry {
        let payload = ScheduleWidgetShared.loadPayload()
        let todayEvents = ScheduleWidgetShared.eventsForToday(from: payload, on: date)
        let totalToday: Int
        if let payload, Calendar.current.isDate(payload.updatedAt, inSameDayAs: date) {
            totalToday = payload.totalTodayEventCount
        } else {
            totalToday = todayEvents.count
        }
        return TodayEventsEntry(
            date: date,
            events: todayEvents,
            timeFormat24h: payload?.timeFormat24h ?? true,
            totalTodayEventCount: totalToday
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

    /// Up to four in the payload for the large widget; small/medium show two. Incomplete first, like “what’s next”.
    private var displayedEvents: [WidgetScheduleEventDTO] {
        let cap = isLargeFamily ? 4 : 2
        let incomplete = entry.events.filter { !$0.isCompleted }
        let completed = entry.events.filter(\.isCompleted)
        return Array((incomplete + completed).prefix(cap))
    }

    /// Tighter layout when the widget is small or showing several rows.
    private var cardLayoutCompact: Bool {
        if compactCards { return true }
        if isLargeFamily { return displayedEvents.count >= 3 }
        return family == .systemMedium && displayedEvents.count >= 2
    }

    private var noEventsToday: Bool {
        entry.totalTodayEventCount == 0
    }

    private var allDoneToday: Bool {
        entry.totalTodayEventCount > 0 && entry.events.allSatisfy(\.isCompleted)
    }

    private var eventListSpacing: CGFloat { compactCards ? 6 : 10 }

    private var cardsFillHeight: Bool {
        compactCards && !noEventsToday && !allDoneToday
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compactCards ? 0 : 8) {
            if noEventsToday {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing scheduled")
                        .font(AppTypography.primaryLabel)
                        .foregroundStyle(.primary)
                    Text("Open PetLifeScheduler to add events")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if allDoneToday {
                VStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(compactCards ? .title2 : AppTypography.emptyStateSymbol)
                        .foregroundStyle(Color.appPink.opacity(0.55))
                    Text("All done!")
                        .font(AppTypography.primaryLabel)
                        .foregroundStyle(.primary)
                    Text("\(entry.totalTodayEventCount) completed today")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            } else {
                VStack(alignment: .leading, spacing: eventListSpacing) {
                    ForEach(displayedEvents) { ev in
                        WidgetScheduleEventRow(
                            event: ev,
                            timeFormat24h: entry.timeFormat24h,
                            compact: cardLayoutCompact,
                            smallWidget: compactCards,
                            fillHeight: cardsFillHeight
                        )
                        .frame(maxHeight: cardsFillHeight ? .infinity : nil)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, compactCards ? 6 : 12)
        .padding(.vertical, compactCards ? 6 : 12)
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
            Circle()
                .fill(Color(.tertiarySystemFill))
            if let jpegData, let ui = UIImage(data: jpegData) {
                Image(uiImage: ui)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Image(systemName: systemImageName ?? "pawprint.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(jpegData != nil ? Self.cropOverscale : 1)
        .clipShape(Circle())
    }
}

/// Read-only schedule row for the widget (no completion control — not tappable from the home screen).
private struct WidgetScheduleEventRow: View {
    let event: WidgetScheduleEventDTO
    let timeFormat24h: Bool
    var compact: Bool
    var smallWidget: Bool = false
    var fillHeight: Bool = false

    private var isQuickLog: Bool { event.isQuickLog == true }

    private var cardCornerRadius: CGFloat { smallWidget ? 12 : 24 }

    private var avatarSize: CGFloat {
        if smallWidget { return 28 }
        return compact ? 36 : 40
    }

    private var rowHorizontalPadding: CGFloat {
        if smallWidget { return 8 }
        return compact ? 10 : 12
    }

    private var rowVerticalPadding: CGFloat {
        if smallWidget { return 6 }
        return compact ? 10 : 11
    }

    private var activityIconName: String {
        if let name = event.activitySystemImage, !name.isEmpty { return name }
        return "calendar"
    }

    private var trimmedPetName: String {
        event.petName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .center, spacing: smallWidget ? 6 : (compact ? 10 : 12)) {
            WidgetPetAvatar(
                jpegData: event.petPhotoJPEGData,
                systemImageName: event.petSystemImage,
                size: avatarSize
            )

            if smallWidget {
                smallWidgetContent
            } else {
                standardWidgetContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillHeight ? .infinity : nil, alignment: .leading)
        .padding(.horizontal, rowHorizontalPadding)
        .padding(.vertical, rowVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(isQuickLog ? Color.appPink.opacity(0.1) : Color(.systemBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(
                    isQuickLog ? Color.appPink.opacity(0.28) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        }
        .opacity(event.isCompleted ? 0.72 : 1)
    }

    private var smallWidgetContent: some View {
        HStack(spacing: 5) {
            Image(systemName: activityIconName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isQuickLog ? Color.appPink : Color.secondary)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.activityName)
                    .font(AppTypography.compactControl)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .strikethrough(event.isCompleted, color: .secondary)

                Text(event.timeLabel(timeFormat24h: timeFormat24h))
                    .font(AppTypography.micro)
                    .foregroundStyle(Color.appPink)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }

    private var standardWidgetContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                Image(systemName: activityIconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isQuickLog ? Color.appPink : Color.secondary)
                    .frame(width: 14)

                Text(event.activityName)
                    .font(AppTypography.primaryLabel)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .strikethrough(event.isCompleted, color: .secondary)
            }

            HStack(spacing: 6) {
                Text(event.timeLabel(timeFormat24h: timeFormat24h))
                    .font(AppTypography.compactControl)
                    .foregroundStyle(Color.appPink)
                    .monospacedDigit()

                if !trimmedPetName.isEmpty {
                    Text("·")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.quaternary)
                    Text(trimmedPetName)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
