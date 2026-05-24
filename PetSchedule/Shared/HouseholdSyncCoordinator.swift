import Foundation
import SwiftUI
import UIKit

extension Notification.Name {
    static let householdCloudShareAccepted = Notification.Name("householdCloudShareAccepted")
    static let householdCloudKitRemoteChange = Notification.Name("householdCloudKitRemoteChange")
}

@MainActor
final class HouseholdSyncCoordinator: ObservableObject {
    static let shared = HouseholdSyncCoordinator()

    private static let modPrefix = "petschedule.ck.mod."

    private var debounceTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?
    private var periodicSyncTask: Task<Void, Never>?
    private var boundViewModel: HomeViewModel?

    private var pendingLocalSyncAcknowledgment = false
    private var uploadedRecordNamesThisSync = Set<String>()
    private var preSyncModificationTimes: [String: Date] = [:]

    @Published var lastErrorMessage: String?
    @Published var isSyncing = false
    @Published var activeToast: HouseholdSyncToast?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .householdCloudKitRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                await HouseholdSyncCoordinator.shared.handleRemoteCloudKitChange()
            }
        }
    }

    func handleRemoteCloudKitChange() async {
        guard let viewModel = boundViewModel else { return }
        await syncNow(viewModel, uploadLocalChanges: pendingLocalSyncAcknowledgment)
    }

    func bind(viewModel: HomeViewModel) {
        boundViewModel = viewModel
    }

    func scheduleCloudSync(from viewModel: HomeViewModel, acknowledgeWhenSynced: Bool = false) {
        if acknowledgeWhenSynced {
            pendingLocalSyncAcknowledgment = true
        }
        HouseholdLocalStore.save(viewModel: viewModel)
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await syncNow(viewModel)
        }
    }

    func syncNow(_ viewModel: HomeViewModel, uploadLocalChanges: Bool = true) async {
        guard await HouseholdCloudKitService.shared.accountAvailable() else { return }

        isSyncing = true
        defer { isSyncing = false }

        uploadedRecordNamesThisSync = []
        preSyncModificationTimes = snapshotModificationTimes()

        do {
            let (db, zoneID) = try await HouseholdCloudKitService.shared.resolveSyncContext()
            await HouseholdCloudKitService.shared.ensureDatabaseSubscription(database: db)

            let root = try await HouseholdCloudKitService.shared.ensureRoot(database: db, zoneID: zoneID)

            if uploadLocalChanges || pendingLocalSyncAcknowledgment {
                for pet in viewModel.pets {
                    let saved = try await HouseholdCloudKitService.shared.upsertPet(
                        pet,
                        database: db,
                        zoneID: zoneID,
                        rootRecordID: root.recordID
                    )
                    uploadedRecordNamesThisSync.insert(saved.recordID.recordName)
                    noteServerModification(recordName: saved.recordID.recordName, date: saved.modificationDate ?? .now)
                }

                for item in viewModel.scheduleItems where !item.isBirthday {
                    let saved = try await HouseholdCloudKitService.shared.upsertScheduleItem(
                        item,
                        database: db,
                        zoneID: zoneID,
                        rootRecordID: root.recordID
                    )
                    uploadedRecordNamesThisSync.insert(saved.recordID.recordName)
                    noteServerModification(recordName: saved.recordID.recordName, date: saved.modificationDate ?? .now)
                }
            }

            let remotePets = try await HouseholdCloudKitService.shared.fetchAllPets(database: db, zoneID: zoneID)
            let petChanges = mergePets(remotePets, into: viewModel)

            let remoteRows = try await HouseholdCloudKitService.shared.fetchAllSchedules(database: db, zoneID: zoneID)
            let scheduleChanges = mergeSchedules(remoteRows, into: viewModel)

            HouseholdLocalStore.save(viewModel: viewModel)
            viewModel.refreshWidgetsAndRemindersOnly()
            lastErrorMessage = nil

            let remoteChanges = petChanges + scheduleChanges
            if !remoteChanges.isEmpty {
                let summary = HouseholdChangeSummarizer.combinedMessage(for: remoteChanges)
                presentToast(message: summary, systemImage: "arrow.triangle.2.circlepath")
                HouseholdChangeNotifier.deliver(changes: remoteChanges)
            } else if pendingLocalSyncAcknowledgment {
                presentToast(message: "Synced with your household", systemImage: "checkmark.icloud.fill")
            }

            pendingLocalSyncAcknowledgment = false
        } catch {
            lastErrorMessage = Self.friendlyMessage(for: error)
        }
    }

    func startAutomaticPolling(with viewModel: HomeViewModel) {
        bind(viewModel: viewModel)
        periodicSyncTask?.cancel()
        periodicSyncTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                await syncNow(viewModel, uploadLocalChanges: pendingLocalSyncAcknowledgment)
            }
        }
    }

    func registerForRemoteNotificationsIfNeeded() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func presentToast(message: String, systemImage: String) {
        activeToast = HouseholdSyncToast(message: message, systemImage: systemImage)
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            guard !Task.isCancelled else { return }
            if activeToast?.message == message {
                activeToast = nil
            }
        }
    }

    private func snapshotModificationTimes() -> [String: Date] {
        var times: [String: Date] = [:]
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(Self.modPrefix) {
            let recordName = String(key.dropFirst(Self.modPrefix.count))
            times[recordName] = storedModification(recordName)
        }
        return times
    }

    private func isRemoteHouseholdChange(recordName: String, remoteModified: Date) -> Bool {
        if uploadedRecordNamesThisSync.contains(recordName) { return false }
        let previous = preSyncModificationTimes[recordName] ?? .distantPast
        return remoteModified > previous
    }

    /// Translates noisy CloudKit/Foundation errors into something a user can act on. The most common
    /// preventable case is the developer forgetting to deploy the CloudKit schema to Production
    /// after their first Development run.
    private static func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription
        let lower = raw.lowercased()

        if lower.contains("cannot create new type") && lower.contains("production schema") {
            return "Household sharing isn't fully set up yet. Please reach out to support — we're rolling out an update on our side."
        }
        if lower.contains("not authenticated") || lower.contains("icloud") && lower.contains("sign in") {
            return "Sign in to iCloud on this device to sync your household."
        }
        if lower.contains("not marked indexable") {
            return "Household sync needs an app update. Install the latest TestFlight build, then open the app again."
        }
        if lower.contains("oplock") {
            return "Sync conflict with iCloud. Changes will retry automatically."
        }
        return raw
    }

    func clearModificationCache() {
        let d = UserDefaults.standard
        for key in d.dictionaryRepresentation().keys where key.hasPrefix(Self.modPrefix) {
            d.removeObject(forKey: key)
        }
    }

    private func modKey(_ recordName: String) -> String { Self.modPrefix + recordName }

    private func storedModification(_ recordName: String) -> Date {
        let t = UserDefaults.standard.double(forKey: modKey(recordName))
        return t > 0 ? Date(timeIntervalSince1970: t) : .distantPast
    }

    private func noteServerModification(recordName: String, date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: modKey(recordName))
    }

    private func mergePets(_ remote: [(pet: Pet, modified: Date)], into vm: HomeViewModel) -> [HouseholdRemoteChange] {
        var changes: [HouseholdRemoteChange] = []
        var byId = Dictionary(uniqueKeysWithValues: vm.pets.map { ($0.id, $0) })

        for pair in remote {
            let recordName = pair.pet.id.uuidString
            guard pair.modified >= storedModification(recordName) else { continue }

            let fromHousehold = isRemoteHouseholdChange(recordName: recordName, remoteModified: pair.modified)
            let previous = byId[pair.pet.id]

            if fromHousehold {
                if previous == nil {
                    changes.append(HouseholdChangeSummarizer.petAdded(pair.pet))
                } else if previous != pair.pet {
                    changes.append(HouseholdChangeSummarizer.petUpdated(pair.pet))
                }
            }

            byId[pair.pet.id] = pair.pet
            noteServerModification(recordName: recordName, date: pair.modified)
        }

        let existingOrder = vm.pets.map(\.id)
        var ordered: [Pet] = []
        var seen = Set<UUID>()
        for id in existingOrder {
            if let p = byId[id] {
                ordered.append(p)
                seen.insert(id)
            }
        }
        for (id, p) in byId where !seen.contains(id) {
            ordered.append(p)
        }
        vm.pets = ordered
        return changes
    }

    private func mergeSchedules(
        _ remote: [(payload: ScheduleItemSyncPayload, attachment: Data?, modified: Date)],
        into vm: HomeViewModel
    ) -> [HouseholdRemoteChange] {
        let pets = vm.pets
        var changes: [HouseholdRemoteChange] = []
        var byId = Dictionary(uniqueKeysWithValues: vm.scheduleItems.filter { !$0.isBirthday }.map { ($0.id, $0) })

        for row in remote {
            let recordName = row.payload.id.uuidString
            guard row.modified >= storedModification(recordName) else { continue }
            guard let item = ScheduleItem(payload: row.payload, pets: pets, attachmentImageData: row.attachment) else { continue }

            let fromHousehold = isRemoteHouseholdChange(recordName: recordName, remoteModified: row.modified)
            let previous = byId[row.payload.id]

            if fromHousehold {
                if previous == nil {
                    changes.append(HouseholdChangeSummarizer.scheduleAdded(item))
                } else if scheduleContentChanged(previous: previous, next: item) {
                    changes.append(HouseholdChangeSummarizer.scheduleUpdated(item, previous: previous))
                }
            }

            byId[row.payload.id] = item
            noteServerModification(recordName: recordName, date: row.modified)
        }

        vm.scheduleItems = Array(byId.values).sorted { $0.time < $1.time }
        return changes
    }

    private func scheduleContentChanged(previous: ScheduleItem?, next: ScheduleItem) -> Bool {
        guard let previous else { return true }
        let enc = JSONEncoder()
        guard
            let a = try? enc.encode(previous.syncPayload),
            let b = try? enc.encode(next.syncPayload)
        else { return true }
        return a != b
    }
}
