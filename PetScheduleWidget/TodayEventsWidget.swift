import SwiftUI
import UIKit
import WidgetKit

private let widgetPink = Color(red: 248 / 255, green: 78 / 255, blue: 166 / 255)

struct TodayEventsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayEventsWidget.kind, provider: TodayEventsProvider()) { entry in
            TodayEventsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's schedule")
        .description("Next upcoming events for your pets today.")
        .supportedFamilies([.systemSmall, .systemMedium])
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

    /// At most two upcoming events (defense in depth; payload should already cap).
    private var displayedEvents: [WidgetScheduleEventDTO] {
        Array(entry.events.prefix(2))
    }

    /// Medium + two cards needs tighter rows so nothing clips; small always compact.
    private var cardLayoutCompact: Bool {
        compactCards || (family == .systemMedium && displayedEvents.count >= 2)
    }

    private var title: String {
        Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var noEventsToday: Bool {
        entry.totalTodayEventCount == 0 && entry.events.isEmpty
    }

    private var allDoneToday: Bool {
        entry.events.isEmpty && entry.totalTodayEventCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compactCards ? 6 : 8) {
            Text(title)
                .font(compactCards ? .caption2.bold() : .subheadline.bold())
                .foregroundStyle(.secondary)

            if noEventsToday {
                Text("No events today")
                    .font(compactCards ? .subheadline.bold() : .body.bold())
                Text("Add some in PetSchedule")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if allDoneToday {
                Text("All done!")
                    .font(compactCards ? .headline.bold() : .title3.bold())
                    .foregroundStyle(widgetPink)
                Text("\(entry.totalTodayEventCount) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: compactCards ? 6 : 6) {
                    ForEach(displayedEvents) { ev in
                        WidgetScheduleEventCard(
                            event: ev,
                            timeFormat24h: entry.timeFormat24h,
                            compact: cardLayoutCompact
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Explicit insets — `widgetContentMargins` + `glassEffect` led to empty / clipped layouts on device.
        .padding(.horizontal, 10)
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

// MARK: - Card chrome like `ScheduleRowView` (material vs pink quick log; no `glassEffect` in widgets)

private struct WidgetPetAvatar: View {
    let jpegData: Data?
    let systemImageName: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let jpegData, let ui = UIImage(data: jpegData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: systemImageName ?? "pawprint.fill")
                    .font(.system(size: size * 0.38, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private struct WidgetScheduleEventCard: View {
    let event: WidgetScheduleEventDTO
    let timeFormat24h: Bool
    var compact: Bool

    private var isQuickLog: Bool { event.isQuickLog == true }

    private var avatarSize: CGFloat { compact ? 40 : 48 }
    private var iconWidth: CGFloat { compact ? 20 : 22 }

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            WidgetPetAvatar(
                jpegData: event.petPhotoJPEGData,
                systemImageName: event.petSystemImage,
                size: avatarSize
            )

            Image(systemName: event.activitySystemImage ?? "pawprint.fill")
                .font(compact ? .subheadline.bold() : .body.bold())
                .foregroundStyle(widgetPink)
                .frame(width: iconWidth)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.timeLabel(timeFormat24h: timeFormat24h))
                    .font(compact ? .subheadline.bold() : .headline.bold())
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                Text(event.activityName)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "circle")
                .font(compact ? .title3 : .title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, compact ? 14 : 18)
        .padding(.vertical, compact ? 11 : 16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isQuickLog ? AnyShapeStyle(widgetPink.opacity(0.2)) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isQuickLog ? widgetPink.opacity(0.35) : Color.primary.opacity(0.1),
                    lineWidth: 1
                )
        }
    }
}
