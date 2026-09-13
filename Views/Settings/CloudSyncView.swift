import SwiftData
import SwiftUI

struct CloudSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var households: [Household]

    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var lastSnapshot: CloudSnapshotSummary?
    @State private var showDownloadConfirmation = false
    @State private var showReplaceConfirmation = false

    var body: some View {
        List {
            Section("Cloud Connection") {
                LabeledContent("Supabase", value: SupabaseConfiguration.configurationSummary)
                LabeledContent("Apple Account", value: accountSession.isSignedIn ? "Signed In" : "Not Signed In")
                LabeledContent("Cloud Session", value: accountSession.cloudStatusText)

                if let date = accountSession.cloudLastAuthenticatedAt {
                    LabeledContent("Cloud Sign-In", value: date.formatted(date: .abbreviated, time: .shortened))
                }

                if !SupabaseConfiguration.isConfigured {
                    Text("Cloud sync is ready in the app, but this build still needs your Supabase Project URL and publishable key in project.yml before it can connect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if accountSession.isSignedIn && !accountSession.isCloudConnected {
                    Text("Sign out and sign back in with Apple once after Supabase is configured. That creates the authenticated Supabase session used for household sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("This Device") {
                if let household = households.first {
                    LabeledContent("Household", value: household.name)
                    LabeledContent("Local Home", value: household.home?.name ?? "Not linked")
                    LabeledContent("Cloud Ready", value: household.syncReady ? "Yes" : "Not uploaded yet")

                    Button {
                        upload(household)
                    } label: {
                        Label("Upload This Home to Cloud", systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(!canUseCloud || isWorking)
                } else {
                    ContentUnavailableView(
                        "No Household Yet",
                        systemImage: "person.2",
                        description: Text("Create the household on the device that already contains your home records before the first upload.")
                    )
                }
            }

            Section("Other Device") {
                Button {
                    checkCloud()
                } label: {
                    Label("Check for My Cloud Household", systemImage: "icloud")
                }
                .disabled(!canUseCloud || isWorking)

                if let lastSnapshot {
                    LabeledContent("Cloud Household", value: lastSnapshot.householdName)
                    LabeledContent("Cloud Home", value: lastSnapshot.homeName)
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
                        Label("Replace Local Home from Cloud", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isWorking)
                }

                Text("Initial download is intentionally limited to an empty home-data store. My Home Keeper will not overwrite a device that already contains rooms, systems, tasks, or other home records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("v0.43 Sync Scope") {
                Label("Rooms, systems, devices, fixtures, furniture, paint, projects, tasks, vendors, detectors, consumables, and history", systemImage: "checkmark.circle")
                Label("Photos and documents remain local in this release", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                Text("Shared photo/document storage is the next phase. Keeping binary files out of the first cloud snapshot makes initial household sync safer and easier to test.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("Working with cloud data…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Cloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cloud Sync", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .confirmationDialog(
            "Download Cloud Household?",
            isPresented: $showDownloadConfirmation,
            titleVisibility: .visible
        ) {
            Button("Download to This Device") { download() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is only allowed when this device has no existing home data. The cloud household will become the local household on this device.")
        }
        .confirmationDialog(
            "Replace Local Home from Cloud?",
            isPresented: $showReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace Local Home", role: .destructive) { replaceFromCloud() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the local home records on this device and replaces them with the latest cloud snapshot. Any local changes that were not uploaded first will be lost. Photos and documents remain outside v0.43 cloud sync.")
        }
    }

    private var canUseCloud: Bool {
        SupabaseConfiguration.isConfigured && accountSession.isCloudConnected
    }

    private func upload(_ household: Household) {
        isWorking = true
        Task {
            do {
                let summary = try await CloudSyncService.uploadCurrentHousehold(
                    household: household,
                    context: modelContext,
                    accountSession: accountSession
                )
                lastSnapshot = summary
                statusMessage = "Uploaded \(summary.homeName) to the \(summary.householdName) cloud household."
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
                lastSnapshot = try await CloudSyncService.latestSnapshot(accountSession: accountSession)
            } catch {
                lastSnapshot = nil
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }


    private func replaceFromCloud() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudSyncService.replaceLocalHomeWithLatestSnapshot(
                    context: modelContext,
                    accountSession: accountSession
                )
                lastSnapshot = summary
                statusMessage = "Replaced this device's local home with the latest cloud copy of \(summary.homeName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func download() {
        isWorking = true
        Task {
            do {
                let summary = try await CloudSyncService.downloadLatestHouseholdIntoEmptyStore(
                    context: modelContext,
                    accountSession: accountSession
                )
                lastSnapshot = summary
                statusMessage = "Downloaded \(summary.homeName). This device is now linked to \(summary.householdName)."
            } catch {
                statusMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}
