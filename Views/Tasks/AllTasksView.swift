import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Query(sort: \MaintenanceTask.dueDate) private var tasks: [MaintenanceTask]
    @State private var searchText = ""
    @State private var statusFilter = "All"
    @State private var categoryFilter = "All"
    @State private var showAdd = false
    @State private var completionTask: MaintenanceTask?

    private var filteredTasks: [MaintenanceTask] {
        tasks.filter { task in
            let matchesSearch = searchText.isEmpty || [task.title, task.taskDescription, task.notes, task.categoryRaw]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(searchText)
            let matchesStatus = statusFilter == "All" || TaskEngine.status(for: task).rawValue == statusFilter
            let matchesCategory = categoryFilter == "All" || task.categoryRaw == categoryFilter
            return matchesSearch && matchesStatus && matchesCategory
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $statusFilter) {
                    Text("All").tag("All")
                    ForEach(TaskDisplayStatus.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Category", selection: $categoryFilter) {
                    Text("All").tag("All")
                    ForEach(TaskCategory.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }

            Section("Tasks") {
                if filteredTasks.isEmpty {
                    Text("No tasks match these filters.").foregroundStyle(.secondary)
                } else {
                    ForEach(filteredTasks) { task in
                        NavigationLink { TaskDetailView(task: task) } label: {
                            TaskRowView(task: task) { completionTask = task }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("All Tasks")
        .searchable(text: $searchText, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { NavigationStack { TaskFormView() } }
        .sheet(item: $completionTask) { task in NavigationStack { CompleteTaskView(task: task) } }
    }
}
