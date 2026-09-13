import SwiftData
import SwiftUI

struct HouseholdSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var homes: [Home]
    @Query private var households: [Household]

    @State private var householdName = ""
    @State private var showCreateSheet = false
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
                        Text("This creates the household structure on this device. Cloud synchronization will connect the same household across devices in the next phase.")
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
            Section("Create Your Household") {
                Label("Use your existing home as the household home", systemImage: "house.and.flag")
                    .font(.headline)

                Text("Your current rooms, systems, tasks, vendors, photos, and history stay exactly where they are. This step only creates a household record around the home already on this device so it can be synchronized later.")
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

            if !accountSession.isSignedIn {
                Section {
                    Label("Sign in with Apple first", systemImage: "person.crop.circle.badge.exclamationmark")
                    Text("A signed-in account is required to establish household ownership.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("What Happens Next") {
                Label("v0.42", systemImage: "person.2")
                Text("Creates household ownership, member roles, and invitation records locally.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("v0.43", systemImage: "icloud.and.arrow.up")
                Text("Adds the cloud synchronization layer so this household and its home data appear on your other devices and for invited family members.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
    @State private var showRename = false
    @State private var renamedHousehold = ""

    var body: some View {
        List {
            Section("Household") {
                LabeledContent("Name", value: household.name)
                if let home = household.home {
                    LabeledContent("Home", value: home.name)
                }
                LabeledContent("Created", value: household.createdAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Cloud Sync", value: household.syncReady ? "Connected" : "Coming in v0.43")

                if household.adoptedExistingHome {
                    Label("Existing home adopted safely", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("Members") {
                ForEach(household.members.sorted { $0.joinedAt < $1.joinedAt }) { member in
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
                        Text(member.role.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showInvite = true
                } label: {
                    Label("Prepare Family Invitation", systemImage: "person.badge.plus")
                }
                .disabled(!currentUserCanManage)
            }

            if !household.invitations.isEmpty {
                Section("Prepared Invitations") {
                    ForEach(household.invitations.sorted { $0.createdAt > $1.createdAt }) { invitation in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(invitation.email)
                                Spacer()
                                Text(invitation.role.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Code \(invitation.invitationCode)")
                                    .font(.caption.monospaced())
                                Spacer()
                                Text(invitation.status.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Sharing Status") {
                Label("Household structure is ready", systemImage: "checkmark.circle")
                Text("Invitations are being recorded now so roles and membership are ready for the cloud layer. They do not yet deliver shared home data to another device. v0.43 will activate cross-device synchronization and invitation acceptance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            if currentUserCanManage {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Rename Household") {
                            renamedHousehold = household.name
                            showRename = true
                        }
                        Button("Prepare Invitation") { showInvite = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            HouseholdInvitationFormView(household: household)
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
    }

    private var currentUserCanManage: Bool {
        guard let userIdentifier = accountSession.profile?.userIdentifier else { return false }
        return household.members.contains { $0.userIdentifier == userIdentifier && $0.role == .owner }
    }
}

struct HouseholdInvitationFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let household: Household

    @State private var email = ""
    @State private var role: HouseholdRole = .editor

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
                    Text("This version prepares the invitation and role locally. v0.43 will connect these invitations to the cloud and make them usable from another device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Prepare Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveInvitation() }
                        .disabled(!looksLikeEmail)
                }
            }
        }
    }

    @ViewBuilder
    private var roleDescription: some View {
        switch role {
        case .owner:
            Text("Owners can manage the household, members, and all home data.")
        case .editor:
            Text("Editors can add and update shared home records, tasks, projects, and history.")
        case .viewer:
            Text("Viewers can see shared household information but cannot change it.")
        }
    }

    private var looksLikeEmail: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private func saveInvitation() {
        let invitation = HouseholdInvitation(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            role: role,
            household: household
        )
        household.invitations.append(invitation)
        modelContext.insert(invitation)
        try? modelContext.save()
        dismiss()
    }
}
