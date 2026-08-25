import SwiftUI
import SwiftData

struct MaintenanceCalendarView: View {
    @Query(sort: \MaintenanceTask.dueDate) private var tasks: [MaintenanceTask]
    @State private var selectedDate = Date()
    @State private var statusFilter: String = "All"
    @State private var categoryFilter: String = "All"

    private var tasksForDay: [MaintenanceTask] {
        tasks.filter { task in
            Calendar.current.isDate(task.dueDate, inSameDayAs: selectedDate) &&
            (statusFilter == "All" || TaskEngine.status(for: task).rawValue == statusFilter) &&
            (categoryFilter == "All" || task.categoryRaw == categoryFilter)
        }
    }

    var body: some View {
        List {
            Section {
                DatePicker("Maintenance calendar", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }

            Section {
                Picker("Status", selection: $statusFilter) {
                    Text("All").tag("All")
                    ForEach(TaskDisplayStatus.allCases, id: \.rawValue) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Category", selection: $categoryFilter) {
                    Text("All Categories").tag("All")
                    ForEach(TaskCategory.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }

            Section(selectedDate.formatted(date: .complete, time: .omitted)) {
                if tasksForDay.isEmpty {
                    Text("No tasks on this date.").foregroundStyle(.secondary)
                } else {
                    ForEach(tasksForDay) { task in
                        NavigationLink { TaskDetailView(task: task) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.headline)
                                StatusBadge(status: TaskEngine.status(for: task))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Calendar")
    }
}
