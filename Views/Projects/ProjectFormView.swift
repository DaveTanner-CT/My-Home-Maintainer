import SwiftUI
import PhotosUI
import UIKit

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let existing: Project?

    @State private var title: String
    @State private var description: String
    @State private var stage: ProjectStage
    @State private var roomName: String
    @State private var budgetText: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var notes: String
    @State private var coverPhotoData: Data?
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var showDelete = false

    init(existing: Project? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _description = State(initialValue: existing?.projectDescription ?? "")
        _stage = State(initialValue: existing?.stage ?? .idea)
        _roomName = State(initialValue: existing?.roomName ?? "")
        _budgetText = State(initialValue: existing?.budget.map { String($0) } ?? "")
        _hasTargetDate = State(initialValue: existing?.targetDate != nil)
        _targetDate = State(initialValue: existing?.targetDate ?? .now)
        _notes = State(initialValue: existing?.notes ?? "")
        _coverPhotoData = State(initialValue: existing?.coverPhotoData)
    }

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

            Section("Cover Photo") {
                if let data = coverPhotoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                PhotosPicker(selection: $selectedCoverPhoto, matching: .images) {
                    Label(coverPhotoData == nil ? "Add Cover Photo" : "Change Cover Photo", systemImage: "photo")
                }
                if coverPhotoData != nil {
                    Button("Remove Cover Photo", role: .destructive) { coverPhotoData = nil }
                }
            }

            Section("Planning") {
                TextField("Budget", text: $budgetText).keyboardType(.decimalPad)
                Toggle("Target date", isOn: $hasTargetDate)
                if hasTargetDate {
                    DatePicker("Target", selection: $targetDate, displayedComponents: .date)
                }
                TextField("Notes", text: $notes, axis: .vertical)
            }

            if existing != nil {
                Section {
                    Button("Delete Project", role: .destructive) { showDelete = true }
                }
            }
        }
        .navigationTitle(existing == nil ? "New Project" : "Edit Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onChange(of: selectedCoverPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                coverPhotoData = try? await newValue.loadTransferable(type: Data.self)
                selectedCoverPhoto = nil
            }
        }
        .confirmationDialog("Delete this project?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Project", role: .destructive) {
                if let existing {
                    modelContext.delete(existing)
                    try? modelContext.save()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Project items linked to this project may also become unavailable.")
        }
    }

    private func save() {
        let project = existing ?? Project(title: title)
        if existing == nil { modelContext.insert(project) }
        project.title = title
        project.projectDescription = description
        project.stage = stage
        project.roomName = roomName
        project.budget = Double(budgetText)
        project.targetDate = hasTargetDate ? targetDate : nil
        project.notes = notes
        project.coverPhotoData = coverPhotoData
        try? modelContext.save()
        dismiss()
    }
}
