import CloudKit
import SwiftData
import SwiftUI
import UIKit

final class HomeKeeperAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            do {
                try await CloudKitSyncService.acceptShare(metadata: cloudKitShareMetadata)
                UserDefaults.standard.set(Date(), forKey: "HomeKeeperLastAcceptedCloudShareDate")
                UserDefaults.standard.removeObject(forKey: "HomeKeeperLastCloudShareError")
            } catch {
                UserDefaults.standard.set(error.localizedDescription, forKey: "HomeKeeperLastCloudShareError")
            }
        }
    }
}

@main
struct HomeKeeperApp: App {
    @UIApplicationDelegateAdaptor(HomeKeeperAppDelegate.self) private var appDelegate
    @StateObject private var accountSession = AccountSessionStore()

    private var modelContainer: ModelContainer = {
        let schema = Schema([
            Home.self,
            Room.self,
            Vendor.self,
            HomeSystem.self,
            Appliance.self,
            PaintFinish.self,
            Fixture.self,
            Furniture.self,
            Detector.self,
            Consumable.self,
            MaintenanceTask.self,
            MaintenanceRecord.self,
            Project.self,
            ProjectItem.self,
            ProjectMeasurement.self,
            HomeAttachment.self,
            Household.self,
            HouseholdMember.self,
            HouseholdInvitation.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        UserDefaults.standard.removeObject(forKey: "HomeKeeperStartupStoreError")
        UserDefaults.standard.removeObject(forKey: "HomeKeeperStartupStoreErrorDate")

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Never delete or rewrite the existing on-device store automatically.
            // If SwiftData returns a recoverable open error, launch with a temporary
            // in-memory store so the app can still open for diagnostics/recovery.
            UserDefaults.standard.set(error.localizedDescription, forKey: "HomeKeeperStartupStoreError")
            UserDefaults.standard.set(Date(), forKey: "HomeKeeperStartupStoreErrorDate")

            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfiguration])
            } catch {
                fatalError("Could not create recovery model container: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            StartupRootView()
                .environmentObject(accountSession)
                .task {
                    accountSession.refreshCredentialState()
                    await NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(modelContainer)
    }
}

private struct StartupRootView: View {
    @State private var recoveryMessage: String? = UserDefaults.standard.string(forKey: "HomeKeeperStartupStoreError")

    var body: some View {
        RootTabView()
            .alert(
                "Local Data Recovery Mode",
                isPresented: Binding(
                    get: { recoveryMessage != nil },
                    set: { if !$0 { recoveryMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    recoveryMessage = nil
                }
            } message: {
                Text("My Home Keeper could not open the existing local database, so it started with a temporary recovery store. Your original on-device database was not deleted or overwritten. Do not re-enter or replace your home data yet. Error: \(recoveryMessage ?? "Unknown storage error")")
            }
    }
}
