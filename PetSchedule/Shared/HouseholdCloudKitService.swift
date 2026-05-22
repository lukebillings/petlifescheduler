import CloudKit
import Foundation

// MARK: - Schedule payload (no embedded Pet / binary attachments)

struct ScheduleItemSyncPayload: Codable {
    var id: UUID
    var time: Date
    var endTime: Date?
    var activityName: String
    var description: String
    var repeatRule: RepeatRule
    var petId: UUID
    var isCompleted: Bool
    var isAllDay: Bool
    var isBirthday: Bool
    var medicineAccepted: Bool?
    var quickLogKind: QuickLogKind?
    var petMood: PetMood?
    var createdByDisplayName: String
    var assignedToDisplayName: String
    var completedByDisplayName: String
    var assigneeAccentRaw: String

    enum CodingKeys: String, CodingKey {
        case id, time, endTime, activityName, description, repeatRule, petId
        case isCompleted, isAllDay, isBirthday, medicineAccepted, quickLogKind, petMood
        case createdByDisplayName, assignedToDisplayName, completedByDisplayName
        case assigneeAccentRaw
        case loggedByDisplayName
    }

    init(
        id: UUID,
        time: Date,
        endTime: Date?,
        activityName: String,
        description: String,
        repeatRule: RepeatRule,
        petId: UUID,
        isCompleted: Bool,
        isAllDay: Bool,
        isBirthday: Bool,
        medicineAccepted: Bool?,
        quickLogKind: QuickLogKind?,
        petMood: PetMood?,
        createdByDisplayName: String,
        assignedToDisplayName: String,
        completedByDisplayName: String,
        assigneeAccentRaw: String
    ) {
        self.id = id
        self.time = time
        self.endTime = endTime
        self.activityName = activityName
        self.description = description
        self.repeatRule = repeatRule
        self.petId = petId
        self.isCompleted = isCompleted
        self.isAllDay = isAllDay
        self.isBirthday = isBirthday
        self.medicineAccepted = medicineAccepted
        self.quickLogKind = quickLogKind
        self.petMood = petMood
        self.createdByDisplayName = createdByDisplayName
        self.assignedToDisplayName = assignedToDisplayName
        self.completedByDisplayName = completedByDisplayName
        self.assigneeAccentRaw = assigneeAccentRaw
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        time = try c.decode(Date.self, forKey: .time)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        activityName = try c.decode(String.self, forKey: .activityName)
        description = try c.decode(String.self, forKey: .description)
        repeatRule = try c.decode(RepeatRule.self, forKey: .repeatRule)
        petId = try c.decode(UUID.self, forKey: .petId)
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        isAllDay = try c.decode(Bool.self, forKey: .isAllDay)
        isBirthday = try c.decode(Bool.self, forKey: .isBirthday)
        medicineAccepted = try c.decodeIfPresent(Bool.self, forKey: .medicineAccepted)
        quickLogKind = try c.decodeIfPresent(QuickLogKind.self, forKey: .quickLogKind)
        petMood = try c.decodeIfPresent(PetMood.self, forKey: .petMood)
        createdByDisplayName = try c.decodeIfPresent(String.self, forKey: .createdByDisplayName) ?? ""
        assignedToDisplayName = try c.decodeIfPresent(String.self, forKey: .assignedToDisplayName) ?? ""
        completedByDisplayName = try c.decodeIfPresent(String.self, forKey: .completedByDisplayName) ?? ""
        assigneeAccentRaw = try c.decodeIfPresent(String.self, forKey: .assigneeAccentRaw) ?? ScheduleAssigneeAccent.pink.rawValue
        if createdByDisplayName.isEmpty,
           let legacy = try c.decodeIfPresent(String.self, forKey: .loggedByDisplayName)?
               .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacy.isEmpty
        {
            createdByDisplayName = legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(time, forKey: .time)
        try c.encodeIfPresent(endTime, forKey: .endTime)
        try c.encode(activityName, forKey: .activityName)
        try c.encode(description, forKey: .description)
        try c.encode(repeatRule, forKey: .repeatRule)
        try c.encode(petId, forKey: .petId)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encode(isAllDay, forKey: .isAllDay)
        try c.encode(isBirthday, forKey: .isBirthday)
        try c.encodeIfPresent(medicineAccepted, forKey: .medicineAccepted)
        try c.encodeIfPresent(quickLogKind, forKey: .quickLogKind)
        try c.encodeIfPresent(petMood, forKey: .petMood)
        try c.encode(createdByDisplayName, forKey: .createdByDisplayName)
        try c.encode(assignedToDisplayName, forKey: .assignedToDisplayName)
        try c.encode(completedByDisplayName, forKey: .completedByDisplayName)
        try c.encode(assigneeAccentRaw, forKey: .assigneeAccentRaw)
    }
}

extension ScheduleItem {
    var syncPayload: ScheduleItemSyncPayload {
        ScheduleItemSyncPayload(
            id: id,
            time: time,
            endTime: endTime,
            activityName: activityName,
            description: description,
            repeatRule: repeatRule,
            petId: pet.id,
            isCompleted: isCompleted,
            isAllDay: isAllDay,
            isBirthday: isBirthday,
            medicineAccepted: medicineAccepted,
            quickLogKind: quickLogKind,
            petMood: petMood,
            createdByDisplayName: createdByDisplayName,
            assignedToDisplayName: assignedToDisplayName,
            completedByDisplayName: completedByDisplayName,
            assigneeAccentRaw: assigneeAccent.rawValue
        )
    }

    init?(payload: ScheduleItemSyncPayload, pets: [Pet], attachmentImageData: Data?) {
        guard let pet = pets.first(where: { $0.id == payload.petId }) else { return nil }
        self.init(
            id: payload.id,
            time: payload.time,
            endTime: payload.endTime,
            activityName: payload.activityName,
            description: payload.description,
            repeatRule: payload.repeatRule,
            pet: pet,
            isCompleted: payload.isCompleted,
            isAllDay: payload.isAllDay,
            isBirthday: payload.isBirthday,
            medicineAccepted: payload.medicineAccepted,
            quickLogKind: payload.quickLogKind,
            petMood: payload.petMood,
            attachmentImageData: attachmentImageData,
            createdByDisplayName: payload.createdByDisplayName,
            assignedToDisplayName: payload.assignedToDisplayName,
            completedByDisplayName: payload.completedByDisplayName,
            assigneeAccent: ScheduleAssigneeAccent.decode(stored: payload.assigneeAccentRaw)
        )
    }
}

// MARK: - CloudKit service

enum HouseholdCloudError: LocalizedError {
    case iCloudUnavailable
    case notOwnerForShareSetup
    case missingPayload
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable: return "Sign in to iCloud to sync your household."
        case .notOwnerForShareSetup: return "Only the organizer can start sharing from this screen."
        case .missingPayload: return "Couldn’t read synced data from iCloud."
        case .decodeFailed: return "Couldn’t decode synced data."
        }
    }
}

final class HouseholdCloudKitService {
    static let shared = HouseholdCloudKitService()

    let container = CKContainer.default()

    private let payloadField = "payload"
    private let photoField = "photo"
    private let attachmentField = "attachment"
    /// CloudKit rejects empty record types for production schema deploy; root must have at least one field.
    private let householdMarkerField = "householdMarker"

    enum RecordType {
        static let root = "PetScheduleHouseholdRoot"
        static let pet = "PetSchedulePet"
        static let schedule = "PetScheduleScheduleItem"
    }

    enum Constants {
        static let zoneName = "PetScheduleHouseholdZone"
        static let rootName = "household-root"
        static let shareRecordNameKey = "petschedule.shareRecordName"
        static let householdMarkerValue = "v1"
    }

    private init() {}

    private func applyHouseholdMarker(to root: CKRecord) {
        root[householdMarkerField] = Constants.householdMarkerValue as CKRecordValue
    }

    func accountAvailable() async -> Bool {
        let status = (try? await container.accountStatus()) ?? .couldNotDetermine
        return status == .available
    }

    /// Shared DB first (participant); otherwise private DB zone for owner/solo.
    func resolveSyncContext() async throws -> (database: CKDatabase, zoneID: CKRecordZone.ID) {
        guard await accountAvailable() else { throw HouseholdCloudError.iCloudUnavailable }

        let sharedDB = container.sharedCloudDatabase
        let sharedZones = try await sharedDB.allRecordZones()
        if let zone = sharedZones.first(where: { $0.zoneID.zoneName == Constants.zoneName }) {
            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.prefersSharedDatabase)
            return (sharedDB, zone.zoneID)
        }

        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.prefersSharedDatabase)
        let privateDB = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: Constants.zoneName)
        do {
            _ = try await privateDB.recordZone(for: zone.zoneID)
        } catch {
            _ = try await privateDB.save(zone)
        }

        return (privateDB, zone.zoneID)
    }

    func ensureRoot(database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> CKRecord {
        let rid = CKRecord.ID(recordName: Constants.rootName, zoneID: zoneID)
        do {
            let root = try await database.record(for: rid)
            if database.databaseScope == .private, root[householdMarkerField] == nil {
                applyHouseholdMarker(to: root)
                return try await database.save(root)
            }
            return root
        } catch let error as CKError where error.code == .unknownItem {
            if database.databaseScope == .shared {
                throw HouseholdCloudError.missingPayload
            }
            let root = CKRecord(recordType: RecordType.root, recordID: rid)
            applyHouseholdMarker(to: root)
            return try await database.save(root)
        }
    }

    func fetchAllPets(database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> [(pet: Pet, modified: Date)] {
        let query = CKQuery(recordType: RecordType.pet, predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query, inZoneWith: zoneID)
        var out: [(Pet, Date)] = []
        for (_, match) in result.matchResults {
            guard case .success(let record) = match else { continue }
            guard let pet = decodePet(record: record) else { continue }
            let mod = record.modificationDate ?? record.creationDate ?? .distantPast
            out.append((pet, mod))
        }
        return out
    }

    func fetchAllSchedules(database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> [(payload: ScheduleItemSyncPayload, attachment: Data?, modified: Date)] {
        let query = CKQuery(recordType: RecordType.schedule, predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query, inZoneWith: zoneID)
        var out: [(ScheduleItemSyncPayload, Data?, Date)] = []
        for (_, match) in result.matchResults {
            guard case .success(let record) = match else { continue }
            guard let asset = record[self.payloadField] as? CKAsset,
                  let url = asset.fileURL,
                  let data = try? Data(contentsOf: url),
                  let payload = try? JSONDecoder().decode(ScheduleItemSyncPayload.self, from: data) else { continue }
            let attachment: Data?
            if let a = record[self.attachmentField] as? CKAsset, let u = a.fileURL {
                attachment = try? Data(contentsOf: u)
            } else {
                attachment = nil
            }
            let mod = record.modificationDate ?? record.creationDate ?? .distantPast
            out.append((payload, attachment, mod))
        }
        return out
    }

    func upsertPet(_ pet: Pet, database: CKDatabase, zoneID: CKRecordZone.ID, rootRecordID: CKRecord.ID) async throws -> CKRecord {
        let rid = CKRecord.ID(recordName: pet.id.uuidString, zoneID: zoneID)
        let record: CKRecord
        do {
            record = try await database.record(for: rid)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: RecordType.pet, recordID: rid)
        }
        // Hierarchical `parent` requires `CKReferenceAction.none`; `.deleteSelf` is only for normal reference fields.
        record.parent = CKRecord.Reference(recordID: rootRecordID, action: .none)

        var petCopy = pet
        let photo = petCopy.photoData
        petCopy.photoData = nil
        let json = try JSONEncoder().encode(petCopy)
        let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent("pet-\(pet.id.uuidString).json")
        try json.write(to: jsonURL, options: .atomic)
        record[self.payloadField] = CKAsset(fileURL: jsonURL)

        if let photo {
            let photoURL = FileManager.default.temporaryDirectory.appendingPathComponent("pet-photo-\(pet.id.uuidString).dat")
            try photo.write(to: photoURL, options: .atomic)
            record[self.photoField] = CKAsset(fileURL: photoURL)
        } else {
            record[self.photoField] = nil
        }

        return try await database.save(record)
    }

    func upsertScheduleItem(_ item: ScheduleItem, database: CKDatabase, zoneID: CKRecordZone.ID, rootRecordID: CKRecord.ID) async throws -> CKRecord {
        let rid = CKRecord.ID(recordName: item.id.uuidString, zoneID: zoneID)
        let record: CKRecord
        do {
            record = try await database.record(for: rid)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: RecordType.schedule, recordID: rid)
        }
        record.parent = CKRecord.Reference(recordID: rootRecordID, action: .none)

        let payload = item.syncPayload
        let json = try JSONEncoder().encode(payload)
        let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent("sched-\(item.id.uuidString).json")
        try json.write(to: jsonURL, options: .atomic)
        record[self.payloadField] = CKAsset(fileURL: jsonURL)

        if let img = item.attachmentImageData {
            let imgURL = FileManager.default.temporaryDirectory.appendingPathComponent("sched-att-\(item.id.uuidString).dat")
            try img.write(to: imgURL, options: .atomic)
            record[self.attachmentField] = CKAsset(fileURL: imgURL)
        } else {
            record[self.attachmentField] = nil
        }

        return try await database.save(record)
    }

    func deletePetRecord(petId: UUID, database: CKDatabase, zoneID: CKRecordZone.ID) async throws {
        let rid = CKRecord.ID(recordName: petId.uuidString, zoneID: zoneID)
        _ = try await database.deleteRecord(withID: rid)
    }

    func deleteScheduleRecord(itemId: UUID, database: CKDatabase, zoneID: CKRecordZone.ID) async throws {
        let rid = CKRecord.ID(recordName: itemId.uuidString, zoneID: zoneID)
        _ = try await database.deleteRecord(withID: rid)
    }

    // MARK: Sharing

    func loadOrCreateShare(database: CKDatabase, root: CKRecord, zoneID: CKRecordZone.ID) async throws -> CKShare {
        guard database.databaseScope == .private else {
            throw HouseholdCloudError.notOwnerForShareSetup
        }

        if let existingName = UserDefaults.standard.string(forKey: Constants.shareRecordNameKey) {
            let sid = CKRecord.ID(recordName: existingName, zoneID: zoneID)
            do {
                let existing = try await database.record(for: sid)
                if let share = existing as? CKShare {
                    return share
                }
                // Stale name pointed at a non-share record; avoid handing a bad object to UICloudSharingController.
                UserDefaults.standard.removeObject(forKey: Constants.shareRecordNameKey)
            } catch {
                // Fall through to create a new share.
            }
        }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "PetLifeScheduler household" as CKRecordValue
        share.publicPermission = .none

        // CloudKit requires the share and its root to be saved together the first time; saving only the share can fail or destabilize on device.
        let (saveResults, _) = try await database.modifyRecords(saving: [root, share], deleting: [])
        var savedShare: CKShare?
        for (_, result) in saveResults {
            switch result {
            case .success(let record):
                if let s = record as? CKShare { savedShare = s }
            case .failure(let error):
                throw error
            }
        }
        guard let ckShare = savedShare else {
            throw HouseholdCloudError.decodeFailed
        }
        UserDefaults.standard.set(ckShare.recordID.recordName, forKey: Constants.shareRecordNameKey)
        return ckShare
    }

    /// Returns the shareable iCloud URL for the household, creating the share if needed. Only
    /// owners can run this — participants don't own the share and can't generate invite links.
    /// Used when sharing the household invite via the system share sheet.
    func prepareInviteShareURL() async throws -> URL? {
        guard await accountAvailable() else { throw HouseholdCloudError.iCloudUnavailable }
        let privateDB = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: Constants.zoneName)
        do {
            _ = try await privateDB.recordZone(for: zone.zoneID)
        } catch {
            _ = try await privateDB.save(zone)
        }
        let root = try await ensureRoot(database: privateDB, zoneID: zone.zoneID)
        let share = try await loadOrCreateShare(database: privateDB, root: root, zoneID: zone.zoneID)
        return share.url
    }

    func fetchExistingShareIfPossible(database: CKDatabase, zoneID: CKRecordZone.ID) async -> CKShare? {
        guard let name = UserDefaults.standard.string(forKey: Constants.shareRecordNameKey) else { return nil }
        let sid = CKRecord.ID(recordName: name, zoneID: zoneID)
        do {
            let rec = try await database.record(for: sid)
            return rec as? CKShare
        } catch {
            return nil
        }
    }

    /// People invited to the CloudKit household (not Apple Family — Apple does not expose that list to apps).
    func fetchHouseholdShareParticipants() async -> [HouseholdShareParticipantRow] {
        guard await accountAvailable() else { return [] }
        let privateDB = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: Constants.zoneName)
        do {
            _ = try await privateDB.recordZone(for: zone.zoneID)
        } catch {
            return []
        }
        guard let share = await fetchExistingShareIfPossible(database: privateDB, zoneID: zone.zoneID) else {
            return []
        }
        return Self.participantRows(from: share)
    }

    private static func participantRows(from share: CKShare) -> [HouseholdShareParticipantRow] {
        share.participants.compactMap { participant in
            guard participant.role != .owner else { return nil }
            let name = displayName(for: participant)
            let status: String
            switch participant.acceptanceStatus {
            case .accepted:
                status = "Joined"
            case .pending:
                status = "Waiting to accept"
            case .unknown:
                status = "Invite sent"
            @unknown default:
                status = "Invite sent"
            }
            return HouseholdShareParticipantRow(
                id: participant.userIdentity.lookupInfo?.userRecordID?.recordName ?? name,
                displayName: name,
                status: status
            )
        }
    }

    private static func displayName(for participant: CKShare.Participant) -> String {
        if let components = participant.userIdentity.nameComponents {
            let formatted = PersonNameComponentsFormatter.localizedString(from: components, style: .default, options: [])
            if !formatted.isEmpty { return formatted }
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress, !email.isEmpty {
            return email
        }
        return "Family member"
    }

    // MARK: Decode

    private func decodePet(record: CKRecord) -> Pet? {
        guard let asset = record[self.payloadField] as? CKAsset,
              let url = asset.fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        guard var pet = try? JSONDecoder().decode(Pet.self, from: data) else { return nil }
        if let pAsset = record[self.photoField] as? CKAsset,
           let pURL = pAsset.fileURL,
           let pdata = try? Data(contentsOf: pURL) {
            pet.photoData = pdata
        }
        return pet
    }
}


struct HouseholdShareParticipantRow: Identifiable, Equatable {
    let id: String
    let displayName: String
    let status: String
}

enum UserDefaultsKeys {
    static let prefersSharedDatabase = "petschedule.cloud.prefersSharedDatabase"
}
