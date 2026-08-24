import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let task: MaintenanceTask
    @State private var showComplete = false
    @State private var showDelete = false

    var body: some View {
        List {
            Section {
                HStack { StatusBadge(status: TaskEngine.status(for: task)); Spacer(); Text(task.category.rawValue).font(.subheadline).foregroundStyle(.secondary) }
                LabeledContent("Due", value: task.dueDate.formatted(date: .long, time: .omitted))
                if task.leadTimeDays > 0, let currentDate = Calendar.current.date(byAdding: .day, value: -task.leadTimeDays, to: task.dueDate) { LabeledContent("Current starting", value: currentDate.formatted(date: .abbreviated, time: .omitted)) }
                LabeledContent("Lead time", value: "\(task.leadTimeDays) days")
                LabeledContent("Repeats", value: task.recurrence.rawValue)
                if task.recurrence != .oneTime { LabeledContent("Recurrence basis", value: task.recurrenceAnchor.rawValue) }
                LabeledContent("Priority", value: task.priority == 2 ? "High" : task.priority == 0 ? "Low" : "Normal")
            }
            if !task.taskDescription.isEmpty || !task.instructions.isEmpty || !task.notes.isEmpty {
                Section("Details") { if !task.taskDescription.isEmpty { Text(task.taskDescription) }; if !task.instructions.isEmpty { LabeledContent("Instructions") { Text(task.instructions) } }; if !task.notes.isEmpty { LabeledContent("Notes") { Text(task.notes) } } }
            }
            if task.vendor != nil || !task.contactName.isEmpty || !task.phone.isEmpty || !task.email.isEmpty || !task.website.isEmpty {
                Section("Contact") {
                    if let vendor = task.vendor { NavigationLink { VendorDetailView(vendor: vendor) } label: { LabeledContent("Vendor", value: vendor.businessName) } }
                    if !task.contactName.isEmpty { LabeledContent("Contact", value: task.contactName) }
                    if !task.phone.isEmpty, let url = URL(string: "tel:\(task.phone.filter { $0.isNumber })") { Link(destination: url) { Label(task.phone, systemImage: "phone") } }
                    if !task.email.isEmpty, let url = URL(string: "mailto:\(task.email)") { Link(destination: url) { Label(task.email, systemImage: "envelope") } }
                    if !task.website.isEmpty, let url = URL(string: task.website.hasPrefix("http") ? task.website : "https://\(task.website)") { Link(destination: url) { Label("Website", systemImage: "safari") } }
                }
            }
            Section("Related") {
                if let system = task.system { NavigationLink { SystemDetailView(system: system) } label: { LabeledContent("System", value: system.name) } }
                if let appliance = task.appliance { NavigationLink { ApplianceDetailView(appliance: appliance) } label: { LabeledContent("Appliance", value: appliance.name) } }
                if let room = task.room { NavigationLink { RoomDetailView(room: room) } label: { LabeledContent("Room", value: room.name) } }
                if let project = task.project { NavigationLink { ProjectDetailView(project: project) } label: { LabeledContent("Project", value: project.title) } }
                if task.system == nil && task.appliance == nil && task.room == nil && task.project == nil { Text("No related records").foregroundStyle(.secondary) }
            }
            if !task.isCompleted { Section { Button { showComplete = true } label: { Label("Complete Task", systemImage: "checkmark.circle.fill").frame(maxWidth: .infinity) } } }
            Section { Button("Delete Task", role: .destructive) { showDelete = true } }
        }
        .navigationTitle(task.title).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("Edit") { TaskFormView(existingTask: task) } } }
        .sheet(isPresented: $showComplete) { NavigationStack { CompleteTaskView(task: task) } }
        .confirmationDialog("Delete this task?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete Task", role: .destructive) { modelContext.delete(task); try? modelContext.save(); dismiss() }; Button("Cancel", role: .cancel) { } } message: { Text("Existing maintenance history will not be deleted.") }
    }
}
