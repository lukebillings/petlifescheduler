import CloudKit
import UIKit

final class PetScheduleAppDelegate: NSObject, UIApplicationDelegate {
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
