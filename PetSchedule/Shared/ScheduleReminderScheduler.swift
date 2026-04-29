import Foundation
import UserNotifications

/// Aligns with `SettingsView` `@AppStorage` keys — **local** notifications for upcoming events (no server / TestFlight required).
enum ScheduleReminderScheduler {

    private static let storageEnabledKey = "remindersEnabled"
    private static let storageMinutesKey = "reminderMinutes"
    static let notificationIdentifierPrefix = "petschedule.event-reminder."

    /// Ensures banners appear while the app is in the foreground (otherwise easy to think reminders “don’t work”).
    private static let delegateBootstrap: Void = {
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
    }()

    /// Removes previously scheduled PetSchedule reminders and schedules up to the next occurrences for eligible items.
    static func reschedule(for items: [ScheduleItem]) {
        _ = delegateBootstrap
        Task {
            await rescheduleAsync(for: items)
        }
    }

    private static func rescheduleAsync(for items: [ScheduleItem]) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.filter { $0.identifier.hasPrefix(notificationIdentifierPrefix) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard UserDefaults.standard.bool(forKey: storageEnabledKey) else { return }

        let rawLead = UserDefaults.standard.integer(forKey: storageMinutesKey)
        let leadMinutes = rawLead > 0 ? rawLead : 10

        let auth = await center.notificationSettings().authorizationStatus
        guard auth == .authorized || auth == .provisional || auth == .ephemeral else { return }

        let now = Date()
        let cal = Calendar.current
        let timeFormat = TimeFormat.current

        struct Candidate {
            let item: ScheduleItem
            let occurrenceStart: Date
            let fireAt: Date
        }

        var candidates: [Candidate] = []

        for item in items {
            guard !item.isCompleted else { continue }
            guard item.quickLogKind == nil else { continue }

            guard let nextStart = nextOccurrenceStart(of: item, after: now, calendar: cal) else { continue }
            guard let reminderFire = cal.date(byAdding: .minute, value: -leadMinutes, to: nextStart) else { continue }
            guard reminderFire > now else { continue }

            candidates.append(Candidate(item: item, occurrenceStart: nextStart, fireAt: reminderFire))
        }

        candidates.sort { $0.fireAt < $1.fireAt }

        // Pending local notification cap (practical limit per app).
        for candidate in candidates.prefix(60) {
            let item = candidate.item
            let content = UNMutableNotificationContent()
            content.title = "\(item.pet.name): \(item.activityName)"
            content.body = bodyText(
                occurrenceStart: candidate.occurrenceStart,
                isAllDay: item.isAllDay,
                timeFormat: timeFormat
            )
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.fireAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(
                identifier: notificationIdentifierPrefix + item.id.uuidString,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                break
            }
        }
    }

    private static func bodyText(occurrenceStart: Date, isAllDay: Bool, timeFormat: TimeFormat) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        if timeFormat == .twelveHour {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "HH:mm"
        }
        let t = formatter.string(from: occurrenceStart)
        if isAllDay {
            return "All day · \(t)"
        }
        return "Starts at \(t)"
    }
}

// MARK: - Next occurrence

private func nextOccurrenceStart(of item: ScheduleItem, after date: Date, calendar cal: Calendar) -> Date? {
    let template = item.time

    switch item.repeatRule {
    case .never:
        return template > date ? template : nil

    case .daily:
        var c = DateComponents()
        c.hour = cal.component(.hour, from: template)
        c.minute = cal.component(.minute, from: template)
        c.second = 0
        return cal.nextDate(after: date, matching: c, matchingPolicy: .nextTime)

    case .weekly:
        var c = DateComponents()
        c.weekday = cal.component(.weekday, from: template)
        c.hour = cal.component(.hour, from: template)
        c.minute = cal.component(.minute, from: template)
        c.second = 0
        return cal.nextDate(after: date, matching: c, matchingPolicy: .nextTime)

    case .weekdays:
        return nextWeekdayOccurrence(after: date, template: template, calendar: cal)

    case .weekends:
        return nextWeekendOccurrence(after: date, template: template, calendar: cal)

    case .monthly:
        var c = DateComponents()
        c.day = cal.component(.day, from: template)
        c.hour = cal.component(.hour, from: template)
        c.minute = cal.component(.minute, from: template)
        c.second = 0
        return cal.nextDate(after: date, matching: c, matchingPolicy: .nextTime)
    }
}

private func nextWeekdayOccurrence(after date: Date, template: Date, calendar cal: Calendar) -> Date? {
    let hour = cal.component(.hour, from: template)
    let minute = cal.component(.minute, from: template)

    let baseDay = cal.startOfDay(for: date)
    for offset in 0..<14 {
        guard let day = cal.date(byAdding: .day, value: offset, to: baseDay) else { continue }
        let weekday = cal.component(.weekday, from: day)
        guard weekday >= 2 && weekday <= 6 else { continue }
        guard let atTime = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
        if atTime > date { return atTime }
    }
    return nil
}

private func nextWeekendOccurrence(after date: Date, template: Date, calendar cal: Calendar) -> Date? {
    let hour = cal.component(.hour, from: template)
    let minute = cal.component(.minute, from: template)

    let baseDay = cal.startOfDay(for: date)
    for offset in 0..<14 {
        guard let day = cal.date(byAdding: .day, value: offset, to: baseDay) else { continue }
        let weekday = cal.component(.weekday, from: day)
        guard weekday == 1 || weekday == 7 else { continue }
        guard let atTime = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
        if atTime > date { return atTime }
    }
    return nil
}

// MARK: - Foreground banners

private final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresentationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
