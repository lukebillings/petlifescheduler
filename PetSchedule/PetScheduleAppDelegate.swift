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
        Task { @MainActor in
            let result = await HouseholdSyncCoordinator.shared.handleRemoteCloudKitChange()
            completionHandler(result)
        }
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

}
