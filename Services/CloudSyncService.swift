import Foundation
import SwiftData

struct CloudSnapshotSummary: Equatable {
    let householdID: String
    let householdName: String
    let homeName: String
    let updatedAt: Date
}

enum CloudSyncError: LocalizedError {
    case notConfigured
    case notSignedIn
    case noHousehold
    case noCloudSnapshot
    case localStoreNotEmpty
    case invalidServerResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured for this build yet."
        case .notSignedIn:
            return "Sign in with Apple before using cloud sync."
        case .noHousehold:
            return "Create a household on the device that already contains your home data first."
        case .noCloudSnapshot:
            return "No cloud household snapshot was found for this account."
        case .localStoreNotEmpty:
            return "This device already contains home data. Initial cloud download is only allowed into an empty home-data store so existing records are not overwritten."
        case .invalidServerResponse:
            return "Supabase returned an unexpected response."
        case .server(let message):
            return message
        }
    }
}

@MainActor
enum CloudSyncService {
    private struct SnapshotRow: Decodable {
        let id: String
        let owner_user_id: String
        let household_name: String
        let home_name: String?
        let archive: HomeTransferArchive
        let updated_at: Date
    }

    static func uploadCurrentHousehold(
        household: Household,
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudSnapshotSummary {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard accountSession.isSignedIn else { throw CloudSyncError.notSignedIn }
        guard let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudSyncError.notSignedIn }

        let token = try await accountSession.validCloudAccessToken()
        let archive = try cloudArchive(context: context)
        let archiveData = try encodeArchive(archive)
        let archiveObject = try JSONSerialization.jsonObject(with: archiveData)

        let updatedAt = Date()
        let body: [String: Any] = [
            "id": household.cloudIdentifier,
            "owner_user_id": cloudUserID,
            "household_name": household.name,
            "home_name": household.home?.name ?? archive.home?.name ?? "Home",
            "archive": archiveObject,
            "updated_at": ISO8601DateFormatter().string(from: updatedAt)
        ]

        var request = try makeRequest(
            path: "/rest/v1/household_snapshots?on_conflict=id",
            method: "POST",
            accessToken: token
        )
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        household.syncReady = true
        try context.save()

        return CloudSnapshotSummary(
            householdID: household.cloudIdentifier,
            householdName: household.name,
            homeName: household.home?.name ?? archive.home?.name ?? "Home",
            updatedAt: updatedAt
        )
    }

    static func latestSnapshot(
        accountSession: AccountSessionStore
    ) async throws -> CloudSnapshotSummary {
        let row = try await latestSnapshotRow(accountSession: accountSession)
        return CloudSnapshotSummary(
            householdID: row.id,
            householdName: row.household_name,
            homeName: row.home_name ?? row.archive.home?.name ?? "Home",
            updatedAt: row.updated_at
        )
    }

    static func downloadLatestHouseholdIntoEmptyStore(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudSnapshotSummary {
        guard try HomeTransferService.isStoreEmpty(context: context) else {
            throw CloudSyncError.localStoreNotEmpty
        }
        guard let profile = accountSession.profile else { throw CloudSyncError.notSignedIn }

        let row = try await latestSnapshotRow(accountSession: accountSession)
        try HomeTransferService.importIntoEmptyStore(row.archive, context: context)

        let homes = try context.fetch(FetchDescriptor<Home>())
        let households = try context.fetch(FetchDescriptor<Household>())

        let household: Household
        if let existing = households.first(where: { $0.cloudIdentifier == row.id }) ?? households.first {
            household = existing
            household.cloudIdentifier = row.id
            household.name = row.household_name
            household.ownerUserIdentifier = profile.userIdentifier
            household.adoptedExistingHome = false
            household.syncReady = true
            household.home = homes.first
        } else {
            household = Household(
                cloudIdentifier: row.id,
                name: row.household_name,
                ownerUserIdentifier: profile.userIdentifier,
                adoptedExistingHome: false,
                syncReady: true,
                home: homes.first
            )
            context.insert(household)
        }

        if !household.members.contains(where: { $0.userIdentifier == profile.userIdentifier }) {
            let owner = HouseholdMember(
                userIdentifier: profile.userIdentifier,
                displayName: profile.displayName,
                email: profile.email ?? "",
                role: .owner,
                household: household
            )
            household.members.append(owner)
            context.insert(owner)
        }

        try context.save()

        return CloudSnapshotSummary(
            householdID: row.id,
            householdName: row.household_name,
            homeName: row.home_name ?? row.archive.home?.name ?? "Home",
            updatedAt: row.updated_at
        )
    }

    static func replaceLocalHomeWithLatestSnapshot(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudSnapshotSummary {
        guard let profile = accountSession.profile else { throw CloudSyncError.notSignedIn }
        let row = try await latestSnapshotRow(accountSession: accountSession)

        try deleteLocalHomeData(context: context)
        try HomeTransferService.importIntoEmptyStore(row.archive, context: context)

        let homes = try context.fetch(FetchDescriptor<Home>())
        let households = try context.fetch(FetchDescriptor<Household>())
        let household: Household

        if let existing = households.first(where: { $0.cloudIdentifier == row.id }) ?? households.first {
            household = existing
            household.cloudIdentifier = row.id
            household.name = row.household_name
            household.ownerUserIdentifier = profile.userIdentifier
            household.syncReady = true
            household.home = homes.first
        } else {
            household = Household(
                cloudIdentifier: row.id,
                name: row.household_name,
                ownerUserIdentifier: profile.userIdentifier,
                adoptedExistingHome: false,
                syncReady: true,
                home: homes.first
            )
            context.insert(household)
        }

        if !household.members.contains(where: { $0.userIdentifier == profile.userIdentifier }) {
            let owner = HouseholdMember(
                userIdentifier: profile.userIdentifier,
                displayName: profile.displayName,
                email: profile.email ?? "",
                role: .owner,
                household: household
            )
            household.members.append(owner)
            context.insert(owner)
        }

        try context.save()

        return CloudSnapshotSummary(
            householdID: row.id,
            householdName: row.household_name,
            homeName: row.home_name ?? row.archive.home?.name ?? "Home",
            updatedAt: row.updated_at
        )
    }

    private static func latestSnapshotRow(
        accountSession: AccountSessionStore
    ) async throws -> SnapshotRow {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard accountSession.isSignedIn,
              let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudSyncError.notSignedIn }

        let token = try await accountSession.validCloudAccessToken()
        let encodedUserID = cloudUserID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cloudUserID
        let path = "/rest/v1/household_snapshots?owner_user_id=eq.\(encodedUserID)&select=id,owner_user_id,household_name,home_name,archive,updated_at&order=updated_at.desc&limit=1"
        let request = try makeRequest(path: path, method: "GET", accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let row = try decoder.decode([SnapshotRow].self, from: data).first else {
            throw CloudSyncError.noCloudSnapshot
        }
        return row
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
        try context.save()
    }

    private static func cloudArchive(context: ModelContext) throws -> HomeTransferArchive {
        let fullData = try HomeTransferService.encodedArchive(context: context, packageType: "Cloud Sync")
        let fullArchive = try HomeTransferService.decode(fullData)

        // v0.43 intentionally syncs structured home data only. Photos/documents stay local
        // until the storage-backed attachment phase so large binary payloads do not live in JSONB.
        return HomeTransferArchive(
            formatVersion: fullArchive.formatVersion,
            appVersion: "0.43",
            packageType: "Cloud Sync",
            exportedAt: .now,
            home: fullArchive.home,
            rooms: fullArchive.rooms,
            vendors: fullArchive.vendors,
            systems: fullArchive.systems,
            appliances: fullArchive.appliances,
            fixtures: fullArchive.fixtures,
            furniture: fullArchive.furniture,
            paints: fullArchive.paints,
            projects: fullArchive.projects,
            projectItems: fullArchive.projectItems,
            measurements: fullArchive.measurements,
            tasks: fullArchive.tasks,
            history: fullArchive.history,
            detectors: fullArchive.detectors,
            consumables: fullArchive.consumables,
            attachments: []
        )
    }

    private static func encodeArchive(_ archive: HomeTransferArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    private static func makeRequest(path: String, method: String, accessToken: String) throws -> URLRequest {
        guard let baseURL = SupabaseConfiguration.projectURL,
              let key = SupabaseConfiguration.publishableKey,
              let url = URL(string: path, relativeTo: baseURL) else {
            throw CloudSyncError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw CloudSyncError.invalidServerResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Cloud request failed with status \(http.statusCode)."
            throw CloudSyncError.server(message)
        }
    }
}
