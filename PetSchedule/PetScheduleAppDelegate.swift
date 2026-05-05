import CloudKit
import UIKit

final class PetScheduleAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata, completionHandler: @escaping (Error?) -> Void) {
        let container = CKContainer.default()
        let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
        op.acceptSharesResultBlock = { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    UserDefaults.standard.set(true, forKey: UserDefaultsKeys.prefersSharedDatabase)
                    NotificationCenter.default.post(name: .householdCloudShareAccepted, object: nil)
                    completionHandler(nil)
                case .failure(let error):
                    completionHandler(error)
                }
            }
        }
        container.add(op)
    }
}
