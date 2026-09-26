import SwiftUI
import SwiftData

/// A lightweight way to preserve small, already-completed home projects without
/// forcing the user through the full plan -> shop -> purchase -> install workflow.
struct ProjectQuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query private var history: [MaintenanceRecord]
    @Query private var allItems: [ProjectItem]

    let existingProject: Project?

    @State private var title: String
    @State private var selectedRoom: Room?
    @State private var completedDate: Date
    @State private var outcome: String
    @State private var materialName: String
    @State private var brand: String
    @State private var costText: String
    @State private var store: String
    @State private var didItYourself: Bool
    @State private var completedBy: String
    @State private var notes: String
    @State private var didLoadExistingRecord = false

    init(existingProject: Project? = nil) {
        self.existingProject = existingProject
        _title = State(initialValue: existingProject?.title ?? "")
        _selectedRoom = State(initialValue: existingProject?.room)
        _completedDate = State(initialValue: .now)
        _outcome = State(initialValue: "")
        _materialName = State(initialValue: "")
        _brand = State(initialValue: "")
        _costText = State(initialValue: "")
        _store = State(initialValue: "")
        _didItYourself = State(initialValue: true)
        _completedBy = State(initialValue: "")
        _notes = State(initialValue: "")
    }

    var body: some View {
        Form {
            Section("Project") {
                if existingProject == nil {
                    TextField("Project name", text: $title)
                } else {
                    LabeledContent("Project", value: title)
                }

                Picker("Room / Area", selection: $selectedRoom) {
                    Text("Not specified").tag(nil as Room?)
                    ForEach(rooms) { room in
                        Text(room.name).tag(room as Room?)
                    }
                }

                DatePicker("Completed", selection: $completedDate, displayedComponents: .date)
            }

            Section("Outcome") {
                TextField("What did you do?", text: $outcome, axis: .vertical)
                    .lineLimit(2...5)
                Text("Example: Removed the old caulk and recaulked the bathtub.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Materials / Product") {
                TextField("Material or product used", text: $materialName)
                TextField("Brand", text: $brand)
                TextField("Cost", text: $costText)
                    .keyboardType(.decimalPad)
                TextField("Purchased from", text: $store)
                Text("For a small project, one product is enough here. You can still use the full project workflow when you need to track several items.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Work") {
                Toggle("I did this myself", isOn: $didItYourself)
                if !didItYourself {
                    TextField("Who completed the work?", text: $completedBy)
                }
            }

            Section("Notes") {
                TextField("Anything else worth remembering", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .navigationTitle(existingProject == nil ? "Quick Project Record" : "Record Project Outcome")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear(perform: loadExistingRecordIfNeeded)
    }

    private var parsedCost: Double? {
        let cleaned = costText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    private var completionRecord: MaintenanceRecord? {
        guard let project = existingProject else { return nil }
        return history.first {
            $0.project?.persistentModelID == project.persistentModelID &&
            $0.eventType == .project &&
            $0.title.caseInsensitiveCompare("Completed \(project.title)") == .orderedSame
        }
    }

    private var quickMaterialItem: ProjectItem? {
        guard let project = existingProject else { return nil }
        return allItems.first {
            $0.project?.persistentModelID == project.persistentModelID &&
            $0.category == "Materials" &&
            $0.comparisonGroup == "Quick Project Record"
        }
    }

    private func loadExistingRecordIfNeeded() {
        guard !didLoadExistingRecord else { return }
        didLoadExistingRecord = true
        guard let project = existingProject else { return }

        selectedRoom = project.room

        if let record = completionRecord {
            completedDate = record.date
            costText = record.cost.map { String(format: "%.2f", $0) } ?? ""
            didItYourself = record.vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            completedBy = didItYourself ? "" : record.vendorName
            parseCompletionNotes(record.notes)
        }

        if let item = quickMaterialItem {
            materialName = item.title
            brand = item.manufacturer
            store = item.store
            if costText.isEmpty {
                costText = (item.actualPurchaseCost ?? item.unitCost).map { String(format: "%.2f", $0) } ?? ""
            }
        }
    }

    private func parseCompletionNotes(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        var freeNotes: [String] = []
        var readingNotes = false

        for line in lines {
            if line.hasPrefix("Outcome: ") {
                outcome = String(line.dropFirst("Outcome: ".count))
            } else if line.hasPrefix("Material / product: ") {
                materialName = String(line.dropFirst("Material / product: ".count))
            } else if line.hasPrefix("Brand: ") {
                brand = String(line.dropFirst("Brand: ".count))
            } else if line.hasPrefix("Purchased from: ") {
                store = String(line.dropFirst("Purchased from: ".count))
            } else if line.hasPrefix("Completed by: ") {
                let value = String(line.dropFirst("Completed by: ".count))
                didItYourself = value == "Homeowner / DIY"
                completedBy = didItYourself ? "" : value
            } else if line == "Notes:" {
                readingNotes = true
            } else if readingNotes {
                freeNotes.append(line)
            }
        }

        notes = freeNotes.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if outcome.isEmpty && !text.isEmpty && !text.contains("Outcome: ") {
            notes = text
        }
    }

    private func formattedHistoryNotes() -> String {
        var lines: [String] = []
        lines.append("Outcome: \(outcome.trimmingCharacters(in: .whitespacesAndNewlines))")

        let material = materialName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !material.isEmpty { lines.append("Material / product: \(material)") }

        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBrand.isEmpty { lines.append("Brand: \(trimmedBrand)") }

        let trimmedStore = store.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStore.isEmpty { lines.append("Purchased from: \(trimmedStore)") }

        if didItYourself {
            lines.append("Completed by: Homeowner / DIY")
        } else {
            let worker = completedBy.trimmingCharacters(in: .whitespacesAndNewlines)
            if !worker.isEmpty { lines.append("Completed by: \(worker)") }
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            lines.append("Notes:")
            lines.append(trimmedNotes)
        }

        return lines.joined(separator: "\n")
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanOutcome.isEmpty else { return }

        let project: Project
        if let existingProject {
            project = existingProject
            project.setPrimaryRoom(selectedRoom)
        } else {
            project = Project(
                title: cleanTitle,
                projectDescription: cleanOutcome,
                stage: .completed,
                targetDate: nil,
                budget: nil,
                notes: "",
                roomName: selectedRoom?.name ?? "",
                room: selectedRoom
            )
            modelContext.insert(project)
        }

        project.stage = .completed
        if project.projectDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            project.projectDescription = cleanOutcome
        }

        let cleanMaterial = materialName.trimmingCharacters(in: .whitespacesAndNewlines)
        let materialItem = allItems.first {
            $0.project?.persistentModelID == project.persistentModelID &&
            $0.category == "Materials" &&
            $0.comparisonGroup == "Quick Project Record"
        }

        if !cleanMaterial.isEmpty {
            let item = materialItem ?? ProjectItem(
                project: project,
                title: cleanMaterial,
                category: "Materials",
                comparisonGroup: "Quick Project Record",
                manufacturer: brand.trimmingCharacters(in: .whitespacesAndNewlines),
                store: store.trimmingCharacters(in: .whitespacesAndNewlines),
                unitCost: parsedCost,
                quantity: 1,
                actualPurchaseCost: parsedCost,
                purchaseDate: completedDate,
                installedDate: completedDate,
                notes: "Used for \(project.title)",
                status: .installed
            )

            item.title = cleanMaterial
            item.manufacturer = brand.trimmingCharacters(in: .whitespacesAndNewlines)
            item.store = store.trimmingCharacters(in: .whitespacesAndNewlines)
            item.unitCost = parsedCost
            item.quantity = 1
            item.actualPurchaseCost = parsedCost
            item.purchaseDate = completedDate
            item.installedDate = completedDate
            item.status = .installed
            item.isIdeaOnly = false
            if materialItem == nil { modelContext.insert(item) }
        } else if let materialItem {
            modelContext.delete(materialItem)
        }

        let existingRecord = history.first {
            $0.project?.persistentModelID == project.persistentModelID &&
            $0.eventType == .project &&
            $0.title.caseInsensitiveCompare("Completed \(project.title)") == .orderedSame
        }
        let record: MaintenanceRecord
        if let existingRecord {
            record = existingRecord
        } else {
            record = MaintenanceRecord(
                date: completedDate,
                title: "Completed \(project.title)",
                cost: parsedCost,
                notes: formattedHistoryNotes(),
                vendorName: didItYourself ? "" : completedBy.trimmingCharacters(in: .whitespacesAndNewlines),
                taskTitle: project.title,
                relatedItemName: cleanMaterial.isEmpty ? project.title : cleanMaterial,
                eventType: .project,
                room: selectedRoom,
                project: project
            )
            modelContext.insert(record)
        }

        record.date = completedDate
        record.title = "Completed \(project.title)"
        record.cost = parsedCost
        record.notes = formattedHistoryNotes()
        record.vendorName = didItYourself ? "" : completedBy.trimmingCharacters(in: .whitespacesAndNewlines)
        record.taskTitle = project.title
        record.relatedItemName = cleanMaterial.isEmpty ? project.title : cleanMaterial
        record.eventType = .project
        record.room = selectedRoom
        record.project = project

        try? modelContext.save()
        dismiss()
    }
}
