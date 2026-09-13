import CloudKit
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
                        Text("This creates the household structure around the home already on this device. You can then upload the household to your private iCloud database from Settings → iCloud Sync.")
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

            Section("CloudKit Roadmap") {
                Label("v0.46", systemImage: "lock.icloud")
                Text("Stores the household backup in the owner’s private iCloud database and supports same-iCloud-account iPhone/iPad transfer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("v0.47", systemImage: "person.2.badge.gearshape")
                Text("Adds Apple CloudKit sharing so invited family members can use their own Apple IDs.")
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

    @State private var showRename = false
    @State private var renamedHousehold = ""
    @State private var isPreparingShare = false
    @State private var cloudShare: CKShare?
    @State private var sharingError: String?

    var body: some View {
        List {
            Section("Household") {
                LabeledContent("Name", value: household.name)
                if let home = household.home {
                    LabeledContent("Home", value: home.name)
                }
                LabeledContent(
                    "Created",
                    value: household.createdAt.formatted(date: .abbreviated, time: .omitted)
                )
                LabeledContent(
                    "iCloud Backup",
                    value: household.syncReady ? "Uploaded" : "Not uploaded yet"
                )

                if household.adoptedExistingHome {
                    Label(
                        "Existing home adopted safely",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)
                }
            }

            Section("Members") {
                ForEach(household.members.sorted { $0.joinedAt < $1.joinedAt }) { member in
                    HStack(spacing: 12) {
                        Image(
                            systemName: member.role == .owner
                                ? "crown.fill"
                                : "person.crop.circle"
                        )
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
                    prepareCloudShare()
                } label: {
                    if isPreparingShare {
                        HStack {
                            ProgressView()
                            Text("Preparing Sharing…")
                        }
                    } else {
                        Label(
                            "Share Household",
                            systemImage: "person.badge.plus"
                        )
                    }
                }
                .disabled(
                    !currentUserCanManage ||
                    isPreparingShare ||
                    !household.syncReady
                )
            }

            Section("Family Sharing") {
                if household.syncReady {
                    Label(
                        "Household is ready to share",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                    Text(
                        "Share this household with another Apple user. "
                        + "They will receive a native CloudKit invitation and "
                        + "can access the shared home using their own Apple ID."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Label(
                        "Upload to iCloud first",
                        systemImage: "icloud.and.arrow.up"
                    )

                    Text(
                        "Before inviting a family member, upload this household "
                        + "from Settings → iCloud Sync."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
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

                        Button("Share Household") {
                            prepareCloudShare()
                        }
                        .disabled(!household.syncReady || isPreparingShare)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { cloudShare != nil },
                set: { isPresented in
                    if !isPresented {
                        cloudShare = nil
                    }
                }
            )
        ) {
            if let cloudShare {
                CloudSharingView(
                    share: cloudShare,
                    container: CloudKitSyncService.cloudContainer
                )
            }
        }
        .alert("Rename Household", isPresented: $showRename) {
            TextField("Household name", text: $renamedHousehold)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let trimmed = renamedHousehold.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if !trimmed.isEmpty {
                    household.name = trimmed
                    try? modelContext.save()
                }
            }
        }
        .alert(
            "Family Sharing",
            isPresented: Binding(
                get: { sharingError != nil },
                set: { isPresented in
                    if !isPresented {
                        sharingError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                sharingError = nil
            }
        } message: {
            Text(sharingError ?? "")
        }
    }

    private func prepareCloudShare() {
        guard household.syncReady else {
            sharingError =
                "Upload this household to iCloud before preparing a family share."
            return
        }

        isPreparingShare = true

        Task {
            do {
                let share = try await CloudKitSyncService.prepareShare(
                    household: household
                )
                cloudShare = share
            } catch {
                sharingError =
                    "My Home Keeper could not prepare this household "
                    + "for family sharing. \(error.localizedDescription)"
            }

            isPreparingShare = false
        }
    }

    private var currentUserCanManage: Bool {
        guard let userIdentifier = accountSession.profile?.userIdentifier else {
            return false
        }

        return household.members.contains {
            $0.userIdentifier == userIdentifier && $0.role == .owner
        }
    }
}

