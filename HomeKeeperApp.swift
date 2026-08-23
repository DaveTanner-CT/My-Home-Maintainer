import SwiftUI
import SwiftData

@main
struct HomeKeeperApp: App {
    private var modelContainer: ModelContainer = {
        let schema = Schema([
            Home.self,
            Room.self,
            Vendor.self,
            HomeSystem.self,
            Appliance.self,
            PaintFinish.self,
            Detector.self,
            Consumable.self,
            MaintenanceTask.self,
            MaintenanceRecord.self,
            Project.self,
            ProjectItem.self,
            ProjectMeasurement.self
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
                .task {
                    await NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(modelContainer)
    }
}
