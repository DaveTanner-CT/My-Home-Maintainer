import SwiftUI
import SwiftData

enum TasksHubSection: String, CaseIterable, Identifiable {
    case attention = "Attention"
    case upcoming = "Upcoming"
    case all = "All"
    case calendar = "Calendar"

    var id: String { rawValue }
}

struct TasksHubView: View {
    @Query(sort: \MaintenanceTask.dueDate) private var tasks: [MaintenanceTask]

    @State private var section: TasksHubSection
    @State private var searchText = ""
    @State private var categoryFilter = "All"
    @State private var statusFilter = "All"
    @State private var selectedDate = Date()
    @State private var showAdd = false
    @State private var completionTask: MaintenanceTask?

    init(initialSection: TasksHubSection = .attention) {
        _section = State(initialValue: initialSection)
    }

    private var searchedTasks: [MaintenanceTask] {
        tasks.filter { task in
            searchText.isEmpty || [
                task.title,
                task.taskDescription,
                task.notes,
                task.categoryRaw,
                task.vendor?.businessName ?? "",
                task.room?.name ?? "",
                task.system?.name ?? "",
                task.appliance?.name ?? ""
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var categoryFilteredTasks: [MaintenanceTask] {
        searchedTasks.filter { task in
            categoryFilter == "All" || task.categoryRaw == categoryFilter
        }
    }

    private var attentionTasks: [MaintenanceTask] {
        categoryFilteredTasks.filter {
            let status = TaskEngine.status(for: $0)
            return status == .overdue || status == .current
        }
    }

    private var upcomingTasks: [MaintenanceTask] {
        categoryFilteredTasks.filter { TaskEngine.status(for: $0) == .upcoming }
    }

    private var allTasks: [MaintenanceTask] {
        categoryFilteredTasks.filter { task in
            statusFilter == "All" || TaskEngine.status(for: task).rawValue == statusFilter
        }
    }

    private var calendarTasks: [MaintenanceTask] {
        categoryFilteredTasks.filter { task in
            Calendar.current.isDate(task.dueDate, inSameDayAs: selectedDate) &&
            (statusFilter == "All" || TaskEngine.status(for: task).rawValue == statusFilter)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Task view", selection: $section) {
                    ForEach(TasksHubSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            if section == .calendar {
                calendarControls
            } else {
                listControls
            }

            switch section {
            case .attention:
                taskSection(
                    title: "Needs Attention",
                    tasks: attentionTasks,
                    emptyTitle: "You're caught up",
                    emptyMessage: "No overdue or current maintenance tasks."
                )

            case .upcoming:
                taskSection(
                    title: "Upcoming",
                    tasks: upcomingTasks,
                    emptyTitle: "Nothing coming up",
                    emptyMessage: "No upcoming tasks match your search and filters."
                )

            case .all:
                taskSection(
                    title: "All Tasks",
                    tasks: allTasks,
                    emptyTitle: "No tasks found",
                    emptyMessage: "No tasks match your search and filters."
                )

            case .calendar:
                calendarSection
            }
        }
        .navigationTitle("Tasks")
        .searchable(text: $searchText, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Task")
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { TaskFormView() }
        }
        .sheet(item: $completionTask) { task in
            NavigationStack { CompleteTaskView(task: task) }
        }
        .onChange(of: section) { _, newValue in
            if newValue != .all && newValue != .calendar {
                statusFilter = "All"
            }
        }
    }

    private var listControls: some View {
        Section("Filter") {
            Picker("Category", selection: $categoryFilter) {
                Text("All Categories").tag("All")
                ForEach(TaskCategory.allCases) { category in
                    Text(category.rawValue).tag(category.rawValue)
                }
            }

            if section == .all {
                Picker("Status", selection: $statusFilter) {
                    Text("All Statuses").tag("All")
                    ForEach(TaskDisplayStatus.allCases, id: \.rawValue) { status in
                        Text(status.rawValue).tag(status.rawValue)
                    }
                }
            }
        }
    }

    private var calendarControls: some View {
        Group {
            Section {
                DatePicker("Maintenance calendar", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }

            Section("Filter") {
                Picker("Category", selection: $categoryFilter) {
                    Text("All Categories").tag("All")
                    ForEach(TaskCategory.allCases) { category in
                        Text(category.rawValue).tag(category.rawValue)
                    }
                }

                Picker("Status", selection: $statusFilter) {
                    Text("All Statuses").tag("All")
                    ForEach(TaskDisplayStatus.allCases, id: \.rawValue) { status in
                        Text(status.rawValue).tag(status.rawValue)
                    }
                }

                Button("Today") {
                    selectedDate = Date()
                }
            }
        }
    }

    @ViewBuilder
    private func taskSection(title: String, tasks: [MaintenanceTask], emptyTitle: String, emptyMessage: String) -> some View {
        Section(title) {
            if tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(emptyTitle)
                        .font(.headline)
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(tasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task)
                    } label: {
                        TaskRowView(task: task) {
                            completionTask = task
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var calendarSection: some View {
        Section(selectedDate.formatted(date: .complete, time: .omitted)) {
            if calendarTasks.isEmpty {
                Text("No tasks on this date.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(calendarTasks) { task in
                    NavigationLink {
                        TaskDetailView(task: task)
                    } label: {
                        TaskRowView(task: task) {
                            completionTask = task
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
