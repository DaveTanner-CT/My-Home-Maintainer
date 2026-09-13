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

    var body: some View {
        List {
            Section("iCloud") {
                LabeledContent("iCloud Account", value: iCloudStatus)
                LabeledContent("Storage", value: "Private + Shared CloudKit")
                Text("Your own household lives in your private iCloud database. Family households shared with you appear through Apple's shared CloudKit database.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let accepted = lastAcceptedShareDate {
                Section("Family Invitation") {
                    Label("CloudKit invitation accepted", systemImage: "person.2.circle.fill")
                        .foregroundStyle(.green)
                    LabeledContent("Accepted", value: accepted.formatted(date: .abbreviated, time: .shortened))
                    Text("Tap Check for Shared Household below to load the household that was shared with this Apple ID.")
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
                if let household = households.first {
                    LabeledContent("Household", value: household.name)
                    if let home = household.home {
                        LabeledContent("Home", value: home.name)
                    }
                    LabeledContent("iCloud Backup", value: household.syncReady ? "Uploaded" : "Not Uploaded Yet")

                    Button {
                        uploadPrivate(household)
                    } label: {
                        Label("Upload This Home to iCloud", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(iCloudStatus != "Available" || isWorking)
                } else {
                    Text("If this device owns a household, create it locally first and upload it here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    checkPrivateCloud()
                } label: {
                    Label("Check My Private iCloud Household", systemImage: "icloud")
                }
                .disabled(iCloudStatus != "Available" || isWorking)

                if let privateSnapshot {
                    LabeledContent("iCloud Household", value: privateSnapshot.householdName)
                    LabeledContent("iCloud Home", value: privateSnapshot.homeName)
                    LabeledContent("Last Updated", value: privateSnapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    Button {
                        showPrivateDownloadConfirmation = true
                    } label: {
                        Label("Download to This Empty Device", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(isWorking)

                    Button(role: .destructive) {
                        showPrivateReplaceConfirmation = true
                    } label: {
                        Label("Replace Local Home from iCloud", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isWorking)
                }
            }

            Section("Shared With Me") {
                Button {
                    checkSharedCloud()
                } label: {
                    Label("Check for Shared Household", systemImage: "person.2.badge.gearshape")
                }
                .disabled(iCloudStatus != "Available" || isWorking)

                if let sharedSnapshot {
                    LabeledContent("Shared Household", value: sharedSnapshot.householdName)
                    LabeledContent("Shared Home", value: sharedSnapshot.homeName)
                    LabeledContent("Last Updated", value: sharedSnapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    Button {
                        showSharedDownloadConfirmation = true
                    } label: {
                        Label("Download Shared Household", systemImage: "person.2.and.arrow.down")
                    }
                    .disabled(isWorking)

                    Button(role: .destructive) {
                        showSharedReplaceConfirmation = true
                    } label: {
                        Label("Replace Local Home with Shared Household", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isWorking)

                    if let household = households.first,
                       household.cloudIdentifier == sharedSnapshot.householdID {
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

            Section("Family Sharing") {
                Label("Owner invitations use Apple's native CKShare system", systemImage: "person.crop.circle.badge.checkmark")
                Label("Recipients use their own Apple ID and iCloud account", systemImage: "person.2")
                Label("Shared household records remain in the owner's iCloud container", systemImage: "lock.icloud")
                Text("This version supports accepting a CKShare invitation, downloading the shared household, and manually uploading read/write changes back to the shared CloudKit record.")
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
        .confirmationDialog("Replace Local Home from Private iCloud?", isPresented: $showPrivateReplaceConfirmation, titleVisibility: .visible) {
            Button("Replace Local Home", role: .destructive) { replaceFromPrivateCloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local home records on this device and replaces them with your latest private iCloud copy.")
        }
        .confirmationDialog("Download Shared Household?", isPresented: $showSharedDownloadConfirmation, titleVisibility: .visible) {
            Button("Download Shared Household") { downloadShared() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only works when the device has no existing home data.")
        }
        .confirmationDialog("Replace Local Home with Shared Household?", isPresented: $showSharedReplaceConfirmation, titleVisibility: .visible) {
            Button("Replace Local Home", role: .destructive) { replaceFromSharedCloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local home records on this device and replaces them with the latest shared household copy.")
        }
    }

    private func refreshStatus() async {
        iCloudStatus = await CloudKitSyncService.accountStatusText()
    }

    private func refreshShareAcceptanceState() {
        lastAcceptedShareDate = UserDefaults.standard.object(forKey: "HomeKeeperLastAcceptedCloudShareDate") as? Date
        lastShareError = UserDefaults.standard.string(forKey: "HomeKeeperLastCloudShareError")
    }

    private func uploadPrivate(_ household: Household) {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.uploadCurrentHousehold(household: household, context: modelContext)
                privateSnapshot = summary
                statusMessage = "Uploaded \(summary.homeName) to your private iCloud database."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func checkPrivateCloud() {
        isWorking = true
        Task {
            do {
                privateSnapshot = try await CloudKitSyncService.latestSnapshot()
            } catch {
                privateSnapshot = nil
                statusMessage = error.localizedDescription
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
                statusMessage = "Replaced this device's local home with \(summary.homeName) from private iCloud."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func checkSharedCloud() {
        isWorking = true
        Task {
            do {
                sharedSnapshot = try await CloudKitSyncService.latestSharedSnapshot()
                refreshShareAcceptanceState()
            } catch {
                sharedSnapshot = nil
                statusMessage = error.localizedDescription
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
                statusMessage = "Replaced this device's local home with shared household \(summary.homeName)."
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
                statusMessage = "Uploaded your changes to shared household \(summary.homeName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
