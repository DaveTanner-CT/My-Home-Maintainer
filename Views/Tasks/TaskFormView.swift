import SwiftUI
import SwiftData

struct TaskFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @Query(sort: \Appliance.name) private var appliances: [Appliance]
    @Query(sort: \Fixture.name) private var fixtures: [Fixture]
    @Query(sort: \Project.title) private var projects: [Project]

    let existingTask: MaintenanceTask?

    @State private var title: String
    @State private var description: String
    @State private var category: TaskCategory
    @State private var dueDate: Date
    @State private var leadTimeDays: Int
    @State private var recurrence: RecurrenceRule
    @State private var recurrenceAnchor: RecurrenceAnchor
    @State private var priority: Int
    @State private var notes: String
    @State private var instructions: String
    @State private var contactName: String
    @State private var phone: String
    @State private var email: String
    @State private var website: String
    @State private var selectedVendor: Vendor?
    @State private var selectedRoom: Room?
    @State private var selectedSystem: HomeSystem?
    @State private var selectedAppliance: Appliance?
    @State private var selectedFixture: Fixture?
    @State private var selectedProject: Project?

    init(
        existingTask: MaintenanceTask? = nil,
        initialRoom: Room? = nil,
        initialSystem: HomeSystem? = nil,
        initialAppliance: Appliance? = nil,
        initialFixture: Fixture? = nil,
        initialProject: Project? = nil,
        initialTitle: String = "",
        initialDescription: String = "",
        initialCategory: TaskCategory = .general,
        initialDueDate: Date = .now,
        initialLeadTimeDays: Int = 0,
        initialRecurrence: RecurrenceRule = .oneTime,
        initialPriority: Int = 1
    ) {
        self.existingTask = existingTask
        _title = State(initialValue: existingTask?.title ?? initialTitle)
        _description = State(initialValue: existingTask?.taskDescription ?? initialDescription)
        _category = State(initialValue: existingTask?.category ?? initialCategory)
        _dueDate = State(initialValue: existingTask?.dueDate ?? initialDueDate)
        _leadTimeDays = State(initialValue: existingTask?.leadTimeDays ?? initialLeadTimeDays)
        _recurrence = State(initialValue: existingTask?.recurrence ?? initialRecurrence)
        _recurrenceAnchor = State(initialValue: existingTask?.recurrenceAnchor ?? .scheduledDate)
        _priority = State(initialValue: existingTask?.priority ?? initialPriority)
        _notes = State(initialValue: existingTask?.notes ?? "")
        _instructions = State(initialValue: existingTask?.instructions ?? "")
        _contactName = State(initialValue: existingTask?.contactName ?? "")
        _phone = State(initialValue: existingTask?.phone ?? "")
        _email = State(initialValue: existingTask?.email ?? "")
        _website = State(initialValue: existingTask?.website ?? "")
        _selectedVendor = State(initialValue: existingTask?.vendor)
        _selectedSystem = State(initialValue: existingTask?.system ?? initialSystem)
        _selectedAppliance = State(initialValue: existingTask?.appliance ?? initialAppliance)
        _selectedFixture = State(initialValue: existingTask?.fixture ?? initialFixture)
        _selectedProject = State(initialValue: existingTask?.project ?? initialProject)
        let inferredRoom = initialRoom ?? initialFixture?.room ?? initialAppliance?.room ?? initialSystem?.room ?? initialProject?.room
        _selectedRoom = State(initialValue: existingTask?.room ?? inferredRoom)
    }

    var body: some View {
        Form {
            Section("Task") {
                TextField("Task name", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                Picker("Category", selection: $category) { ForEach(TaskCategory.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Priority", selection: $priority) { Text("Low").tag(0); Text("Normal").tag(1); Text("High").tag(2) }
            }
            Section("Schedule") {
                DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                Stepper("Lead time: \(leadTimeDays) days", value: $leadTimeDays, in: 0...365)
                Picker("Repeat", selection: $recurrence) { ForEach(RecurrenceRule.allCases) { Text($0.rawValue).tag($0) } }
                if recurrence != .oneTime { Picker("Repeat from", selection: $recurrenceAnchor) { ForEach(RecurrenceAnchor.allCases) { Text($0.rawValue).tag($0) } } }
            }
            Section("Related Home Records") {
                Picker("Room / Area", selection: $selectedRoom) { Text("None").tag(nil as Room?); ForEach(rooms) { Text($0.name).tag(Optional($0)) } }
                Picker("Fixture", selection: $selectedFixture) { Text("None").tag(nil as Fixture?); ForEach(fixtures) { Text($0.name).tag(Optional($0)) } }
                Picker("Device / Equipment", selection: $selectedAppliance) { Text("None").tag(nil as Appliance?); ForEach(appliances) { Text($0.name).tag(Optional($0)) } }
                Picker("System", selection: $selectedSystem) { Text("None").tag(nil as HomeSystem?); ForEach(systems) { Text($0.name).tag(Optional($0)) } }
                Picker("Project", selection: $selectedProject) { Text("None").tag(nil as Project?); ForEach(projects) { Text($0.title).tag(Optional($0)) } }
                Picker("Vendor", selection: $selectedVendor) { Text("None").tag(nil as Vendor?); ForEach(vendors) { Text($0.businessName).tag(Optional($0)) } }
                Text("A task can stay connected to the physical item, its room, its project, and the vendor. Selecting an item will use its Room / Area when no room is selected.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Contact") {
                TextField("Contact name", text: $contactName)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            Section("Instructions & Notes") { TextField("Instructions", text: $instructions, axis: .vertical); TextField("Notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle(existingTask == nil ? "New Task" : "Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .onChange(of: selectedFixture) { _, value in if selectedRoom == nil { selectedRoom = value?.room } }
        .onChange(of: selectedAppliance) { _, value in if selectedRoom == nil { selectedRoom = value?.room } }
        .onChange(of: selectedSystem) { _, value in if selectedRoom == nil { selectedRoom = value?.room } }
        .onChange(of: selectedProject) { _, value in if selectedRoom == nil { selectedRoom = value?.room } }
    }

    private func save() {
        let task = existingTask ?? MaintenanceTask(title: title, dueDate: dueDate)
        if existingTask == nil { modelContext.insert(task) }
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines); task.taskDescription = description; task.category = category; task.dueDate = dueDate
        task.leadTimeDays = leadTimeDays; task.recurrence = recurrence; task.recurrenceAnchor = recurrenceAnchor; task.priority = priority; task.notes = notes; task.instructions = instructions
        task.contactName = contactName; task.phone = phone; task.email = email; task.website = website
        task.vendor = selectedVendor; task.system = selectedSystem; task.appliance = selectedAppliance; task.fixture = selectedFixture; task.project = selectedProject
        task.room = selectedRoom ?? selectedFixture?.room ?? selectedAppliance?.room ?? selectedSystem?.room ?? selectedProject?.room
        try? modelContext.save(); Task { await NotificationManager.shared.schedule(for: task) }; dismiss()
    }
}
