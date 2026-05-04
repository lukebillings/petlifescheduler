import SwiftUI
import UIKit
import WidgetKit

private let widgetPink = Color(red: 248 / 255, green: 78 / 255, blue: 166 / 255)

/// Dark text always readable on forced white cards (widgets can be in dark appearance; `.label` would be near-white).
private let widgetCardText = Color(red: 0.12, green: 0.12, blue: 0.14)
private let widgetCardTextSecondary = Color(red: 0.38, green: 0.38, blue: 0.42)

struct TodayEventsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayEventsWidget.kind, provider: TodayEventsProvider()) { entry in
            TodayEventsWidgetView(entry: entry)
                .containerBackground(widgetPink, for: .widget)
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

    /// Tighter rows when space is tight (many cards or small widget).
    private var cardLayoutCompact: Bool {
        if compactCards { return true }
        if isLargeFamily { return displayedEvents.count >= 3 }
        return family == .systemMedium && displayedEvents.count >= 2
    }

    private var noEventsToday: Bool {
        entry.totalTodayEventCount == 0 && entry.events.isEmpty
    }

    private var allDoneToday: Bool {
        entry.events.isEmpty && entry.totalTodayEventCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compactCards ? 6 : (isLargeFamily ? 10 : 8)) {
            if noEventsToday {
                Text("No events today")
                    .font(compactCards ? .subheadline.bold() : .body.bold())
                    .foregroundStyle(.white)
                Text("Add some in PetSchedule")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            } else if allDoneToday {
                Text("All done!")
                    .font(compactCards ? .headline.bold() : .title3.bold())
                    .foregroundStyle(.white)
                Text("\(entry.totalTodayEventCount) completed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                VStack(alignment: .leading, spacing: compactCards ? 6 : (isLargeFamily ? 8 : 6)) {
                    ForEach(displayedEvents) { ev in
                        WidgetScheduleEventCard(
                            event: ev,
                            timeFormat24h: entry.timeFormat24h,
                            compact: cardLayoutCompact,
                            widgetFamily: family
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Explicit insets — `widgetContentMargins` + `glassEffect` led to empty / clipped layouts on device.
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
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

// MARK: - White cards on app-pink background (quick log: pink stroke)

private struct WidgetPetAvatar: View {
    let jpegData: Data?
    let systemImageName: String?
    let size: CGFloat

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
                    .foregroundStyle(widgetCardTextSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(Circle())
    }
}

private struct WidgetScheduleEventCard: View {
    let event: WidgetScheduleEventDTO
    let timeFormat24h: Bool
    var compact: Bool
    var widgetFamily: WidgetFamily

    private var isQuickLog: Bool { event.isQuickLog == true }

    private var avatarSize: CGFloat {
        if widgetFamily == .systemLarge { return compact ? 52 : 64 }
        return compact ? 40 : 48
    }

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 14) {
            WidgetPetAvatar(
                jpegData: event.petPhotoJPEGData,
                systemImageName: event.petSystemImage,
                size: avatarSize
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(event.timeLabel(timeFormat24h: timeFormat24h))
                    .font(compact ? .subheadline.bold() : .headline.bold())
                    .foregroundStyle(widgetCardText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                Text(event.activityName)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(widgetCardTextSecondary)
                    .lineLimit(2)
                if widgetFamily == .systemLarge, !event.petName.isEmpty {
                    Text(event.petName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(widgetCardTextSecondary.opacity(0.95))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 14 : 18)
        .padding(.vertical, compact ? 11 : 16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isQuickLog ? widgetPink.opacity(0.45) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        }
    }
}
