import Foundation

struct CloudHouseholdMembership: Codable, Equatable, Identifiable {
    let householdID: String
    let householdName: String
    let homeName: String?
    let role: HouseholdRole
    let displayName: String
    let email: String
    let joinedAt: Date

    var id: String { householdID }
}

struct CloudHouseholdInvitationSummary: Codable, Equatable, Identifiable {
    let id: String
    let householdID: String
    let householdName: String
    let email: String
    let role: HouseholdRole
    let invitationCode: String
    let createdAt: Date
    let status: HouseholdInvitationStatus
}

struct CloudHouseholdMemberSummary: Codable, Equatable, Identifiable {
    let id: String
    let userID: String
    let displayName: String
    let email: String
    let role: HouseholdRole
    let joinedAt: Date
}

enum CloudHouseholdError: LocalizedError {
    case notConfigured
    case notSignedIn
    case invalidResponse
    case invalidInvitationCode
    case invitationNotFound
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured for this build yet."
        case .notSignedIn:
            return "Sign in with Apple before managing a shared household."
        case .invalidResponse:
            return "Supabase returned an unexpected household response."
        case .invalidInvitationCode:
            return "Enter the 8-character invitation code."
        case .invitationNotFound:
            return "That invitation could not be found or is no longer available."
        case .server(let message):
            return message
        }
    }
}

@MainActor
enum CloudHouseholdService {
    private struct HouseholdRow: Decodable {
        let id: String
        let owner_user_id: String
        let name: String
        let home_name: String?
        let created_at: Date
        let updated_at: Date
    }

    private struct MemberRow: Decodable {
        let id: String
        let household_id: String
        let user_id: String
        let display_name: String?
        let email: String?
        let role: String
        let joined_at: Date
    }

    private struct InvitationRow: Decodable {
        let id: String
        let household_id: String
        let email: String
        let role: String
        let status: String
        let invitation_code: String
        let created_at: Date
    }

    private struct AcceptedInvitationRow: Decodable {
        let household_id: String
        let household_name: String
        let home_name: String?
        let role: String
    }

    static func ensureCloudHousehold(
        household: Household,
        accountSession: AccountSessionStore
    ) async throws {
        guard let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudHouseholdError.notSignedIn }
        let token = try await accountSession.validCloudAccessToken()

        let householdBody: [String: Any] = [
            "id": household.cloudIdentifier,
            "owner_user_id": cloudUserID,
            "name": household.name,
            "home_name": household.home?.name ?? "Home",
            "updated_at": isoString(.now)
        ]

        var request = try makeRequest(
            path: "/rest/v1/households?on_conflict=id",
            method: "POST",
            accessToken: token
        )
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: householdBody)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let profile = accountSession.profile
        let memberBody: [String: Any] = [
            "household_id": household.cloudIdentifier,
            "user_id": cloudUserID,
            "display_name": profile?.displayName ?? "Household Owner",
            "email": profile?.email ?? "",
            "role": HouseholdRole.owner.rawValue,
            "joined_at": isoString(.now)
        ]

        var memberRequest = try makeRequest(
            path: "/rest/v1/household_members?on_conflict=household_id,user_id",
            method: "POST",
            accessToken: token
        )
        memberRequest.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        memberRequest.httpBody = try JSONSerialization.data(withJSONObject: memberBody)
        let (memberData, memberResponse) = try await URLSession.shared.data(for: memberRequest)
        try validate(response: memberResponse, data: memberData)
    }

    static func createInvitation(
        household: Household,
        email: String,
        role: HouseholdRole,
        accountSession: AccountSessionStore
    ) async throws -> CloudHouseholdInvitationSummary {
        try await ensureCloudHousehold(household: household, accountSession: accountSession)
        guard let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudHouseholdError.notSignedIn }
        let token = try await accountSession.validCloudAccessToken()
        let code = HouseholdInvitation.makeCode()
        let invitationID = UUID().uuidString
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let createdAt = Date()

        let body: [String: Any] = [
            "id": invitationID,
            "household_id": household.cloudIdentifier,
            "email": normalizedEmail,
            "role": role.rawValue,
            "status": HouseholdInvitationStatus.pending.rawValue,
            "invitation_code": code,
            "invited_by": cloudUserID,
            "created_at": isoString(createdAt)
        ]

        var request = try makeRequest(path: "/rest/v1/household_invitations", method: "POST", accessToken: token)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        return CloudHouseholdInvitationSummary(
            id: invitationID,
            householdID: household.cloudIdentifier,
            householdName: household.name,
            email: normalizedEmail,
            role: role,
            invitationCode: code,
            createdAt: createdAt,
            status: .pending
        )
    }

    static func revokeInvitation(
        invitationCode: String,
        accountSession: AccountSessionStore
    ) async throws {
        let token = try await accountSession.validCloudAccessToken()
        let code = invitationCode.uppercased()
        var request = try makeRequest(
            path: "/rest/v1/household_invitations?invitation_code=eq.\(queryValue(code))",
            method: "PATCH",
            accessToken: token
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "status": HouseholdInvitationStatus.revoked.rawValue
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    static func pendingInvitations(
        accountSession: AccountSessionStore
    ) async throws -> [CloudHouseholdInvitationSummary] {
        let token = try await accountSession.validCloudAccessToken()
        let path = "/rest/v1/household_invitations?status=eq.Pending&select=id,household_id,email,role,status,invitation_code,created_at&order=created_at.desc"
        let request = try makeRequest(path: path, method: "GET", accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let rows = try decoder().decode([InvitationRow].self, from: data)

        var results: [CloudHouseholdInvitationSummary] = []
        for row in rows {
            let householdName = (try? await fetchHouseholdName(row.household_id, token: token)) ?? "Shared Household"
            results.append(CloudHouseholdInvitationSummary(
                id: row.id,
                householdID: row.household_id,
                householdName: householdName,
                email: row.email,
                role: HouseholdRole(rawValue: row.role) ?? .viewer,
                invitationCode: row.invitation_code,
                createdAt: row.created_at,
                status: HouseholdInvitationStatus(rawValue: row.status) ?? .pending
            ))
        }
        return results
    }

    static func acceptInvitation(
        code: String,
        accountSession: AccountSessionStore
    ) async throws -> CloudHouseholdMembership {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalizedCode.count == 8 else { throw CloudHouseholdError.invalidInvitationCode }
        guard let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudHouseholdError.notSignedIn }
        let token = try await accountSession.validCloudAccessToken()
        let profile = accountSession.profile

        let body: [String: Any] = [
            "p_code": normalizedCode,
            "p_display_name": profile?.displayName ?? "Family Member",
            "p_email": profile?.email ?? ""
        ]
        var request = try makeRequest(path: "/rest/v1/rpc/accept_household_invitation", method: "POST", accessToken: token)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        guard let row = try decoder().decode([AcceptedInvitationRow].self, from: data).first else {
            throw CloudHouseholdError.invitationNotFound
        }

        return CloudHouseholdMembership(
            householdID: row.household_id,
            householdName: row.household_name,
            homeName: row.home_name,
            role: HouseholdRole(rawValue: row.role) ?? .viewer,
            displayName: profile?.displayName ?? "Family Member",
            email: profile?.email ?? "",
            joinedAt: .now
        )
    }

    static func myMemberships(
        accountSession: AccountSessionStore
    ) async throws -> [CloudHouseholdMembership] {
        guard let cloudUserID = accountSession.cloudUserIdentifier else { throw CloudHouseholdError.notSignedIn }
        let token = try await accountSession.validCloudAccessToken()
        let path = "/rest/v1/household_members?user_id=eq.\(queryValue(cloudUserID))&select=id,household_id,user_id,display_name,email,role,joined_at&order=joined_at.asc"
        let request = try makeRequest(path: path, method: "GET", accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let rows = try decoder().decode([MemberRow].self, from: data)

        var memberships: [CloudHouseholdMembership] = []
        for row in rows {
            if let household = try? await fetchHousehold(row.household_id, token: token) {
                memberships.append(CloudHouseholdMembership(
                    householdID: row.household_id,
                    householdName: household.name,
                    homeName: household.home_name,
                    role: HouseholdRole(rawValue: row.role) ?? .viewer,
                    displayName: row.display_name ?? "Family Member",
                    email: row.email ?? "",
                    joinedAt: row.joined_at
                ))
            }
        }
        return memberships
    }

    static func members(
        householdID: String,
        accountSession: AccountSessionStore
    ) async throws -> [CloudHouseholdMemberSummary] {
        let token = try await accountSession.validCloudAccessToken()
        let path = "/rest/v1/household_members?household_id=eq.\(queryValue(householdID))&select=id,household_id,user_id,display_name,email,role,joined_at&order=joined_at.asc"
        let request = try makeRequest(path: path, method: "GET", accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder().decode([MemberRow].self, from: data).map {
            CloudHouseholdMemberSummary(
                id: $0.id,
                userID: $0.user_id,
                displayName: $0.display_name ?? "Family Member",
                email: $0.email ?? "",
                role: HouseholdRole(rawValue: $0.role) ?? .viewer,
                joinedAt: $0.joined_at
            )
        }
    }

    static func changeRole(
        memberID: String,
        role: HouseholdRole,
        accountSession: AccountSessionStore
    ) async throws {
        let token = try await accountSession.validCloudAccessToken()
        var request = try makeRequest(
            path: "/rest/v1/household_members?id=eq.\(queryValue(memberID))",
            method: "PATCH",
            accessToken: token
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: ["role": role.rawValue])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    static func removeMember(
        memberID: String,
        accountSession: AccountSessionStore
    ) async throws {
        let token = try await accountSession.validCloudAccessToken()
        let request = try makeRequest(
            path: "/rest/v1/household_members?id=eq.\(queryValue(memberID))",
            method: "DELETE",
            accessToken: token
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private static func fetchHouseholdName(_ householdID: String, token: String) async throws -> String {
        try await fetchHousehold(householdID, token: token).name
    }

    private static func fetchHousehold(_ householdID: String, token: String) async throws -> HouseholdRow {
        let path = "/rest/v1/households?id=eq.\(queryValue(householdID))&select=id,owner_user_id,name,home_name,created_at,updated_at&limit=1"
        let request = try makeRequest(path: path, method: "GET", accessToken: token)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        guard let row = try decoder().decode([HouseholdRow].self, from: data).first else {
            throw CloudHouseholdError.invalidResponse
        }
        return row
    }

    private static func decoder() -> JSONDecoder {
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
            throw CloudHouseholdError.notConfigured
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
        guard let http = response as? HTTPURLResponse else { throw CloudHouseholdError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Household cloud request failed with status \(http.statusCode)."
            throw CloudHouseholdError.server(message)
        }
    }
}
