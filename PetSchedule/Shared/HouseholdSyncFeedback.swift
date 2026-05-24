import SwiftUI
import UIKit
import UserNotifications

// MARK: - Remote change descriptions

struct HouseholdRemoteChange: Equatable {
    let message: String
    let actorDisplayName: String?
}

enum HouseholdChangeSummarizer {
    static func petAdded(_ pet: Pet) -> HouseholdRemoteChange {
        HouseholdRemoteChange(
            message: phrase(actor: nil, action: "added pet \(pet.name)"),
            actorDisplayName: nil
        )
    }

    static func petUpdated(_ pet: Pet) -> HouseholdRemoteChange {
        HouseholdRemoteChange(
            message: phrase(actor: nil, action: "updated \(pet.name)"),
            actorDisplayName: nil
        )
    }

    static func scheduleAdded(_ item: ScheduleItem) -> HouseholdRemoteChange {
        let actor = actorDisplayName(for: item, previous: nil)
        return HouseholdRemoteChange(
            message: phrase(actor: actor, action: "added \(schedulePhrase(item))"),
            actorDisplayName: actor
        )
    }

    static func scheduleUpdated(_ item: ScheduleItem, previous: ScheduleItem?) -> HouseholdRemoteChange {
        let actor = actorDisplayName(for: item, previous: previous)
        return HouseholdRemoteChange(
            message: phrase(actor: actor, action: "updated \(schedulePhrase(item))"),
            actorDisplayName: actor
        )
    }

    static func combinedMessage(for changes: [HouseholdRemoteChange]) -> String {
        guard !changes.isEmpty else { return "Your household schedule was updated" }
        if changes.count == 1 { return changes[0].message }
        if changes.count == 2 {
            return "\(changes[0].message) · \(changes[1].message)"
        }
        return "\(changes[0].message) and \(changes.count - 1) more updates"
    }

    static func notificationTitle(for changes: [HouseholdRemoteChange]) -> String {
        guard let first = changes.first else { return "PetLifeScheduler" }
        if let actor = first.actorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !actor.isEmpty {
            return actor
        }
        return "Household update"
    }

    /// Name from the other person's Settings → Your Name, when stored on the synced item.
    static func actorDisplayName(for item: ScheduleItem, previous: ScheduleItem?) -> String? {
        let local = UserProfileStorage.trimmedDisplayName()
        func pick(_ raw: String) -> String? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed != local else { return nil }
            return trimmed
        }
        if let previous,
           item.isCompleted != previous.isCompleted
            || item.completedByDisplayName != previous.completedByDisplayName {
            if let name = pick(item.completedByDisplayName) { return name }
        }
        if let name = pick(item.createdByDisplayName) { return name }
        if let name = pick(item.completedByDisplayName) { return name }
        return nil
    }

    private static func phrase(actor: String?, action: String) -> String {
        let trimmed = actor?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return "\(trimmed) \(action)"
        }
        guard let first = action.first else { return action }
        return String(first).uppercased() + action.dropFirst()
    }

    private static func schedulePhrase(_ item: ScheduleItem) -> String {
        let petName = item.pet.name
        if item.isBirthday { return "birthday for \(petName)" }
        if let kind = item.quickLogKind {
            return "\(kind.rawValue) for \(petName)"
        }
        let title = item.activityName.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "schedule for \(petName)" }
        return "\(title) for \(petName)"
    }
}

// MARK: - Push notifications (household updates)

enum HouseholdChangeNotifier {
    static let identifierPrefix = "petschedule.household-change."

    static func deliver(changes: [HouseholdRemoteChange]) {
        guard !changes.isEmpty else { return }
        guard UserDefaults.standard.bool(forKey: ScheduleReminderScheduler.storageEnabledKey) else { return }

        let body = HouseholdChangeSummarizer.combinedMessage(for: changes)
        let title = HouseholdChangeSummarizer.notificationTitle(for: changes)
        let state = UIApplication.shared.applicationState
        if state == .active {
            return
        }
        Task {
            await scheduleNotification(title: title, body: body)
        }
    }

    private static func scheduleNotification(title: String, body: String) async {
        _ = ScheduleReminderScheduler.ensureDelegate()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let authorized: Bool = {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: return true
            default: return false
            }
        }()
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifierPrefix + UUID().uuidString,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}

// MARK: - Pink in-app toast

struct HouseholdSyncToast: Equatable {
    let message: String
    let systemImage: String
}

struct HouseholdSyncToastBanner: View {
    let toast: HouseholdSyncToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.body.weight(.semibold))
            Text(toast.message)
                .font(AppTypography.secondaryLabel)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appPink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.appPink.opacity(0.35), radius: 12, y: 5)
    }
}

struct HouseholdSyncToastModifier: ViewModifier {
    @ObservedObject private var sync = HouseholdSyncCoordinator.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let toast = sync.activeToast {
                    HouseholdSyncToastBanner(toast: toast)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: sync.activeToast)
    }
}

extension View {
    func householdSyncToast() -> some View {
        modifier(HouseholdSyncToastModifier())
    }
}
