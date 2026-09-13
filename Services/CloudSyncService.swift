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
    private struct ManifestRow: Decodable {
        let household_id: String
        let owner_user_id: String
        let household_name: String
        let home_name: String?
        let revision: String
        let format_version: Int
        let app_version: String
        let package_type: String
        let exported_at: Date
        let updated_at: Date
    }

    private struct PayloadRow<T: Decodable>: Decodable {
        let payload: T
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
        let revision = UUID().uuidString
        let updatedAt = Date()
        let householdID = household.cloudIdentifier

        // Upload small structured chunks instead of one large JSONB document. The
        // manifest is written last, so other devices only discover a revision after
        // every required chunk has finished uploading successfully.
        try await uploadChunk("home", payload: archive.home.map { [$0] } ?? [], householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("rooms", payload: archive.rooms, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("vendors", payload: archive.vendors, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("systems", payload: archive.systems, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("appliances", payload: archive.appliances, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("fixtures", payload: archive.fixtures, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("furniture", payload: archive.furniture ?? [], householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("paints", payload: archive.paints, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("projects", payload: archive.projects, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("project_items", payload: archive.projectItems, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("measurements", payload: archive.measurements, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("tasks", payload: archive.tasks, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("history", payload: archive.history, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("detectors", payload: archive.detectors, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)
        try await uploadChunk("consumables", payload: archive.consumables, householdID: householdID, revision: revision, ownerUserID: cloudUserID, accessToken: token)

        let manifestBody: [String: Any] = [
            "household_id": householdID,
            "owner_user_id": cloudUserID,
            "household_name": household.name,
            "home_name": household.home?.name ?? archive.home?.name ?? "Home",
            "revision": revision,
            "format_version": archive.formatVersion,
            "app_version": archive.appVersion,
            "package_type": archive.packageType,
            "exported_at": isoString(archive.exportedAt),
            "updated_at": isoString(updatedAt)
        ]

        var manifestRequest = try makeRequest(
            path: "/rest/v1/household_sync_manifests?on_conflict=household_id",
            method: "POST",
            accessToken: token
        )
        manifestRequest.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        manifestRequest.httpBody = try JSONSerialization.data(withJSONObject: manifestBody)

        let (manifestData, manifestResponse) = try await URLSession.shared.data(for: manifestRequest)
        try validate(response: manifestResponse, data: manifestData)

        household.syncReady = true
        try context.save()

        return CloudSnapshotSummary(
            householdID: householdID,
            householdName: household.name,
            homeName: household.home?.name ?? archive.home?.name ?? "Home",
            updatedAt: updatedAt
        )
    }

    static func latestSnapshot(
        accountSession: AccountSessionStore
    ) async throws -> CloudSnapshotSummary {
        let manifest = try await latestManifest(accountSession: accountSession)
        return CloudSnapshotSummary(
            householdID: manifest.household_id,
            householdName: manifest.household_name,
            homeName: manifest.home_name ?? "Home",
            updatedAt: manifest.updated_at
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

        let manifest = try await latestManifest(accountSession: accountSession)
        let archive = try await archiveForManifest(manifest, accountSession: accountSession)
        try HomeTransferService.importIntoEmptyStore(archive, context: context)

        try attachHouseholdAfterImport(
            manifest: manifest,
            profile: profile,
            context: context,
            adoptedExistingHome: false
        )

        return CloudSnapshotSummary(
            householdID: manifest.household_id,
            householdName: manifest.household_name,
            homeName: manifest.home_name ?? archive.home?.name ?? "Home",
            updatedAt: manifest.updated_at
        )
    }

    static func replaceLocalHomeWithLatestSnapshot(
        context: ModelContext,
        accountSession: AccountSessionStore
    ) async throws -> CloudSnapshotSummary {
        guard let profile = accountSession.profile else { throw CloudSyncError.notSignedIn }
        let manifest = try await latestManifest(accountSession: accountSession)
        let archive = try await archiveForManifest(manifest, accountSession: accountSession)

        try deleteLocalHomeData(context: context)
        try HomeTransferService.importIntoEmptyStore(archive, context: context)

        try attachHouseholdAfterImport(
            manifest: manifest,
            profile: profile,
            context: context,
            adoptedExistingHome: false
        )

        return CloudSnapshotSummary(
            householdID: manifest.household_id,
            householdName: manifest.household_name,
            homeName: manifest.home_name ?? archive.home?.name ?? "Home",
            updatedAt: manifest.updated_at
        )
    }

    private static func latestManifest(
        accountSession: AccountSessionStore
    ) async throws -> ManifestRow {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard accountSession.isSignedIn,
              let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudSyncError.notSignedIn }

        let token = try await accountSession.validCloudAccessToken()
        let encodedUserID = queryValue(cloudUserID)
        let path = "/rest/v1/household_sync_manifests?owner_user_id=eq.\(encodedUserID)&select=household_id,owner_user_id,household_name,home_name,revision,format_version,app_version,package_type,exported_at,updated_at&order=updated_at.desc&limit=1"
        let request = try makeRequest(path: path, method: "GET", accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = cloudDecoder()
        guard let row = try decoder.decode([ManifestRow].self, from: data).first else {
            throw CloudSyncError.noCloudSnapshot
        }
        return row
    }

    private static func archiveForManifest(
        _ manifest: ManifestRow,
        accountSession: AccountSessionStore
    ) async throws -> HomeTransferArchive {
        let token = try await accountSession.validCloudAccessToken()
        let householdID = manifest.household_id
        let revision = manifest.revision

        let homeRows: [TransferHome] = try await fetchChunk("home", householdID: householdID, revision: revision, accessToken: token)
        let rooms: [TransferRoom] = try await fetchChunk("rooms", householdID: householdID, revision: revision, accessToken: token)
        let vendors: [TransferVendor] = try await fetchChunk("vendors", householdID: householdID, revision: revision, accessToken: token)
        let systems: [TransferSystem] = try await fetchChunk("systems", householdID: householdID, revision: revision, accessToken: token)
        let appliances: [TransferAppliance] = try await fetchChunk("appliances", householdID: householdID, revision: revision, accessToken: token)
        let fixtures: [TransferFixture] = try await fetchChunk("fixtures", householdID: householdID, revision: revision, accessToken: token)
        let furniture: [TransferFurniture] = try await fetchChunk("furniture", householdID: householdID, revision: revision, accessToken: token)
        let paints: [TransferPaint] = try await fetchChunk("paints", householdID: householdID, revision: revision, accessToken: token)
        let projects: [TransferProject] = try await fetchChunk("projects", householdID: householdID, revision: revision, accessToken: token)
        let projectItems: [TransferProjectItem] = try await fetchChunk("project_items", householdID: householdID, revision: revision, accessToken: token)
        let measurements: [TransferMeasurement] = try await fetchChunk("measurements", householdID: householdID, revision: revision, accessToken: token)
        let tasks: [TransferTask] = try await fetchChunk("tasks", householdID: householdID, revision: revision, accessToken: token)
        let history: [TransferHistory] = try await fetchChunk("history", householdID: householdID, revision: revision, accessToken: token)
        let detectors: [TransferDetector] = try await fetchChunk("detectors", householdID: householdID, revision: revision, accessToken: token)
        let consumables: [TransferConsumable] = try await fetchChunk("consumables", householdID: householdID, revision: revision, accessToken: token)

        return HomeTransferArchive(
            formatVersion: manifest.format_version,
            appVersion: manifest.app_version,
            packageType: manifest.package_type,
            exportedAt: manifest.exported_at,
            home: homeRows.first,
            rooms: rooms,
            vendors: vendors,
            systems: systems,
            appliances: appliances,
            fixtures: fixtures,
            furniture: furniture,
            paints: paints,
            projects: projects,
            projectItems: projectItems,
            measurements: measurements,
            tasks: tasks,
            history: history,
            detectors: detectors,
            consumables: consumables,
            attachments: []
        )
    }

    private static func uploadChunk<T: Encodable>(
        _ type: String,
        payload: T,
        householdID: String,
        revision: String,
        ownerUserID: String,
        accessToken: String
    ) async throws {
        let payloadData = try cloudEncoder().encode(payload)
        let payloadObject = try JSONSerialization.jsonObject(with: payloadData)
        let body: [String: Any] = [
            "household_id": householdID,
            "revision": revision,
            "owner_user_id": ownerUserID,
            "chunk_type": type,
            "payload": payloadObject,
            "updated_at": isoString(.now)
        ]

        var request = try makeRequest(
            path: "/rest/v1/household_sync_chunks?on_conflict=household_id,revision,chunk_type",
            method: "POST",
            accessToken: accessToken
        )
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private static func fetchChunk<T: Decodable>(
        _ type: String,
        householdID: String,
        revision: String,
        accessToken: String
    ) async throws -> T {
        let path = "/rest/v1/household_sync_chunks?household_id=eq.\(queryValue(householdID))&revision=eq.\(queryValue(revision))&chunk_type=eq.\(queryValue(type))&select=payload&limit=1"
        let request = try makeRequest(path: path, method: "GET", accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        guard let row = try cloudDecoder().decode([PayloadRow<T>].self, from: data).first else {
            throw CloudSyncError.server("The cloud household is incomplete. Missing \(type.replacingOccurrences(of: "_", with: " ")) data for this revision.")
        }
        return row.payload
    }

    private static func attachHouseholdAfterImport(
        manifest: ManifestRow,
        profile: AccountSessionStore.Profile,
        context: ModelContext,
        adoptedExistingHome: Bool
    ) throws {
        let homes = try context.fetch(FetchDescriptor<Home>())
        let households = try context.fetch(FetchDescriptor<Household>())

        let household: Household
        if let existing = households.first(where: { $0.cloudIdentifier == manifest.household_id }) ?? households.first {
            household = existing
            household.cloudIdentifier = manifest.household_id
            household.name = manifest.household_name
            household.ownerUserIdentifier = profile.userIdentifier
            household.adoptedExistingHome = adoptedExistingHome
            household.syncReady = true
            household.home = homes.first
        } else {
            household = Household(
                cloudIdentifier: manifest.household_id,
                name: manifest.household_name,
                ownerUserIdentifier: profile.userIdentifier,
                adoptedExistingHome: adoptedExistingHome,
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

        // Strip every binary/photo field from the structured sync payload. Photos and
        // documents will move to Supabase Storage in a later release rather than JSONB.
        let projects = fullArchive.projects.map {
            TransferProject(
                id: $0.id,
                title: $0.title,
                projectDescription: $0.projectDescription,
                stage: $0.stage,
                notes: $0.notes,
                roomName: $0.roomName,
                targetDate: $0.targetDate,
                budget: $0.budget,
                roomID: $0.roomID,
                coverPhotoData: nil,
                additionalRoomIDs: $0.additionalRoomIDs
            )
        }

        let projectItems = fullArchive.projectItems.map {
            TransferProjectItem(
                id: $0.id,
                projectID: $0.projectID,
                title: $0.title,
                category: $0.category,
                comparisonGroup: $0.comparisonGroup,
                manufacturer: $0.manufacturer,
                model: $0.model,
                sku: $0.sku,
                finishColor: $0.finishColor,
                dimensions: $0.dimensions,
                store: $0.store,
                website: $0.website,
                notes: $0.notes,
                status: $0.status,
                unitCost: $0.unitCost,
                quantity: $0.quantity,
                actualPurchaseCost: $0.actualPurchaseCost,
                purchaseDate: $0.purchaseDate,
                installedDate: $0.installedDate,
                photoData: nil,
                isIdeaOnly: $0.isIdeaOnly
            )
        }

        return HomeTransferArchive(
            formatVersion: fullArchive.formatVersion,
            appVersion: "0.44",
            packageType: "Structured Cloud Sync",
            exportedAt: .now,
            home: fullArchive.home,
            rooms: fullArchive.rooms,
            vendors: fullArchive.vendors,
            systems: fullArchive.systems,
            appliances: fullArchive.appliances,
            fixtures: fullArchive.fixtures,
            furniture: fullArchive.furniture,
            paints: fullArchive.paints,
            projects: projects,
            projectItems: projectItems,
            measurements: fullArchive.measurements,
            tasks: fullArchive.tasks,
            history: fullArchive.history,
            detectors: fullArchive.detectors,
            consumables: fullArchive.consumables,
            attachments: []
        )
    }

    private static func cloudEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func cloudDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func queryValue(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
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
