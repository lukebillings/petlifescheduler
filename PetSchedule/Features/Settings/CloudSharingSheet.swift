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
        guard isPresented else {
            context.coordinator.preparationTask?.cancel()
            context.coordinator.preparationTask = nil
            context.coordinator.didBeginPresent = false
            if uiViewController.presentedViewController != nil {
                uiViewController.dismiss(animated: true)
            }
            return
        }

        guard !context.coordinator.didBeginPresent else { return }
        context.coordinator.didBeginPresent = true

        let coordinator = context.coordinator
        let host = uiViewController
        context.coordinator.preparationTask?.cancel()
        context.coordinator.preparationTask = Task {
            do {
                let privateDB = container.privateCloudDatabase
                let zone = CKRecordZone(zoneName: HouseholdCloudKitService.Constants.zoneName)
                do {
                    _ = try await privateDB.recordZone(for: zone.zoneID)
                } catch {
                    _ = try await privateDB.save(zone)
                }
                let root = try await HouseholdCloudKitService.shared.ensureRoot(database: privateDB, zoneID: zone.zoneID)
                let share = try await HouseholdCloudKitService.shared.loadOrCreateShare(
                    database: privateDB,
                    root: root,
                    zoneID: zone.zoneID
                )
                try Task.checkCancellation()
                await MainActor.run {
                    guard coordinator.isPresented else { return }
                    let controller = UICloudSharingController(share: share, container: container)
                    controller.availablePermissions = [.allowReadWrite]
                    controller.modalPresentationStyle = .formSheet
                    controller.delegate = coordinator
                    controller.presentationController?.delegate = coordinator
                    if host.presentedViewController == nil {
                        host.present(controller, animated: true)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    coordinator.didBeginPresent = false
                }
            } catch {
                await MainActor.run {
                    coordinator.dismissBinding()
                }
            }
        }
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        @Binding var isPresented: Bool
        var didBeginPresent = false
        var preparationTask: Task<Void, Never>?

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        fileprivate func dismissBinding() {
            didBeginPresent = false
            isPresented = false
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
            "PetSchedule household"
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }
    }
}
