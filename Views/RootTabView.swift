import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didRunStartupMaintenance = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeDashboardView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                TasksHubView()
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }

            NavigationStack {
                MyHomeView()
            }
            .tabItem { Label("My Home", systemImage: "wrench.and.screwdriver") }

            NavigationStack {
                ProjectsView()
            }
            .tabItem { Label("Projects", systemImage: "hammer.fill") }
        }
        .task {
            guard !didRunStartupMaintenance else { return }
            didRunStartupMaintenance = true
            LegacySampleDataCleanup.runIfNeeded(context: modelContext)
            if let tasks = try? modelContext.fetch(FetchDescriptor<MaintenanceTask>()) {
                for task in tasks where !task.isCompleted {
                    await NotificationManager.shared.schedule(for: task)
                }
            }
        }
    }
}
