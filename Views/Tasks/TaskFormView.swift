import SwiftUI
import SwiftData

struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @Query(sort: \Appliance.name) private var appliances: [Appliance]

    let existingTask: MaintenanceTask?

    @State private var title = ""
    @State private var description = ""
    @State private var category: TaskCategory = .general
    @State private var dueDate = Date()
    @State private var leadTimeDays = 0
    @State private var recurrence: RecurrenceRule = .oneTime
    @State private var recurrenceAnchor: RecurrenceAnchor = .scheduledDate
    @State private var notes = ""
    @State private var instructions = ""
    @State private var selectedVendor: Vendor?
    @State private var selectedRoom: Room?
    @State private var selectedSystem: HomeSystem?
    @State private var selectedAppliance: Appliance?

    init(existingTask: MaintenanceTask? = nil) {
        self.existingTask = existingTask
    }

    var body: some View {
        Form {
            Section("Task") {
                TextField("Task name", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                Picker("Category", selection: $category) {
                    ForEach(TaskCategory.allCases) { Text($0.rawValue).tag($0) }
                }
            }

            Section("Schedule") {
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                Stepper("Lead time: \(leadTimeDays) days", value: $leadTimeDays, in: 0...365)
                Picker("Repeat", selection: $recurrence) {
                    ForEach(RecurrenceRule.allCases) { Text($0.rawValue).tag($0) }
                }
                if recurrence != .oneTime {
                    Picker("Repeat from", selection: $recurrenceAnchor) {
                        ForEach(RecurrenceAnchor.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }

            Section("Related Home Records") {
                Picker("Vendor", selection: $selectedVendor) {
                    Text("None").tag(nil as Vendor?)
                    ForEach(vendors) { Text($0.businessName).tag(Optional($0)) }
                }
                Picker("Room", selection: $selectedRoom) {
                    Text("None").tag(nil as Room?)
                    ForEach(rooms) { Text($0.name).tag(Optional($0)) }
                }
                Picker("System", selection: $selectedSystem) {
                    Text("None").tag(nil as HomeSystem?)
                    ForEach(systems) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Appliance", selection: $selectedAppliance) {
                    Text("None").tag(nil as Appliance?)
                    ForEach(appliances) { Text($0.name).tag(Optional($0)) }
                }
            }

            Section("Notes") {
                TextField("Instructions", text: $instructions, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        guard let task = existingTask else { return }
        title = task.title
        description = task.taskDescription
        category = task.category
        dueDate = task.dueDate
        leadTimeDays = task.leadTimeDays
        recurrence = task.recurrence
        recurrenceAnchor = task.recurrenceAnchor
        notes = task.notes
        instructions = task.instructions
        selectedVendor = task.vendor
        selectedRoom = task.room
        selectedSystem = task.system
        selectedAppliance = task.appliance
    }

    private func save() {
        let task: MaintenanceTask
        if let existingTask {
            task = existingTask
        } else {
            task = MaintenanceTask(title: title, dueDate: dueDate)
            modelContext.insert(task)
        }

        task.title = title
        task.taskDescription = description
        task.category = category
        task.dueDate = dueDate
        task.leadTimeDays = leadTimeDays
        task.recurrence = recurrence
        task.recurrenceAnchor = recurrenceAnchor
        task.notes = notes
        task.instructions = instructions
        task.vendor = selectedVendor
        task.room = selectedRoom
        task.system = selectedSystem
        task.appliance = selectedAppliance

        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
        dismiss()
    }
}
