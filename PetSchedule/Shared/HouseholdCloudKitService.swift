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

    enum RecordType {
        static let root = "PetScheduleHouseholdRoot"
        static let pet = "PetSchedulePet"
        static let schedule = "PetScheduleScheduleItem"
    }

    enum Constants {
        static let zoneName = "PetScheduleHouseholdZone"
        static let rootName = "household-root"
        static let shareRecordNameKey = "petschedule.shareRecordName"
    }

    private init() {}

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
            return try await database.record(for: rid)
        } catch let error as CKError where error.code == .unknownItem {
            if database.databaseScope == .shared {
                throw HouseholdCloudError.missingPayload
            }
            let root = CKRecord(recordType: RecordType.root, recordID: rid)
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
        record.parent = CKRecord.Reference(recordID: rootRecordID, action: .deleteSelf)

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
        record.parent = CKRecord.Reference(recordID: rootRecordID, action: .deleteSelf)

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
            } catch {
                // Fall through to create a new share.
            }
        }

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "PetSchedule household" as CKRecordValue
        share.publicPermission = .none

        let saved = try await database.save(share)
        guard let ckShare = saved as? CKShare else {
            throw HouseholdCloudError.decodeFailed
        }
        UserDefaults.standard.set(ckShare.recordID.recordName, forKey: Constants.shareRecordNameKey)
        return ckShare
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


enum UserDefaultsKeys {
    static let prefersSharedDatabase = "petschedule.cloud.prefersSharedDatabase"
}
