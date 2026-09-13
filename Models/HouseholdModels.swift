import Foundation
import SwiftData

enum HouseholdRole: String, CaseIterable, Codable, Identifiable {
    case owner = "Owner"
    case editor = "Editor"
    case viewer = "Viewer"

    var id: String { rawValue }
}

enum HouseholdInvitationStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case revoked = "Revoked"
}

@Model
final class Household {
    var id: UUID
    var cloudIdentifier: String
    var name: String
    var createdAt: Date
    var ownerUserIdentifier: String
    var adoptedExistingHome: Bool
    var syncReady: Bool
    var home: Home?
    var members: [HouseholdMember] = []
    var invitations: [HouseholdInvitation] = []

    init(
        id: UUID = UUID(),
        cloudIdentifier: String = UUID().uuidString,
        name: String,
        createdAt: Date = .now,
        ownerUserIdentifier: String,
        adoptedExistingHome: Bool = false,
        syncReady: Bool = false,
        home: Home? = nil
    ) {
        self.id = id
        self.cloudIdentifier = cloudIdentifier
        self.name = name
        self.createdAt = createdAt
        self.ownerUserIdentifier = ownerUserIdentifier
        self.adoptedExistingHome = adoptedExistingHome
        self.syncReady = syncReady
        self.home = home
    }
}

@Model
final class HouseholdMember {
    var id: UUID
    var userIdentifier: String
    var displayName: String
    var email: String
    var roleRaw: String
    var joinedAt: Date
    var household: Household?

    init(
        id: UUID = UUID(),
        userIdentifier: String,
        displayName: String,
        email: String = "",
        role: HouseholdRole,
        joinedAt: Date = .now,
        household: Household? = nil
    ) {
        self.id = id
        self.userIdentifier = userIdentifier
        self.displayName = displayName
        self.email = email
        self.roleRaw = role.rawValue
        self.joinedAt = joinedAt
        self.household = household
    }

    var role: HouseholdRole {
        get { HouseholdRole(rawValue: roleRaw) ?? .viewer }
        set { roleRaw = newValue.rawValue }
    }
}

@Model
final class HouseholdInvitation {
    var id: UUID
    var email: String
    var roleRaw: String
    var statusRaw: String
    var createdAt: Date
    var invitationCode: String
    var household: Household?

    init(
        id: UUID = UUID(),
        email: String,
        role: HouseholdRole,
        status: HouseholdInvitationStatus = .pending,
        createdAt: Date = .now,
        invitationCode: String = HouseholdInvitation.makeCode(),
        household: Household? = nil
    ) {
        self.id = id
        self.email = email
        self.roleRaw = role.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.invitationCode = invitationCode
        self.household = household
    }

    var role: HouseholdRole {
        get { HouseholdRole(rawValue: roleRaw) ?? .viewer }
        set { roleRaw = newValue.rawValue }
    }

    var status: HouseholdInvitationStatus {
        get { HouseholdInvitationStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    static func makeCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }
}
