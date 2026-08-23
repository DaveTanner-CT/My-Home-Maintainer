import SwiftUI

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var description = ""
    @State private var stage: ProjectStage = .idea
    @State private var roomName = ""
    @State private var budgetText = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Project") {
                TextField("Project name", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                Picker("Stage", selection: $stage) {
                    ForEach(ProjectStage.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Room / area", text: $roomName)
            }
            Section("Planning") {
                TextField("Budget", text: $budgetText).keyboardType(.decimalPad)
                Toggle("Target date", isOn: $hasTargetDate)
                if hasTargetDate { DatePicker("Target", selection: $targetDate, displayedComponents: .date) }
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("New Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.isEmpty) }
        }
    }

    private func save() {
        let project = Project(title: title, projectDescription: description, stage: stage, targetDate: hasTargetDate ? targetDate : nil, budget: Double(budgetText), notes: notes, roomName: roomName)
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}
