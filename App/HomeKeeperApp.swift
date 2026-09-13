import SwiftUI
import SwiftData

@main
struct HomeKeeperApp: App {
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
            HomeAttachment.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(accountSession)
                .task {
                    accountSession.refreshCredentialState()

                    await NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(modelContainer)
    }
}
