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

    var body: some View {
        Form {
            Section("Completion") {
                DatePicker("Completion date", selection: $completionDate, displayedComponents: .date)
                if task.vendor != nil {
                    Toggle("Same vendor as task", isOn: $sameVendor)
                }
                if !sameVendor || task.vendor == nil {
                    Picker("Vendor", selection: $selectedVendor) {
                        Text("None").tag(nil as Vendor?)
                        ForEach(vendors) { Text($0.businessName).tag(Optional($0)) }
                    }
                }
                TextField("Cost", text: $costText)
                    .keyboardType(.decimalPad)
                TextField("Completion notes", text: $notes, axis: .vertical)
            }

            if let next = TaskEngine.nextDueDate(for: task, completionDate: completionDate) {
                Section("Next Occurrence") {
                    LabeledContent("Next due", value: next.formatted(date: .long, time: .omitted))
                }
            }
        }
        .navigationTitle("Complete Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { complete() } }
        }
    }

    private func complete() {
        let vendor = sameVendor ? task.vendor : selectedVendor
        let relatedName = task.system?.name ?? task.appliance?.name ?? task.room?.name ?? task.project?.title ?? ""
        let record = MaintenanceRecord(
            date: completionDate,
            title: task.title,
            cost: Double(costText),
            notes: notes,
            vendorName: vendor?.businessName ?? "",
            taskTitle: task.title,
            relatedItemName: relatedName
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

        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
        dismiss()
    }
}
