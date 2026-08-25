import SwiftUI
import SwiftData

struct ProjectCompletionView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ProjectItem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]
    @Query private var systems: [HomeSystem]
    @Query private var paints: [PaintFinish]
    @State private var completedMessage = false

    private var purchased: [ProjectItem] {
        allItems.filter { $0.project?.persistentModelID == project.persistentModelID && ($0.status == .purchased || $0.status == .installed) && !$0.isIdeaOnly }
    }

    var body: some View {
        List {
            Section("Project Completion") {
                if project.stage != .completed {
                    Button { project.stage = .completed; save(); completedMessage = true } label: { Label("Mark Project Completed", systemImage: "checkmark.circle") }
                } else {
                    Label("Project marked completed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
                Text("Purchased project items can be promoted into permanent home records so the information you researched becomes part of the room, equipment, fixture, system, or paint history.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Purchased / Installed Items") {
                if purchased.isEmpty { Text("No purchased project items are ready to install or save.").foregroundStyle(.secondary) }
                ForEach(purchased) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { VStack(alignment: .leading) { Text(item.title).font(.headline); Text(item.category).font(.caption).foregroundStyle(.secondary) }; Spacer(); if alreadySaved(item) { Label("Saved", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) } }
                        Menu {
                            Button { addAppliance(item) } label: { Label("Appliance / Electronics / Equipment", systemImage: "refrigerator") }
                            Button { addFixture(item) } label: { Label("Fixture", systemImage: "lightbulb") }
                            Button { addSystem(item) } label: { Label("Home System", systemImage: "wrench.and.screwdriver") }
                            Button { addPaint(item) } label: { Label("Paint / Finish", systemImage: "paintbrush") }
                            Button { addHistory(item) } label: { Label("Maintenance / Home History Record", systemImage: "clock.arrow.circlepath") }
                        } label: { Label("Save to My Home", systemImage: "square.and.arrow.down") }
                        .disabled(alreadySaved(item) || item.status == .installed)
                    }.padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Finish Project")
        .alert("Project Completed", isPresented: $completedMessage) { Button("OK", role: .cancel) {} }
    }

    private func alreadySaved(_ item: ProjectItem) -> Bool {
        let roomID = project.room?.persistentModelID
        return appliances.contains { $0.name.caseInsensitiveCompare(item.title) == .orderedSame && $0.room?.persistentModelID == roomID }
            || fixtures.contains { $0.name.caseInsensitiveCompare(item.title) == .orderedSame && $0.room?.persistentModelID == roomID }
            || systems.contains { $0.name.caseInsensitiveCompare(item.title) == .orderedSame && $0.room?.persistentModelID == roomID }
            || paints.contains { $0.colorName.caseInsensitiveCompare(item.title) == .orderedSame && $0.room?.persistentModelID == roomID }
    }

    private func addAppliance(_ item: ProjectItem) {
        let record = Appliance(name: item.title, category: item.category, manufacturer: item.manufacturer, model: item.model, purchaseDate: item.purchaseDate, purchasePrice: item.actualPurchaseCost ?? item.unitCost, purchasedFrom: item.store, manufacturerWebsite: item.website, notes: item.notes, room: project.room)
        modelContext.insert(record); copyPhoto(item, to: .appliance(record)); item.status = .installed; save()
    }
    private func addFixture(_ item: ProjectItem) {
        let record = Fixture(name: item.title, category: item.category, manufacturer: item.manufacturer, model: item.model, partNumber: item.sku, finishColor: item.finishColor, installationDate: project.stage == .completed ? .now : nil, purchaseDate: item.purchaseDate, purchasePrice: item.actualPurchaseCost ?? item.unitCost, purchasedFrom: item.store, productLink: item.website, notes: item.notes, room: project.room)
        modelContext.insert(record); copyPhoto(item, to: .fixture(record)); item.status = .installed; save()
    }
    private func addSystem(_ item: ProjectItem) {
        let record = HomeSystem(name: item.title, type: item.category, manufacturer: item.manufacturer, model: item.model, installationDate: project.stage == .completed ? .now : nil, purchaseCost: item.actualPurchaseCost ?? item.unitCost, location: project.locationName, notes: item.notes, website: item.website, room: project.room)
        modelContext.insert(record); copyPhoto(item, to: .system(record)); item.status = .installed; save()
    }
    private func addPaint(_ item: ProjectItem) {
        let record = PaintFinish(roomName: project.locationName, room: project.room, surface: item.category, brand: item.manufacturer, productLine: item.model, colorName: item.title, colorCode: item.sku, sheen: item.finishColor, store: item.store, purchaseDate: item.purchaseDate, quantity: item.quantity, cost: item.actualPurchaseCost ?? item.unitCost, notes: item.notes, productLink: item.website)
        modelContext.insert(record); copyPhoto(item, to: .paint(record)); item.status = .installed; save()
    }
    private func addHistory(_ item: ProjectItem) {
        let record = MaintenanceRecord(date: item.purchaseDate ?? .now, title: "\(project.title): \(item.title)", cost: item.actualPurchaseCost ?? item.estimatedTotal, notes: item.notes, taskTitle: project.title, relatedItemName: item.title)
        modelContext.insert(record); copyPhoto(item, to: .maintenanceRecord(record)); item.status = .installed; save()
    }
    private func copyPhoto(_ item: ProjectItem, to owner: AttachmentOwnerReference) {
        guard let data = item.photoData else { return }
        let attachment = HomeAttachment(name: item.title, caption: "From project: \(project.title)", category: "Photo", fileName: "\(item.title.replacingOccurrences(of: " ", with: "-"))-project-photo.jpg", typeIdentifier: "image/jpeg", fileData: data)
        owner.assign(to: attachment); modelContext.insert(attachment)
    }
    private func save() { try? modelContext.save() }
}
