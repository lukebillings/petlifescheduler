import SwiftUI
import UIKit
import UserNotifications

// MARK: - Remote change descriptions

struct HouseholdRemoteChange: Equatable {
    let message: String
}

enum HouseholdChangeSummarizer {
    static func petAdded(_ pet: Pet) -> HouseholdRemoteChange {
        HouseholdRemoteChange(message: "Added pet \(pet.name)")
    }

    static func petUpdated(_ pet: Pet) -> HouseholdRemoteChange {
        HouseholdRemoteChange(message: "Updated \(pet.name)")
    }

    static func scheduleAdded(_ item: ScheduleItem) -> HouseholdRemoteChange {
        HouseholdRemoteChange(message: "Added \(schedulePhrase(item))")
    }

    static func scheduleUpdated(_ item: ScheduleItem) -> HouseholdRemoteChange {
        HouseholdRemoteChange(message: "Updated \(schedulePhrase(item))")
    }

    static func combinedMessage(for changes: [HouseholdRemoteChange]) -> String {
        guard !changes.isEmpty else { return "Household schedule updated" }
        if changes.count == 1 { return changes[0].message }
        if changes.count == 2 {
            return "\(changes[0].message) · \(changes[1].message)"
        }
        return "\(changes[0].message) and \(changes.count - 1) more updates"
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
        let body = HouseholdChangeSummarizer.combinedMessage(for: changes)
        let state = UIApplication.shared.applicationState
        if state == .active {
            return
        }
        Task {
            await scheduleNotification(body: body)
        }
    }

    private static func scheduleNotification(body: String) async {
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
        content.title = "Household update"
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
