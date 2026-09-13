import SwiftData
import SwiftUI

struct CloudKitSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var households: [Household]

    @State private var iCloudStatus = "Checking…"
    @State private var isWorking = false
    @State private var lastSnapshot: CloudKitSnapshotSummary?
    @State private var statusMessage: String?
    @State private var showDownloadConfirmation = false
    @State private var showReplaceConfirmation = false

    var body: some View {
        List {
            Section("iCloud") {
                LabeledContent("iCloud Account", value: iCloudStatus)
                LabeledContent("Storage", value: "Your private iCloud database")
                Text("Your household backup is stored in your own iCloud account through CloudKit. My Home Keeper does not store this household data in a developer-owned Supabase database.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("This Device") {
                if let household = households.first {
                    LabeledContent("Household", value: household.name)
                    if let home = household.home {
                        LabeledContent("Home", value: home.name)
                    }
                    LabeledContent("iCloud Backup", value: household.syncReady ? "Uploaded" : "Not Uploaded Yet")

                    Button {
                        upload(household)
                    } label: {
                        Label("Upload This Home to iCloud", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(iCloudStatus != "Available" || isWorking)
                } else {
                    ContentUnavailableView(
                        "No Household Yet",
                        systemImage: "person.2",
                        description: Text("Create a household around the home already on this device before the first iCloud upload.")
                    )
                }
            }

            Section("Other Apple Device") {
                Button {
                    checkCloud()
                } label: {
                    Label("Check iCloud for My Household", systemImage: "icloud")
                }
                .disabled(iCloudStatus != "Available" || isWorking)

                if let lastSnapshot {
                    LabeledContent("iCloud Household", value: lastSnapshot.householdName)
                    LabeledContent("iCloud Home", value: lastSnapshot.homeName)
                    LabeledContent("Last Uploaded", value: lastSnapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))

                    Button {
                        showDownloadConfirmation = true
                    } label: {
                        Label("Download to This Empty Device", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(isWorking)

                    Button(role: .destructive) {
                        showReplaceConfirmation = true
                    } label: {
                        Label("Replace Local Home from iCloud", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isWorking)
                }
            }

            Section("CloudKit Pivot") {
                Label("Household data is stored in the user's private iCloud database", systemImage: "lock.icloud")
                Label("This foundation uses a private CloudKit record zone", systemImage: "externaldrive.badge.icloud")
                Label("Family sharing with CKShare is the next phase", systemImage: "person.2.badge.gearshape")
                Text("v0.46 proves private iCloud storage and same-account iPhone/iPad transfer first. v0.47 will replace invitation codes with Apple's native CloudKit sharing flow so family members use their own Apple IDs.")
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
        .task { await refreshStatus() }
        .alert("iCloud Sync", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .confirmationDialog("Download iCloud Household?", isPresented: $showDownloadConfirmation, titleVisibility: .visible) {
            Button("Download to This Device") { download() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only works when the device has no existing home data.")
        }
        .confirmationDialog("Replace Local Home from iCloud?", isPresented: $showReplaceConfirmation, titleVisibility: .visible) {
            Button("Replace Local Home", role: .destructive) { replaceFromCloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local home records on this device and replaces them with the latest iCloud copy. Any local changes that were not uploaded first will be lost.")
        }
    }

    private func refreshStatus() async {
        iCloudStatus = await CloudKitSyncService.accountStatusText()
    }

    private func upload(_ household: Household) {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.uploadCurrentHousehold(household: household, context: modelContext)
                lastSnapshot = summary
                statusMessage = "Uploaded \(summary.homeName) to your private iCloud database."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func checkCloud() {
        isWorking = true
        Task {
            do {
                lastSnapshot = try await CloudKitSyncService.latestSnapshot()
            } catch {
                lastSnapshot = nil
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func download() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.downloadLatestHouseholdIntoEmptyStore(context: modelContext, accountSession: accountSession)
                lastSnapshot = summary
                statusMessage = "Downloaded \(summary.homeName) from iCloud."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func replaceFromCloud() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudKitSyncService.replaceLocalHomeWithLatestSnapshot(context: modelContext, accountSession: accountSession)
                lastSnapshot = summary
                statusMessage = "Replaced this device's local home with the latest iCloud copy of \(summary.homeName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
