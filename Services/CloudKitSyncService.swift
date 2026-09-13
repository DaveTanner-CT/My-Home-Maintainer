import CloudKit
import Foundation
import SwiftData

enum CloudKitSyncError: LocalizedError {
    case iCloudUnavailable
    case noHousehold
    case noCloudSnapshot
    case noSharedHousehold
    case localStoreNotEmpty
    case invalidArchive

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloud is not available for My Home Keeper on this device. Make sure you are signed into iCloud and iCloud Drive is enabled."
        case .noHousehold:
            return "Create a household around this home before uploading it to iCloud."
        case .noCloudSnapshot:
            return "No My Home Keeper household snapshot was found in this iCloud account."
        case .noSharedHousehold:
            return "No shared My Home Keeper household was found. Accept the Apple sharing invitation first, then try again."
        case .localStoreNotEmpty:
            return "This device already contains home data. Use Replace Local Home from iCloud if you intentionally want to overwrite it."
        case .invalidArchive:
            return "The iCloud household archive could not be read."
        }
    }
}

struct CloudKitSnapshotSummary: Equatable {
    let householdID: String
    let householdName: String
    let homeName: String
    let updatedAt: Date
}

@MainActor
enum CloudKitSyncService {
    private static let zoneName = "MyHomeKeeperHousehold"
    private static let recordType = "HouseholdSnapshot"
    private static let assetField = "archiveAsset"
    private static let container = CKContainer.default()

    static var cloudContainer: CKContainer {
        container
    }

    static func prepareShare(household: Household) async throws -> CKShare {
        try await requireAvailableAccount()

        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: zoneName,
            ownerName: CKCurrentUserDefaultName
        )
        try await ensureZone(zoneID: zoneID, database: database)

        let recordID = CKRecord.ID(
            recordName: household.cloudIdentifier,
            zoneID: zoneID
        )

        let rootRecord = try await fetchRecord(recordID, database: database)

        if let existingShareReference = rootRecord.share {
            let existingRecord = try await fetchRecord(
                existingShareReference.recordID,
                database: database
            )
            if let existingShare = existingRecord as? CKShare {
                return existingShare
            }
        }

        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = household.name as CKRecordValue
        share.publicPermission = .none

        try await saveShare(
            rootRecord: rootRecord,
            share: share,
            database: database
        )

        return share
    }

    static func acceptShare(metadata: CKShare.Metadata) async throws {
        try await requireAvailableAccount()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.qualityOfService = .userInitiated
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    UserDefaults.standard.set(Date(), forKey: "HomeKeeperLastAcceptedCloudShareDate")
                    UserDefaults.standard.removeObject(forKey: "HomeKeeperLastCloudShareError")
                    continuation.resume(returning: ())
                case .failure(let error):
                    UserDefaults.standard.set(error.localizedDescription, forKey: "HomeKeeperLastCloudShareError")
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    static func latestSharedSnapshot() async throws -> CloudKitSnapshotSummary {
        let record = try await latestSharedSnapshotRecord()
        return summary(for: record)
    }

    static func downloadLatestSharedHouseholdIntoEmptyStore(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudKitSnapshotSummary {
        guard try HomeTransferService.isStoreEmpty(context: context) else {
            throw CloudKitSyncError.localStoreNotEmpty
        }

        let record = try await latestSharedSnapshotRecord()
        let archive = try archive(from: record)
        try HomeTransferService.importIntoEmptyStore(archive, context: context)
        try attachSharedHousehold(record: record, context: context, accountSession: accountSession)
        return summary(for: record)
    }

    static func replaceLocalHomeWithLatestSharedSnapshot(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudKitSnapshotSummary {
        let record = try await latestSharedSnapshotRecord()
        let archive = try archive(from: record)
        try deleteLocalHomeData(context: context)
        try HomeTransferService.importIntoEmptyStore(archive, context: context)
        try attachSharedHousehold(record: record, context: context, accountSession: accountSession)
        return summary(for: record)
    }

    static func uploadCurrentSharedHousehold(
        household: Household,
        context: ModelContext
    ) async throws -> CloudKitSnapshotSummary {
        try await requireAvailableAccount()
        let database = container.sharedCloudDatabase
        let record = try await sharedSnapshotRecord(recordName: household.cloudIdentifier)

        let archiveData = try HomeTransferService.encodedArchive(
            context: context,
            packageType: "CloudKit Shared Household"
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mhk-shared-cloudkit-\(UUID().uuidString).json")
        try archiveData.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let homeName = household.home?.name ?? "Home"
        record["householdName"] = household.name as CKRecordValue
        record["homeName"] = homeName as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        record["formatVersion"] = 1 as CKRecordValue
        record[assetField] = CKAsset(fileURL: tempURL)

        let saved = try await saveRecord(record, database: database)
        household.syncReady = true
        try context.save()
        return summary(for: saved)
    }

    static func accountStatusText() async -> String {
        do {
            switch try await accountStatus() {
            case .available: return "Available"
            case .noAccount: return "No iCloud Account"
            case .restricted: return "Restricted"
            case .couldNotDetermine: return "Unavailable"
            case .temporarilyUnavailable: return "Temporarily Unavailable"
            @unknown default: return "Unavailable"
            }
        } catch {
            return "Unavailable"
        }
    }

    static func uploadCurrentHousehold(
        household: Household,
        context: ModelContext
    ) async throws -> CloudKitSnapshotSummary {
        try await requireAvailableAccount()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        try await ensureZone(zoneID: zoneID, database: database)

        let archiveData = try HomeTransferService.encodedArchive(context: context, packageType: "CloudKit Private Backup")
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mhk-cloudkit-\(UUID().uuidString).json")
        try archiveData.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let recordID = CKRecord.ID(recordName: household.cloudIdentifier, zoneID: zoneID)
        let record: CKRecord
        do {
            record = try await fetchRecord(recordID, database: database)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        let homeName = household.home?.name ?? "Home"
        record["householdName"] = household.name as CKRecordValue
        record["homeName"] = homeName as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        record["formatVersion"] = 1 as CKRecordValue
        record[assetField] = CKAsset(fileURL: tempURL)

        let saved = try await saveRecord(record, database: database)
        let updatedAt = saved["updatedAt"] as? Date ?? Date()

        household.syncReady = true
        try context.save()

        return CloudKitSnapshotSummary(
            householdID: household.cloudIdentifier,
            householdName: household.name,
            homeName: homeName,
            updatedAt: updatedAt
        )
    }

    static func latestSnapshot() async throws -> CloudKitSnapshotSummary {
        try await requireAvailableAccount()
        let record = try await latestSnapshotRecord()
        return summary(for: record)
    }

    static func downloadLatestHouseholdIntoEmptyStore(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudKitSnapshotSummary {
        guard try HomeTransferService.isStoreEmpty(context: context) else {
            throw CloudKitSyncError.localStoreNotEmpty
        }

        let record = try await latestSnapshotRecord()
        let archive = try archive(from: record)
        try HomeTransferService.importIntoEmptyStore(archive, context: context)
        try attachHousehold(record: record, context: context, accountSession: accountSession)
        return summary(for: record)
    }

    static func replaceLocalHomeWithLatestSnapshot(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudKitSnapshotSummary {
        let record = try await latestSnapshotRecord()
        let archive = try archive(from: record)
        try deleteLocalHomeData(context: context)
        try HomeTransferService.importIntoEmptyStore(archive, context: context)
        try attachHousehold(record: record, context: context, accountSession: accountSession)
        return summary(for: record)
    }

    private static func latestSnapshotRecord() async throws -> CKRecord {
        try await requireAvailableAccount()
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        try await ensureZone(zoneID: zoneID, database: database)

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        let records = try await performQuery(query, zoneID: zoneID, database: database)
        guard let record = records.first else { throw CloudKitSyncError.noCloudSnapshot }
        return record
    }

    private static func latestSharedSnapshotRecord() async throws -> CKRecord {
        try await requireAvailableAccount()
        let database = container.sharedCloudDatabase
        let zones = try await allRecordZones(database: database)

        var matches: [CKRecord] = []
        for zone in zones {
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            do {
                let records = try await performQuery(query, zoneID: zone.zoneID, database: database)
                matches.append(contentsOf: records)
            } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
                continue
            }
        }

        guard let record = matches.max(by: {
            ($0["updatedAt"] as? Date ?? $0.modificationDate ?? .distantPast) <
            ($1["updatedAt"] as? Date ?? $1.modificationDate ?? .distantPast)
        }) else {
            throw CloudKitSyncError.noSharedHousehold
        }
        return record
    }

    private static func sharedSnapshotRecord(recordName: String) async throws -> CKRecord {
        try await requireAvailableAccount()
        let database = container.sharedCloudDatabase
        let zones = try await allRecordZones(database: database)

        for zone in zones {
            let recordID = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
            do {
                return try await fetchRecord(recordID, database: database)
            } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
                continue
            }
        }
        throw CloudKitSyncError.noSharedHousehold
    }

    private static func allRecordZones(database: CKDatabase) async throws -> [CKRecordZone] {
        try await withCheckedThrowingContinuation { continuation in
            database.fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: zones ?? [])
                }
            }
        }
    }

    private static func archive(from record: CKRecord) throws -> HomeTransferArchive {
        guard let asset = record[assetField] as? CKAsset,
              let fileURL = asset.fileURL,
              let data = try? Data(contentsOf: fileURL) else {
            throw CloudKitSyncError.invalidArchive
        }
        return try HomeTransferService.decode(data)
    }

    private static func summary(for record: CKRecord) -> CloudKitSnapshotSummary {
        CloudKitSnapshotSummary(
            householdID: record.recordID.recordName,
            householdName: record["householdName"] as? String ?? "Household",
            homeName: record["homeName"] as? String ?? "Home",
            updatedAt: record["updatedAt"] as? Date ?? record.modificationDate ?? .now
        )
    }

    private static func attachHousehold(
        record: CKRecord,
        context: ModelContext,
        accountSession: AccountSessionStore
    ) throws {
        let homes = try context.fetch(FetchDescriptor<Home>())
        let existingHouseholds = try context.fetch(FetchDescriptor<Household>())
        let householdName = record["householdName"] as? String ?? "Household"
        let cloudIdentifier = record.recordID.recordName
        let profile = accountSession.profile
        let userIdentifier = profile?.userIdentifier ?? "icloud-user"

        let household: Household
        if let existing = existingHouseholds.first {
            household = existing
            household.cloudIdentifier = cloudIdentifier
            household.name = householdName
            household.ownerUserIdentifier = userIdentifier
            household.syncReady = true
            household.home = homes.first
        } else {
            household = Household(
                cloudIdentifier: cloudIdentifier,
                name: householdName,
                ownerUserIdentifier: userIdentifier,
                adoptedExistingHome: false,
                syncReady: true,
                home: homes.first
            )
            context.insert(household)
        }

        if !household.members.contains(where: { $0.userIdentifier == userIdentifier }) {
            let member = HouseholdMember(
                userIdentifier: userIdentifier,
                displayName: profile?.displayName ?? "iCloud User",
                email: profile?.email ?? "",
                role: .owner,
                household: household
            )
            household.members.append(member)
            context.insert(member)
        }

        try context.save()
    }

    private static func attachSharedHousehold(
        record: CKRecord,
        context: ModelContext,
        accountSession: AccountSessionStore
    ) throws {
        let homes = try context.fetch(FetchDescriptor<Home>())
        let existingHouseholds = try context.fetch(FetchDescriptor<Household>())
        let householdName = record["householdName"] as? String ?? "Shared Household"
        let cloudIdentifier = record.recordID.recordName
        let profile = accountSession.profile
        let userIdentifier = profile?.userIdentifier ?? "icloud-shared-user"

        let household: Household
        if let existing = existingHouseholds.first {
            household = existing
            household.cloudIdentifier = cloudIdentifier
            household.name = householdName
            household.ownerUserIdentifier = "cloudkit-share-owner"
            household.syncReady = true
            household.home = homes.first
        } else {
            household = Household(
                cloudIdentifier: cloudIdentifier,
                name: householdName,
                ownerUserIdentifier: "cloudkit-share-owner",
                adoptedExistingHome: false,
                syncReady: true,
                home: homes.first
            )
            context.insert(household)
        }

        if !household.members.contains(where: { $0.userIdentifier == userIdentifier }) {
            let member = HouseholdMember(
                userIdentifier: userIdentifier,
                displayName: profile?.displayName ?? "Shared Member",
                email: profile?.email ?? "",
                role: .editor,
                household: household
            )
            household.members.append(member)
            context.insert(member)
        }

        try context.save()
    }

    private static func deleteLocalHomeData(context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<HomeAttachment>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<ProjectMeasurement>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<ProjectItem>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<MaintenanceRecord>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<MaintenanceTask>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<PaintFinish>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Furniture>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Fixture>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Appliance>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<HomeSystem>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Detector>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Consumable>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Project>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Vendor>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Room>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Home>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<HouseholdInvitation>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<HouseholdMember>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Household>()) { context.delete(item) }
        try context.save()
    }

    private static func requireAvailableAccount() async throws {
        guard try await accountStatus() == .available else {
            throw CloudKitSyncError.iCloudUnavailable
        }
    }

    private static func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: status) }
            }
        }
    }

    private static func ensureZone(zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecordZone, Error>) in
                database.save(zone) { savedZone, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let savedZone { continuation.resume(returning: savedZone) }
                    else { continuation.resume(throwing: CloudKitSyncError.iCloudUnavailable) }
                }
            }
        } catch let error as CKError where error.code == .serverRejectedRequest || error.code == .partialFailure {
            // The zone may already exist. Fetching/querying below will confirm availability.
        }
    }

    private static func saveShare(
        rootRecord: CKRecord,
        share: CKShare,
        database: CKDatabase
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(
                recordsToSave: [rootRecord, share],
                recordIDsToDelete: nil
            )
            operation.savePolicy = .changedKeys
            operation.isAtomic = true
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private static func saveRecord(_ record: CKRecord, database: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let error { continuation.resume(throwing: error) }
                else if let savedRecord { continuation.resume(returning: savedRecord) }
                else { continuation.resume(throwing: CloudKitSyncError.invalidArchive) }
            }
        }
    }

    private static func fetchRecord(_ recordID: CKRecord.ID, database: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let error { continuation.resume(throwing: error) }
                else if let record { continuation.resume(returning: record) }
                else { continuation.resume(throwing: CloudKitSyncError.noCloudSnapshot) }
            }
        }
    }

    private static func performQuery(_ query: CKQuery, zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            database.perform(query, inZoneWith: zoneID) { records, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: records ?? []) }
            }
        }
    }
}
