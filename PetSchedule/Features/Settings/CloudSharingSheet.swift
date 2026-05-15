import CloudKit
import SwiftUI
import UIKit

/// Hosts `UICloudSharingController` for inviting household members via CloudKit.
struct CloudSharingSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let container: CKContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator

        guard isPresented else {
            coordinator.prepareTask?.cancel()
            coordinator.prepareTask = nil
            coordinator.didBeginPresent = false
            if uiViewController.presentedViewController != nil {
                uiViewController.dismiss(animated: true)
            }
            return
        }

        guard !coordinator.didBeginPresent else { return }
        coordinator.didBeginPresent = true

        let host = uiViewController
        DispatchQueue.main.async {
            Self.startPresentingShare(from: host, container: container, coordinator: coordinator)
        }
    }

    /// Waits for a `window`, loads the `CKShare` off the main thread, then presents `UICloudSharingController(share:container:)` (non-deprecated).
    private static func startPresentingShare(from host: UIViewController, container: CKContainer, coordinator: Coordinator) {
        func tryStart(attempt: Int) {
            guard coordinator.isPresentedBinding else {
                coordinator.didBeginPresent = false
                return
            }
            guard host.presentedViewController == nil else { return }

            let windowReady = host.viewIfLoaded?.window != nil
            if !windowReady, attempt < 30 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    tryStart(attempt: attempt + 1)
                }
                return
            }

            coordinator.prepareTask?.cancel()
            coordinator.prepareTask = Task {
                do {
                    let share = try await prepareShare(container: container)
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard coordinator.isPresentedBinding else {
                            coordinator.didBeginPresent = false
                            return
                        }

                        let sharingController = UICloudSharingController(share: share, container: container)
                        sharingController.availablePermissions = [.allowReadWrite]
                        sharingController.modalPresentationStyle = .pageSheet
                        sharingController.delegate = coordinator
                        sharingController.presentationController?.delegate = coordinator

                        DispatchQueue.main.async {
                            guard coordinator.isPresentedBinding else { return }
                            guard host.presentedViewController == nil else { return }
                            host.present(sharingController, animated: true)
                        }
                    }
                } catch {
                    await MainActor.run {
                        coordinator.dismissBinding()
                    }
                }
            }
        }

        tryStart(attempt: 0)
    }

    private static func prepareShare(container: CKContainer) async throws -> CKShare {
        let privateDB = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: HouseholdCloudKitService.Constants.zoneName)
        do {
            _ = try await privateDB.recordZone(for: zone.zoneID)
        } catch {
            _ = try await privateDB.save(zone)
        }
        let root = try await HouseholdCloudKitService.shared.ensureRoot(
            database: privateDB,
            zoneID: zone.zoneID
        )
        return try await HouseholdCloudKitService.shared.loadOrCreateShare(
            database: privateDB,
            root: root,
            zoneID: zone.zoneID
        )
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        /// Stored as a plain `Binding` — `@Binding` must not be used on `NSObject` subclasses (runtime issues).
        var isPresented: Binding<Bool>
        var didBeginPresent = false
        var prepareTask: Task<Void, Never>?

        fileprivate var isPresentedBinding: Bool { isPresented.wrappedValue }

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        fileprivate func dismissBinding() {
            prepareTask?.cancel()
            prepareTask = nil
            didBeginPresent = false
            isPresented.wrappedValue = false
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            dismissBinding()
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            dismissBinding()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            dismissBinding()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            dismissBinding()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "PetLifeScheduler household"
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }
    }
}
