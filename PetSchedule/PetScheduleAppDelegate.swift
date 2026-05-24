import CloudKit
import UIKit

final class PetScheduleAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = ScheduleReminderScheduler.ensureDelegate()
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {}

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {}

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completionHandler(.noData)
            return
        }
        NotificationCenter.default.post(name: .householdCloudKitRemoteChange, object: nil)
        completionHandler(.newData)
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await HouseholdCloudKitService.shared.acceptIncomingShare(metadata: metadata)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard HouseholdCloudKitService.isLikelyCloudKitShareURL(url) else { return false }
        Task {
            try? await HouseholdCloudKitService.shared.acceptIncomingShare(url: url)
        }
        return true
    }
}
