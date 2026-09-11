import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    let existing: Project?

    @State private var title: String
    @State private var description: String
    @State private var stage: ProjectStage
    @State private var selectedRoom: Room?
    @State private var selectedRooms: [Room]
    @State private var budgetText: String
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var notes: String
    @State private var coverPhotoData: Data?
    @State private var selectedCoverPhoto: PhotosPickerItem?
    @State private var showDelete = false
    @State private var deleteError: String?
    @State private var didResolveLegacyRoom = false

    init(existing: Project? = nil, initialRoom: Room? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _description = State(initialValue: existing?.projectDescription ?? "")
        _stage = State(initialValue: existing?.stage ?? .idea)
        _selectedRoom = State(initialValue: existing?.room ?? initialRoom)
        _selectedRooms = State(initialValue: existing?.linkedRooms ?? [initialRoom].compactMap { $0 })
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
            }

            MultiRoomSelectionSection(rooms: rooms, primaryRoom: $selectedRoom, selectedRooms: $selectedRooms, title: "Rooms / Areas")

            Section("Cover Photo") {
                if let data = coverPhotoData, let image = UIImage(data: data) {
                    ExpandablePhoto(image: image, height: 220, fill: false, cornerRadius: 12)
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
        .onAppear {
            // Older projects stored only a room-name string. Resolve that legacy value
            // to the real Room record the first time the edit form opens.
            guard !didResolveLegacyRoom else { return }
            didResolveLegacyRoom = true
            if selectedRoom == nil, let legacyName = existing?.roomName, !legacyName.isEmpty {
                selectedRoom = rooms.first { $0.name.caseInsensitiveCompare(legacyName) == .orderedSame }
                if let selectedRoom, !selectedRooms.contains(where: { $0.persistentModelID == selectedRoom.persistentModelID }) { selectedRooms.append(selectedRoom) }
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
            Button("Delete Project", role: .destructive) { deleteProject() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Project planning items, measurements, and project-only attachments will be deleted. Tasks, home records, and Home History entries will be kept and unlinked from the project.")
        }
        .alert("Could Not Delete Project", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: { Text(deleteError ?? "The project could not be deleted.") }
    }

    private func deleteProject() {
        guard let existing else { return }
        let projectID = existing.persistentModelID

        if let tasks = try? modelContext.fetch(FetchDescriptor<MaintenanceTask>()) {
            for task in tasks where task.project?.persistentModelID == projectID { task.project = nil }
        }
        if let systems = try? modelContext.fetch(FetchDescriptor<HomeSystem>()) {
            for system in systems where system.sourceProject?.persistentModelID == projectID { system.sourceProject = nil }
        }
        if let appliances = try? modelContext.fetch(FetchDescriptor<Appliance>()) {
            for appliance in appliances where appliance.sourceProject?.persistentModelID == projectID { appliance.sourceProject = nil }
        }
        if let fixtures = try? modelContext.fetch(FetchDescriptor<Fixture>()) {
            for fixture in fixtures where fixture.sourceProject?.persistentModelID == projectID { fixture.sourceProject = nil }
        }
        if let paints = try? modelContext.fetch(FetchDescriptor<PaintFinish>()) {
            for paint in paints where paint.sourceProject?.persistentModelID == projectID { paint.sourceProject = nil }
        }
        if let history = try? modelContext.fetch(FetchDescriptor<MaintenanceRecord>()) {
            for record in history where record.project?.persistentModelID == projectID { record.project = nil }
        }

        let projectItems = (try? modelContext.fetch(FetchDescriptor<ProjectItem>()))?.filter { $0.project?.persistentModelID == projectID } ?? []
        let itemIDs = Set(projectItems.map { $0.persistentModelID })
        if let attachments = try? modelContext.fetch(FetchDescriptor<HomeAttachment>()) {
            for attachment in attachments {
                let belongsToProject = attachment.project?.persistentModelID == projectID
                let belongsToProjectItem = attachment.projectItem.map { itemIDs.contains($0.persistentModelID) } ?? false
                if belongsToProject || belongsToProjectItem { modelContext.delete(attachment) }
            }
        }
        for item in projectItems { modelContext.delete(item) }
        if let measurements = try? modelContext.fetch(FetchDescriptor<ProjectMeasurement>()) {
            for measurement in measurements where measurement.project?.persistentModelID == projectID { modelContext.delete(measurement) }
        }

        modelContext.delete(existing)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func save() {
        let project = existing ?? Project(title: title)
        if existing == nil { modelContext.insert(project) }
        project.title = title
        project.projectDescription = description
        project.stage = stage
        project.setPrimaryRoom(selectedRoom)
        project.additionalRooms = selectedRooms.filter { $0.persistentModelID != selectedRoom?.persistentModelID }
        project.roomName = selectedRoom?.name ?? selectedRooms.first?.name ?? ""
        project.budget = Double(budgetText)
        project.targetDate = hasTargetDate ? targetDate : nil
        project.notes = notes
        project.coverPhotoData = coverPhotoData
        try? modelContext.save()
        dismiss()
    }
}
