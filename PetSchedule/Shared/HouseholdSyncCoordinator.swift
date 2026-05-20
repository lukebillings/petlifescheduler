import Foundation
import SwiftUI

extension Notification.Name {
    static let householdCloudShareAccepted = Notification.Name("householdCloudShareAccepted")
}

@MainActor
final class HouseholdSyncCoordinator: ObservableObject {
    static let shared = HouseholdSyncCoordinator()

    private static let modPrefix = "petschedule.ck.mod."

    private var debounceTask: Task<Void, Never>?

    @Published var lastErrorMessage: String?
    @Published var isSyncing = false

    private init() {}

    func scheduleCloudSync(from viewModel: HomeViewModel) {
        HouseholdLocalStore.save(viewModel: viewModel)
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            await syncNow(viewModel)
        }
    }

    func syncNow(_ viewModel: HomeViewModel) async {
        guard await HouseholdCloudKitService.shared.accountAvailable() else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let (db, zoneID) = try await HouseholdCloudKitService.shared.resolveSyncContext()
            let root = try await HouseholdCloudKitService.shared.ensureRoot(database: db, zoneID: zoneID)

            for pet in viewModel.pets {
                let saved = try await HouseholdCloudKitService.shared.upsertPet(
                    pet,
                    database: db,
                    zoneID: zoneID,
                    rootRecordID: root.recordID
                )
                noteServerModification(recordName: saved.recordID.recordName, date: saved.modificationDate ?? .now)
            }

            for item in viewModel.scheduleItems where !item.isBirthday {
                let saved = try await HouseholdCloudKitService.shared.upsertScheduleItem(
                    item,
                    database: db,
                    zoneID: zoneID,
                    rootRecordID: root.recordID
                )
                noteServerModification(recordName: saved.recordID.recordName, date: saved.modificationDate ?? .now)
            }

            let remotePets = try await HouseholdCloudKitService.shared.fetchAllPets(database: db, zoneID: zoneID)
            mergePets(remotePets, into: viewModel)

            let remoteRows = try await HouseholdCloudKitService.shared.fetchAllSchedules(database: db, zoneID: zoneID)
            mergeSchedules(remoteRows, into: viewModel)

            HouseholdLocalStore.save(viewModel: viewModel)
            viewModel.syncWidgetSchedule()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = Self.friendlyMessage(for: error)
        }
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

    private func mergePets(_ remote: [(pet: Pet, modified: Date)], into vm: HomeViewModel) {
        var byId = Dictionary(uniqueKeysWithValues: vm.pets.map { ($0.id, $0) })
        for pair in remote {
            let recordName = pair.pet.id.uuidString
            if pair.modified >= storedModification(recordName) {
                byId[pair.pet.id] = pair.pet
                noteServerModification(recordName: recordName, date: pair.modified)
            }
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
    }

    private func mergeSchedules(_ remote: [(payload: ScheduleItemSyncPayload, attachment: Data?, modified: Date)], into vm: HomeViewModel) {
        let pets = vm.pets
        var byId = Dictionary(uniqueKeysWithValues: vm.scheduleItems.filter { !$0.isBirthday }.map { ($0.id, $0) })

        for row in remote {
            let recordName = row.payload.id.uuidString
            guard row.modified >= storedModification(recordName) else { continue }
            if let item = ScheduleItem(payload: row.payload, pets: pets, attachmentImageData: row.attachment) {
                byId[row.payload.id] = item
                noteServerModification(recordName: recordName, date: row.modified)
            }
        }

        vm.scheduleItems = Array(byId.values).sorted { $0.time < $1.time }
    }
}
