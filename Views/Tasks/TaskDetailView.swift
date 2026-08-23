import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let task: MaintenanceTask
    @State private var showComplete = false
    @State private var showEdit = false

    var body: some View {
        List {
            Section {
                HStack {
                    StatusBadge(status: TaskEngine.status(for: task))
                    Spacer()
                    Text(task.category.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Due", value: task.dueDate.formatted(date: .long, time: .omitted))
                LabeledContent("Lead time", value: "\(task.leadTimeDays) days")
                LabeledContent("Repeats", value: task.recurrence.rawValue)
                LabeledContent("Recurrence basis", value: task.recurrenceAnchor.rawValue)
            }

            if !task.taskDescription.isEmpty || !task.instructions.isEmpty || !task.notes.isEmpty {
                Section("Details") {
                    if !task.taskDescription.isEmpty { Text(task.taskDescription) }
                    if !task.instructions.isEmpty { LabeledContent("Instructions") { Text(task.instructions) } }
                    if !task.notes.isEmpty { LabeledContent("Notes") { Text(task.notes) } }
                }
            }

            if task.vendor != nil || !task.phone.isEmpty || !task.email.isEmpty || !task.website.isEmpty {
                Section("Contact") {
                    if let vendor = task.vendor { LabeledContent("Vendor", value: vendor.businessName) }
                    if !task.contactName.isEmpty { LabeledContent("Contact", value: task.contactName) }
                    if !task.phone.isEmpty, let url = URL(string: "tel:\(task.phone.filter { $0.isNumber })") {
                        Link(destination: url) { Label(task.phone, systemImage: "phone") }
                    }
                    if !task.email.isEmpty, let url = URL(string: "mailto:\(task.email)") {
                        Link(destination: url) { Label(task.email, systemImage: "envelope") }
                    }
                    if !task.website.isEmpty, let url = URL(string: task.website) {
                        Link(destination: url) { Label("Website", systemImage: "safari") }
                    }
                }
            }

            Section("Related") {
                if let system = task.system { LabeledContent("System", value: system.name) }
                if let appliance = task.appliance { LabeledContent("Appliance", value: appliance.name) }
                if let room = task.room { LabeledContent("Room", value: room.name) }
                if let project = task.project { LabeledContent("Project", value: project.title) }
            }

            if !task.isCompleted {
                Section {
                    Button { showComplete = true } label: {
                        Label("Complete Task", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showComplete) { NavigationStack { CompleteTaskView(task: task) } }
        .sheet(isPresented: $showEdit) { NavigationStack { TaskFormView(existingTask: task) } }
    }
}
