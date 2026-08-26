import SwiftUI
import SwiftData

struct CompleteTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]

    let task: MaintenanceTask

    @State private var completionDate = Date()
    @State private var sameVendor = true
    @State private var selectedVendor: Vendor?
    @State private var costText = ""
    @State private var notes = ""
    @State private var eventType: HomeEventType = .maintenance
    @State private var saveError: String?

    var body: some View {
        Form {
            Section("Completion") {
                DatePicker("Completion date", selection: $completionDate, displayedComponents: .date)
                Picker("History type", selection: $eventType) { ForEach(HomeEventType.allCases) { Text($0.rawValue).tag($0) } }
                if task.vendor != nil { Toggle("Same vendor as task", isOn: $sameVendor) }
                if !sameVendor || task.vendor == nil {
                    Picker("Vendor", selection: $selectedVendor) {
                        Text("None").tag(nil as Vendor?)
                        ForEach(vendors) { Text($0.businessName).tag(Optional($0)) }
                    }
                }
                TextField("Cost", text: $costText).keyboardType(.decimalPad)
                TextField("Completion notes", text: $notes, axis: .vertical)
            }

            Section("Will be saved to Home History") {
                if let fixture = task.fixture { LabeledContent("Fixture", value: fixture.name) }
                if let appliance = task.appliance { LabeledContent("Device / Equipment", value: appliance.name) }
                if let system = task.system { LabeledContent("System", value: system.name) }
                if let room = resolvedRoom { LabeledContent("Room / Area", value: room.name) }
                if let project = task.project { LabeledContent("Project", value: project.title) }
            }

            if let next = TaskEngine.nextDueDate(for: task, completionDate: completionDate) {
                Section("Next Occurrence") { LabeledContent("Next due", value: next.formatted(date: .long, time: .omitted)) }
            }
        }
        .navigationTitle("Complete Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { complete() }.disabled(!costIsValid) }
        }
        .alert("Could Not Complete Task", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "The task could not be saved.") }
    }

    private var costIsValid: Bool {
        let trimmed = costText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard let value = Double(trimmed) else { return false }
        return value >= 0
    }

    private var resolvedRoom: Room? { task.room ?? task.fixture?.room ?? task.appliance?.room ?? task.system?.room ?? task.project?.room }

    private func complete() {
        let vendor = sameVendor ? task.vendor : selectedVendor
        let relatedName = task.fixture?.name ?? task.system?.name ?? task.appliance?.name ?? resolvedRoom?.name ?? task.project?.title ?? ""
        let record = MaintenanceRecord(
            date: completionDate,
            title: task.title,
            cost: Double(costText),
            notes: notes,
            vendorName: vendor?.businessName ?? "",
            taskTitle: task.title,
            relatedItemName: relatedName,
            eventType: eventType,
            room: resolvedRoom,
            system: task.system,
            appliance: task.appliance,
            fixture: task.fixture,
            project: task.project,
            vendor: vendor
        )
        modelContext.insert(record)

        if let nextDate = TaskEngine.nextDueDate(for: task, completionDate: completionDate) {
            task.dueDate = nextDate
            task.isCompleted = false
            task.completedDate = completionDate
        } else {
            task.isCompleted = true
            task.completedDate = completionDate
        }

        do {
            try modelContext.save()
            Task { await NotificationManager.shared.schedule(for: task) }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
