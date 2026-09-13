import SwiftData
import SwiftUI

struct HouseholdSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var homes: [Home]
    @Query private var households: [Household]

    @State private var householdName = ""
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let household = households.first {
                HouseholdDetailView(household: household)
            } else {
                setupList
            }
        }
        .navigationTitle("Household")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                Form {
                    Section("Household") {
                        TextField("Household name", text: $householdName)
                    }
                    Section {
                        Text("This creates the household around the home already on this device. Afterward, upload the home from Cloud Sync so invited family members can download it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("Create Household")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") { createHousehold() }
                            .disabled(householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinHouseholdView()
        }
        .alert("Household", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var setupList: some View {
        List {
            if !homes.isEmpty {
                Section("Create Your Household") {
                    Label("Use your existing home as the household home", systemImage: "house.and.flag")
                        .font(.headline)

                    Text("Your current rooms, systems, tasks, vendors, photos, and history stay exactly where they are. This creates the household record around the home already on this device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let home = homes.first {
                        LabeledContent("Current home", value: home.name)
                    }

                    Button("Create Household from This Home") {
                        householdName = suggestedHouseholdName
                        showCreateSheet = true
                    }
                    .disabled(!accountSession.isSignedIn)
                }
            }

            Section("Join a Family Household") {
                Label("Use your own Apple account", systemImage: "person.2.badge.gearshape")
                    .font(.headline)
                Text("If a household owner has invited you, enter the 8-character invitation code. Your account will join the same cloud household without sharing anyone else's Apple ID.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    showJoinSheet = true
                } label: {
                    Label("Join Household", systemImage: "person.badge.plus")
                }
                .disabled(!accountSession.isCloudConnected)
            }

            if !accountSession.isSignedIn {
                Section {
                    Label("Sign in with Apple first", systemImage: "person.crop.circle.badge.exclamationmark")
                    Text("A signed-in account is required to create or join a household.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if !accountSession.isCloudConnected {
                Section {
                    Label("Cloud session required", systemImage: "icloud.slash")
                    Text("Connect the Supabase cloud session from Account before joining another household.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("v0.45 Family Sharing") {
                Label("Cloud invitations", systemImage: "envelope.badge")
                Label("Owner, Editor, and Viewer roles", systemImage: "person.3")
                Label("Family members use their own Apple IDs", systemImage: "apple.logo")
            }
        }
    }

    private var suggestedHouseholdName: String {
        guard let home = homes.first else { return "My Household" }
        let trimmed = home.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "My Household" : "\(trimmed) Household"
    }

    private func createHousehold() {
        guard let profile = accountSession.profile else {
            errorMessage = "Sign in with Apple before creating a household."
            return
        }

        let home = homes.first
        let household = Household(
            name: householdName.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerUserIdentifier: profile.userIdentifier,
            adoptedExistingHome: home != nil,
            home: home
        )
        let owner = HouseholdMember(
            userIdentifier: profile.userIdentifier,
            displayName: profile.displayName,
            email: profile.email ?? "",
            role: .owner,
            household: household
        )
        household.members.append(owner)
        modelContext.insert(household)
        modelContext.insert(owner)

        do {
            try modelContext.save()
            showCreateSheet = false
            if accountSession.isCloudConnected {
                Task {
                    do {
                        try await CloudHouseholdService.ensureCloudHousehold(household: household, accountSession: accountSession)
                    } catch {
                        errorMessage = "The household was created on this device, but the cloud household could not be prepared yet. \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            errorMessage = "My Home Keeper could not create the household. \(error.localizedDescription)"
        }
    }
}

struct HouseholdDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    let household: Household

    @State private var showInvite = false
    @State private var showJoin = false
    @State private var showRename = false
    @State private var renamedHousehold = ""
    @State private var cloudMembers: [CloudHouseholdMemberSummary] = []
    @State private var isRefreshingMembers = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section("Household") {
                LabeledContent("Name", value: household.name)
                if let home = household.home {
                    LabeledContent("Home", value: home.name)
                } else {
                    LabeledContent("Home", value: "Ready to download")
                }
                LabeledContent("Cloud", value: household.syncReady ? "Linked" : "Connected")
                if let role = currentLocalRole {
                    LabeledContent("Your Role", value: role.rawValue)
                }
            }

            Section("Members") {
                if !cloudMembers.isEmpty {
                    ForEach(cloudMembers) { member in
                        CloudMemberRow(member: member, canManage: currentUserCanManage, onRoleChange: { newRole in
                            changeRole(member, to: newRole)
                        }, onRemove: {
                            removeMember(member)
                        })
                    }
                } else {
                    ForEach(household.members.sorted { $0.joinedAt < $1.joinedAt }) { member in
                        memberRow(name: member.displayName, email: member.email, role: member.role)
                    }
                }

                if currentUserCanManage {
                    Button {
                        showInvite = true
                    } label: {
                        Label("Invite Family Member", systemImage: "person.badge.plus")
                    }
                }

                Button {
                    refreshMembers()
                } label: {
                    Label(isRefreshingMembers ? "Refreshing…" : "Refresh Members", systemImage: "arrow.clockwise")
                }
                .disabled(!accountSession.isCloudConnected || isRefreshingMembers)
            }

            if !household.invitations.isEmpty {
                Section("Invitations") {
                    ForEach(household.invitations.sorted { $0.createdAt > $1.createdAt }) { invitation in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(invitation.email)
                                Spacer()
                                Text(invitation.role.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Code \(invitation.invitationCode)")
                                    .font(.caption.monospaced().weight(.semibold))
                                Spacer()
                                Text(invitation.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if invitation.status == .pending {
                                ShareLink(item: invitationShareText(invitation)) {
                                    Label("Share Invitation", systemImage: "square.and.arrow.up")
                                        .font(.subheadline)
                                }
                                if currentUserCanManage {
                                    Button("Revoke Invitation", role: .destructive) {
                                        revokeInvitation(invitation)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if household.home == nil {
                Section("Next Step") {
                    Label("Household joined", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Open Cloud Sync, tap Check for My Cloud Household, then download the shared home to this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Sharing Status") {
                    Label("Family sharing is active", systemImage: "person.2.circle.fill")
                        .foregroundStyle(.green)
                    Text("Owners can invite and manage family members. Joined members can discover and download the shared household from Cloud Sync. Manual structured sync remains the data-sync method in this release.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if currentUserCanManage {
                        Button("Rename Household") {
                            renamedHousehold = household.name
                            showRename = true
                        }
                        Button("Invite Family Member") { showInvite = true }
                    }
                    Button("Join with Invitation Code") { showJoin = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            HouseholdInvitationFormView(household: household)
        }
        .sheet(isPresented: $showJoin) {
            JoinHouseholdView()
        }
        .alert("Rename Household", isPresented: $showRename) {
            TextField("Household name", text: $renamedHousehold)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renamedHousehold.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    household.name = trimmed
                    try? modelContext.save()
                }
            }
        }
        .alert("Household", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .task {
            if accountSession.isCloudConnected {
                refreshMembers()
            }
        }
    }

    @ViewBuilder
    private func memberRow(name: String, email: String, role: HouseholdRole) -> some View {
        HStack(spacing: 12) {
            Image(systemName: role == .owner ? "crown.fill" : "person.crop.circle")
                .foregroundStyle(role == .owner ? .orange : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                if !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(role.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var currentLocalRole: HouseholdRole? {
        guard let userIdentifier = accountSession.profile?.userIdentifier else { return nil }
        return household.members.first { $0.userIdentifier == userIdentifier }?.role
    }

    private var currentUserCanManage: Bool {
        currentLocalRole == .owner
    }

    private func invitationShareText(_ invitation: HouseholdInvitation) -> String {
        "You've been invited to join \(household.name) in My Home Keeper as \(invitation.role.rawValue). Install/open My Home Keeper, sign in with your own Apple ID, choose Join Household, and enter code \(invitation.invitationCode)."
    }

    private func refreshMembers() {
        guard accountSession.isCloudConnected else { return }
        isRefreshingMembers = true
        Task {
            do {
                cloudMembers = try await CloudHouseholdService.members(householdID: household.cloudIdentifier, accountSession: accountSession)
            } catch {
                statusMessage = error.localizedDescription
            }
            isRefreshingMembers = false
        }
    }

    private func changeRole(_ member: CloudHouseholdMemberSummary, to role: HouseholdRole) {
        Task {
            do {
                try await CloudHouseholdService.changeRole(memberID: member.id, role: role, accountSession: accountSession)
                refreshMembers()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func removeMember(_ member: CloudHouseholdMemberSummary) {
        Task {
            do {
                try await CloudHouseholdService.removeMember(memberID: member.id, accountSession: accountSession)
                refreshMembers()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func revokeInvitation(_ invitation: HouseholdInvitation) {
        Task {
            do {
                try await CloudHouseholdService.revokeInvitation(invitationCode: invitation.invitationCode, accountSession: accountSession)
                invitation.status = .revoked
                try? modelContext.save()
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }
}

private struct CloudMemberRow: View {
    let member: CloudHouseholdMemberSummary
    let canManage: Bool
    let onRoleChange: (HouseholdRole) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: member.role == .owner ? "crown.fill" : "person.crop.circle")
                .foregroundStyle(member.role == .owner ? .orange : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                if !member.email.isEmpty {
                    Text(member.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canManage && member.role != .owner {
                Menu(member.role.rawValue) {
                    Button("Editor") { onRoleChange(.editor) }
                    Button("Viewer") { onRoleChange(.viewer) }
                    Divider()
                    Button("Remove Member", role: .destructive) { onRemove() }
                }
                .font(.caption.weight(.semibold))
            } else {
                Text(member.role.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HouseholdInvitationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    let household: Household

    @State private var email = ""
    @State private var role: HouseholdRole = .editor
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Family Member") {
                    TextField("Email address", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    Picker("Role", selection: $role) {
                        ForEach([HouseholdRole.editor, .viewer]) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                }

                Section("Role Access") {
                    roleDescription
                }

                Section {
                    Text("The invitation is stored in the cloud and generates an 8-character code. Share that code with the family member. They sign in with their own Apple ID and enter the code to join.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isSaving {
                    HStack {
                        ProgressView()
                        Text("Creating cloud invitation…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Invite Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") { saveInvitation() }
                        .disabled(!looksLikeEmail || isSaving || !accountSession.isCloudConnected)
                }
            }
            .alert("Invitation", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var roleDescription: some View {
        switch role {
        case .owner:
            Text("Owners can manage the household, members, and all home data.")
        case .editor:
            Text("Editors can work with shared home records. Owner-controlled cloud publishing remains manual in this release.")
        case .viewer:
            Text("Viewers can download and view shared household information without managing membership.")
        }
    }

    private var looksLikeEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func saveInvitation() {
        isSaving = true
        Task {
            do {
                let cloudInvitation = try await CloudHouseholdService.createInvitation(
                    household: household,
                    email: email,
                    role: role,
                    accountSession: accountSession
                )
                let invitation = HouseholdInvitation(
                    id: UUID(uuidString: cloudInvitation.id) ?? UUID(),
                    email: cloudInvitation.email,
                    role: cloudInvitation.role,
                    status: cloudInvitation.status,
                    createdAt: cloudInvitation.createdAt,
                    invitationCode: cloudInvitation.invitationCode,
                    household: household
                )
                household.invitations.append(invitation)
                modelContext.insert(invitation)
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct JoinHouseholdView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var households: [Household]

    @State private var invitationCode = ""
    @State private var pendingInvitations: [CloudHouseholdInvitationSummary] = []
    @State private var isWorking = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Invitation Code") {
                    TextField("8-character code", text: $invitationCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Join Household") {
                        accept(code: invitationCode)
                    }
                    .disabled(invitationCode.trimmingCharacters(in: .whitespacesAndNewlines).count != 8 || isWorking || !accountSession.isCloudConnected)
                }

                Section("Invitations for Your Account") {
                    Button {
                        checkInvitations()
                    } label: {
                        Label("Check for Invitations", systemImage: "envelope.open")
                    }
                    .disabled(isWorking || !accountSession.isCloudConnected)

                    ForEach(pendingInvitations) { invitation in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(invitation.householdName)
                                .font(.headline)
                            LabeledContent("Role", value: invitation.role.rawValue)
                            Text("Code \(invitation.invitationCode)")
                                .font(.caption.monospaced())
                            Button("Accept Invitation") {
                                accept(code: invitation.invitationCode)
                            }
                            .disabled(isWorking)
                        }
                        .padding(.vertical, 3)
                    }
                }

                Section {
                    Text("Invitation-code acceptance works even if Sign in with Apple uses a private relay email. After joining, go to Cloud Sync to download the shared home.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isWorking {
                    HStack {
                        ProgressView()
                        Text("Working…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Join Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Household", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    if households.first != nil { dismiss() }
                    statusMessage = nil
                }
            } message: {
                Text(statusMessage ?? "")
            }
        }
    }

    private func checkInvitations() {
        isWorking = true
        Task {
            do {
                pendingInvitations = try await CloudHouseholdService.pendingInvitations(accountSession: accountSession)
                if pendingInvitations.isEmpty {
                    statusMessage = "No pending invitations matched this Apple account. If you were given a code, enter it above."
                }
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func accept(code: String) {
        isWorking = true
        Task {
            do {
                let membership = try await CloudHouseholdService.acceptInvitation(code: code, accountSession: accountSession)
                try saveLocalMembership(membership)
                statusMessage = "Joined \(membership.householdName) as \(membership.role.rawValue). Next, open Cloud Sync and download the shared home."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func saveLocalMembership(_ membership: CloudHouseholdMembership) throws {
        guard let profile = accountSession.profile else { throw CloudHouseholdError.notSignedIn }
        let household: Household
        if let existing = households.first(where: { $0.cloudIdentifier == membership.householdID }) {
            household = existing
            household.name = membership.householdName
        } else {
            household = Household(
                cloudIdentifier: membership.householdID,
                name: membership.householdName,
                ownerUserIdentifier: "cloud-owner",
                adoptedExistingHome: false,
                syncReady: true,
                home: nil
            )
            modelContext.insert(household)
        }

        if !household.members.contains(where: { $0.userIdentifier == profile.userIdentifier }) {
            let member = HouseholdMember(
                userIdentifier: profile.userIdentifier,
                displayName: membership.displayName,
                email: membership.email,
                role: membership.role,
                household: household
            )
            household.members.append(member)
            modelContext.insert(member)
        }
        try modelContext.save()
    }
}
