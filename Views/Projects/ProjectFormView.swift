import SwiftUI

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let existing: Project?
    @State private var title: String; @State private var description: String; @State private var stage: ProjectStage; @State private var roomName: String
    @State private var budgetText: String; @State private var hasTargetDate: Bool; @State private var targetDate: Date; @State private var notes: String; @State private var showDelete = false

    init(existing: Project? = nil) {
        self.existing = existing; _title = State(initialValue: existing?.title ?? ""); _description = State(initialValue: existing?.projectDescription ?? ""); _stage = State(initialValue: existing?.stage ?? .idea); _roomName = State(initialValue: existing?.roomName ?? "")
        _budgetText = State(initialValue: existing?.budget.map { String($0) } ?? ""); _hasTargetDate = State(initialValue: existing?.targetDate != nil); _targetDate = State(initialValue: existing?.targetDate ?? .now); _notes = State(initialValue: existing?.notes ?? "")
    }
    var body: some View {
        Form {
            Section("Project") { TextField("Project name", text: $title); TextField("Description", text: $description, axis: .vertical); Picker("Stage", selection: $stage) { ForEach(ProjectStage.allCases) { Text($0.rawValue).tag($0) } }; TextField("Room / area", text: $roomName) }
            Section("Planning") { TextField("Budget", text: $budgetText).keyboardType(.decimalPad); Toggle("Target date", isOn: $hasTargetDate); if hasTargetDate { DatePicker("Target", selection: $targetDate, displayedComponents: .date) }; TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Project", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "New Project" : "Edit Project").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        .confirmationDialog("Delete this project?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete Project", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } } message: { Text("Project items linked to this project may also become unavailable.") }
    }
    private func save() { let p = existing ?? Project(title: title); if existing == nil { modelContext.insert(p) }; p.title = title; p.projectDescription = description; p.stage = stage; p.roomName = roomName; p.budget = Double(budgetText); p.targetDate = hasTargetDate ? targetDate : nil; p.notes = notes; try? modelContext.save(); dismiss() }
}
