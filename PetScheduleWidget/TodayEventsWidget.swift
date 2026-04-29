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
                .containerBackground(Color(uiColor: .systemGroupedBackground), for: .widget)
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

    private var noEventsToday: Bool {
        entry.totalTodayEventCount == 0 && entry.events.isEmpty
    }

    private var allDoneToday: Bool {
        entry.events.isEmpty && entry.totalTodayEventCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compactCards ? 6 : 8) {
            if noEventsToday {
                Text("No events today")
                    .font(compactCards ? .subheadline.bold() : .body.bold())
                    .foregroundStyle(.primary)
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

// MARK: - White cards on grouped background (quick log: pink stroke; no `glassEffect` in widgets)

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
        .scaleEffect(1.14)
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
                    .foregroundStyle(widgetCardText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                Text(event.activityName)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(widgetCardTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "circle")
                .font(compact ? .title3 : .title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(widgetCardText.opacity(0.55))
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
