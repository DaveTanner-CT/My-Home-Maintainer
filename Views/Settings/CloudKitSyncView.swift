import SwiftData
import SwiftUI

struct CloudKitSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var households: [Household]

    @State private var iCloudStatus = "Checking…"
    @State private var isWorking = false
    @State private var privateSnapshot: CloudKitSnapshotSummary?
    @State private var sharedSnapshot: CloudKitSnapshotSummary?
    @State private var statusMessage: String?
    @State private var showPrivateDownloadConfirmation = false
    @State private var showPrivateReplaceConfirmation = false
    @State private var showSharedDownloadConfirmation = false
    @State private var showSharedReplaceConfirmation = false
    @State private var lastAcceptedShareDate: Date? = UserDefaults.standard.object(forKey: "HomeKeeperLastAcceptedCloudShareDate") as? Date
    @State private var lastShareError: String? = UserDefaults.standard.string(forKey: "HomeKeeperLastCloudShareError")

    private var localHousehold: Household? { households.first }

    private var currentUserIsOwner: Bool {
        guard let household = localHousehold,
              let userID = accountSession.profile?.userIdentifier else {
            return false
        }

        return household.ownerUserIdentifier == userID || household.members.contains {
            $0.userIdentifier == userID && $0.role == .owner
        }
    }

    private var privateCloudHasNewerChanges: Bool {
        guard let snapshot = privateSnapshot else { return false }
        return CloudKitSyncCheckpointStore.isRemoteNewer(
            remoteDate: snapshot.updatedAt,
            householdID: snapshot.householdID,
            scope: .privateHousehold
        )
    }

    private var sharedCloudHasNewerChanges: Bool {
        guard let snapshot = sharedSnapshot else { return false }
        return CloudKitSyncCheckpointStore.isRemoteNewer(
            remoteDate: snapshot.updatedAt,
            householdID: snapshot.householdID,
            scope: .sharedHousehold
        )
    }

    var body: some View {
        List {
            Section("iCloud") {
                LabeledContent("iCloud Account", value: iCloudStatus)
                LabeledContent("Storage", value: "Private + Shared CloudKit")

                Button {
                    refreshCloudOverview(showErrors: true)
                } label: {
                    Label("Refresh Cloud Status", systemImage: "arrow.clockwise.icloud")
                }
                .disabled(iCloudStatus != "Available" || isWorking)

                Text("My Home Keeper checks iCloud when this screen opens. Cloud copies are never applied automatically, so a newer family change cannot silently overwrite edits on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            syncAttentionSection

            if let accepted = lastAcceptedShareDate {
                Section("Family Invitation") {
                    Label("CloudKit invitation accepted", systemImage: "person.2.circle.fill")
                        .foregroundStyle(.green)
                    LabeledContent("Accepted", value: accepted.formatted(date: .abbreviated, time: .shortened))
                    Text("Shared household updates can now be checked and applied from this screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let lastShareError {
                Section("Family Invitation") {
                    Label("Invitation could not be accepted", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(lastShareError)
                        .font(.footnote)
                    Text("Open the Apple sharing invitation again after confirming this device is signed into iCloud.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("My Private Household") {
                if let household = localHousehold {
                    LabeledContent("Household", value: household.name)
                    if let home = household.home {
                        LabeledContent("Home", value: home.name)
                    }
                    LabeledContent("iCloud Backup", value: household.syncReady ? "Uploaded" : "Not Uploaded Yet")

                    if currentUserIsOwner {
                        Button {
                            uploadPrivate(household)
                        } label: {
                            Label("Upload This Home to iCloud", systemImage: "icloud.and.arrow.up")
                        }
                        .disabled(iCloudStatus != "Available" || isWorking)
                    }
                } else {
                    Text("If this device owns a household, create it locally first and upload it here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    checkPrivateCloud(showErrors: true)
                } label: {
                    Label("Check My Private iCloud Household", systemImage: "icloud")
                }
                .disabled(iCloudStatus != "Available" || isWorking)

                if let privateSnapshot {
                    LabeledContent("iCloud Household", value: privateSnapshot.householdName)
                    LabeledContent("iCloud Home", value: privateSnapshot.homeName)
                    LabeledContent("Cloud Updated", value: privateSnapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    if let applied = CloudKitSyncCheckpointStore.lastAppliedDate(
                        householdID: privateSnapshot.householdID,
                        scope: .privateHousehold
                    ) {
                        LabeledContent("This Device Synced", value: applied.formatted(date: .abbreviated, time: .shortened))
                    }

                    if privateCloudHasNewerChanges {
                        Label("A newer iCloud copy is available", systemImage: "icloud.and.arrow.down.fill")
                            .foregroundStyle(.orange)
                    }

                    Button {
                        showPrivateDownloadConfirmation = true
                    } label: {
                        Label("Download to This Empty Device", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(isWorking)

                    Button {
                        showPrivateReplaceConfirmation = true
                    } label: {
                        Label(
                            privateCloudHasNewerChanges ? "Update This Device from iCloud" : "Reload Local Home from iCloud",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(isWorking)
                }
            }

            Section("Shared With Me") {
                Button {
                    checkSharedCloud(showErrors: true)
                } label: {
                    Label("Check for Shared Household", systemImage: "person.2.badge.gearshape")
                }
                .disabled(iCloudStatus != "Available" || isWorking)

                if let sharedSnapshot {
                    LabeledContent("Shared Household", value: sharedSnapshot.householdName)
                    LabeledContent("Shared Home", value: sharedSnapshot.homeName)
                    LabeledContent("Cloud Updated", value: sharedSnapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    if let applied = CloudKitSyncCheckpointStore.lastAppliedDate(
                        householdID: sharedSnapshot.householdID,
                        scope: .sharedHousehold
                    ) {
                        LabeledContent("This Device Synced", value: applied.formatted(date: .abbreviated, time: .shortened))
                    }

                    if sharedCloudHasNewerChanges {
                        Label("New family changes are available", systemImage: "person.2.wave.2.fill")
                            .foregroundStyle(.orange)
                    }

                    Button {
                        showSharedDownloadConfirmation = true
                    } label: {
                        Label("Download Shared Household", systemImage: "person.2.and.arrow.down")
                    }
                    .disabled(isWorking)

                    Button {
                        showSharedReplaceConfirmation = true
                    } label: {
                        Label(
                            sharedCloudHasNewerChanges ? "Update This Device from Shared Household" : "Reload Shared Household",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(isWorking)

                    if let household = localHousehold,
                       household.cloudIdentifier == sharedSnapshot.householdID,
                       !currentUserIsOwner {
                        Button {
                            uploadShared(household)
                        } label: {
                            Label("Upload My Changes to Shared Household", systemImage: "person.2.badge.plus")
                        }
                        .disabled(isWorking)
                    }
                } else {
                    Text("After accepting a My Home Keeper invitation from another Apple user, tap Check for Shared Household.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Safe Family Sync") {
                Label("Checks cloud status automatically when this screen opens", systemImage: "arrow.clockwise.icloud")
                Label("Highlights when a newer cloud copy exists", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                Label("Never overwrites local records without confirmation", systemImage: "checkmark.shield")
                Text("This release deliberately avoids automatic conflict resolution. Until record-by-record sync is added, whole-home replacements always require your confirmation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("Working with iCloud…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshStatus()
            refreshShareAcceptanceState()
            if iCloudStatus == "Available" {
                refreshCloudOverview(showErrors: false)
            }
        }
        .refreshable {
            await refreshStatus()
            await refreshCloudOverviewAsync(showErrors: false)
        }
        .alert("iCloud Sync", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .confirmationDialog("Download Private iCloud Household?", isPresented: $showPrivateDownloadConfirmation, titleVisibility: .visible) {
            Button("Download to This Device") { downloadPrivate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only works when the device has no existing home data.")
        }
        .confirmationDialog("Update Local Home from Private iCloud?", isPresented: $showPrivateReplaceConfirmation, titleVisibility: .visible) {
            Button("Update Local Home", role: .destructive) { replaceFromPrivateCloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the local home records on this device with the selected iCloud copy. Use this after confirming iCloud contains the version you want.")
        }
        .confirmationDialog("Download Shared Household?", isPresented: $showSharedDownloadConfirmation, titleVisibility: .visible) {
            Button("Download Shared Household") { downloadShared() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only works when the device has no existing home data.")
        }
        .confirmationDialog("Update Local Home from Shared Household?", isPresented: $showSharedReplaceConfirmation, titleVisibility: .visible) {
            Button("Update Local Home", role: .destructive) { replaceFromSharedCloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the local home records on this device with the latest family-shared iCloud copy. Any local edits not uploaded first will be lost.")
        }
    }

    @ViewBuilder
    private var syncAttentionSection: some View {
        if privateCloudHasNewerChanges || sharedCloudHasNewerChanges {
            Section("Sync Attention") {
                if privateCloudHasNewerChanges {
                    Label("A newer private iCloud version is available", systemImage: "icloud.and.arrow.down.fill")
                        .foregroundStyle(.orange)
                }
                if sharedCloudHasNewerChanges {
                    Label("A family member has a newer shared version", systemImage: "person.2.wave.2.fill")
                        .foregroundStyle(.orange)
                }
                Text("Review the cloud timestamp below before updating this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func refreshStatus() async {
        iCloudStatus = await CloudKitSyncService.accountStatusText()
    }

    private func refreshShareAcceptanceState() {
        lastAcceptedShareDate = UserDefaults.standard.object(forKey: "HomeKeeperLastAcceptedCloudShareDate") as? Date
        lastShareError = UserDefaults.standard.string(forKey: "HomeKeeperLastCloudShareError")
    }

    private func refreshCloudOverview(showErrors: Bool) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            await refreshCloudOverviewAsync(showErrors: showErrors)
            isWorking = false
        }
    }

    private func refreshCloudOverviewAsync(showErrors: Bool) async {
        guard iCloudStatus == "Available" else { return }

        do {
            privateSnapshot = try await CloudKitSyncService.latestSnapshot()
        } catch {
            privateSnapshot = nil
            if showErrors && currentUserIsOwner {
                statusMessage = error.localizedDescription
            }
        }

        do {
            sharedSnapshot = try await CloudKitSyncService.latestSharedSnapshot()
            refreshShareAcceptanceState()
        } catch {
            sharedSnapshot = nil
            if showErrors && !currentUserIsOwner && lastAcceptedShareDate != nil {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func uploadPrivate(_ household: Household) {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.uploadCurrentHousehold(household: household, context: modelContext)
                privateSnapshot = summary
                CloudKitSyncCheckpointStore.markApplied(
                    summary.updatedAt,
                    householdID: summary.householdID,
                    scope: .privateHousehold
                )
                statusMessage = "Uploaded \(summary.homeName) to your private iCloud database."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func checkPrivateCloud(showErrors: Bool) {
        isWorking = true
        Task {
            do {
                privateSnapshot = try await CloudKitSyncService.latestSnapshot()
            } catch {
                privateSnapshot = nil
                if showErrors { statusMessage = error.localizedDescription }
            }
            isWorking = false
        }
    }

    private func downloadPrivate() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.downloadLatestHouseholdIntoEmptyStore(context: modelContext, accountSession: accountSession)
                privateSnapshot = summary
                CloudKitSyncCheckpointStore.markApplied(
                    summary.updatedAt,
                    householdID: summary.householdID,
                    scope: .privateHousehold
                )
                statusMessage = "Downloaded \(summary.homeName) from your private iCloud database."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func replaceFromPrivateCloud() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.replaceLocalHomeWithLatestSnapshot(context: modelContext, accountSession: accountSession)
                privateSnapshot = summary
                CloudKitSyncCheckpointStore.markApplied(
                    summary.updatedAt,
                    householdID: summary.householdID,
                    scope: .privateHousehold
                )
                statusMessage = "Updated this device with \(summary.homeName) from private iCloud."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func checkSharedCloud(showErrors: Bool) {
        isWorking = true
        Task {
            do {
                sharedSnapshot = try await CloudKitSyncService.latestSharedSnapshot()
                refreshShareAcceptanceState()
            } catch {
                sharedSnapshot = nil
                if showErrors { statusMessage = error.localizedDescription }
            }
            isWorking = false
        }
    }

    private func downloadShared() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.downloadLatestSharedHouseholdIntoEmptyStore(context: modelContext, accountSession: accountSession)
                sharedSnapshot = summary
                CloudKitSyncCheckpointStore.markApplied(
                    summary.updatedAt,
                    householdID: summary.householdID,
                    scope: .sharedHousehold
                )
                statusMessage = "Downloaded shared household \(summary.homeName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func replaceFromSharedCloud() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.replaceLocalHomeWithLatestSharedSnapshot(context: modelContext, accountSession: accountSession)
                sharedSnapshot = summary
                CloudKitSyncCheckpointStore.markApplied(
                    summary.updatedAt,
                    householdID: summary.householdID,
                    scope: .sharedHousehold
                )
                statusMessage = "Updated this device with shared household \(summary.homeName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func uploadShared(_ household: Household) {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.uploadCurrentSharedHousehold(household: household, context: modelContext)
                sharedSnapshot = summary
                CloudKitSyncCheckpointStore.markApplied(
                    summary.updatedAt,
                    householdID: summary.householdID,
                    scope: .sharedHousehold
                )
                statusMessage = "Uploaded your changes to shared household \(summary.homeName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
