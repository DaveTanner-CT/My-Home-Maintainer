import SwiftUI
import SwiftData

enum TaskLinkTarget {
    case system(HomeSystem)
    case appliance(Appliance)
    case fixture(Fixture)
    case project(Project)
    case vendor(Vendor)

    var title: String {
        switch self {
        case .system: return "System"
        case .appliance: return "Device / Equipment"
        case .fixture: return "Fixture"
        case .project: return "Project"
        case .vendor: return "Vendor"
        }
    }

    func isLinked(_ task: MaintenanceTask) -> Bool {
        switch self {
        case .system(let item): return task.system?.persistentModelID == item.persistentModelID
        case .appliance(let item): return task.appliance?.persistentModelID == item.persistentModelID
        case .fixture(let item): return task.fixture?.persistentModelID == item.persistentModelID
        case .project(let item): return task.project?.persistentModelID == item.persistentModelID
        case .vendor(let item): return task.vendor?.persistentModelID == item.persistentModelID
        }
    }

    func canLink(_ task: MaintenanceTask) -> Bool {
        switch self {
        case .system:
            return task.system == nil || isLinked(task)
        case .appliance:
            return task.appliance == nil || isLinked(task)
        case .fixture:
            return task.fixture == nil || isLinked(task)
        case .project:
            return task.project == nil || isLinked(task)
        case .vendor:
            return task.vendor == nil || isLinked(task)
        }
    }

    func toggle(_ task: MaintenanceTask) {
        let unlink = isLinked(task)
        switch self {
        case .system(let item): task.system = unlink ? nil : item
        case .appliance(let item): task.appliance = unlink ? nil : item
        case .fixture(let item): task.fixture = unlink ? nil : item
        case .project(let item): task.project = unlink ? nil : item
        case .vendor(let item): task.vendor = unlink ? nil : item
        }
    }
}

struct ExistingTaskLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MaintenanceTask.dueDate) private var tasks: [MaintenanceTask]

    let target: TaskLinkTarget

    private var availableTasks: [MaintenanceTask] {
        tasks.filter { target.canLink($0) }
    }

    var body: some View {
        List {
            Section {
                Text("Select an existing task to link it to this \(target.title.lowercased()). Tasks already linked to a different \(target.title.lowercased()) are left alone and are not shown here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if availableTasks.isEmpty {
                ContentUnavailableView("No tasks available to link", systemImage: "link")
            } else {
                Section("Tasks") {
                    ForEach(availableTasks) { task in
                        Button {
                            target.toggle(task)
                            try? modelContext.save()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title).foregroundStyle(.primary)
                                    Text(task.dueDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: target.isLinked(task) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(target.isLinked(task) ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Link Existing Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
