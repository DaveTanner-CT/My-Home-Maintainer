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
    @Query private var history: [MaintenanceRecord]
    @State private var completedMessage = false

    private var projectItems: [ProjectItem] {
        allItems.filter { $0.project?.persistentModelID == project.persistentModelID && !$0.isIdeaOnly }
    }
    private var purchased: [ProjectItem] { projectItems.filter { $0.status == .purchased } }
    private var installed: [ProjectItem] { projectItems.filter { $0.status == .installed } }
    private var canCloseProject: Bool { purchased.isEmpty }

    var body: some View {
        List {
            Section("Step 4 · Install / Save to Home") {
                Text("A purchase is not the end of the workflow. Save installed products into the permanent home record so the room, warranty, tasks, documents, project source, and future maintenance remain connected.")
                    .font(.footnote).foregroundStyle(.secondary)
                if purchased.isEmpty { Label("No purchased items waiting to be installed", systemImage: "checkmark.circle").foregroundStyle(.secondary) }
            }

            Section("Purchased — Ready to Install") {
                if purchased.isEmpty { Text("Nothing waiting for installation or handoff.").foregroundStyle(.secondary) }
                ForEach(purchased) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.headline)
                                Text(item.comparisonGroupName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let date = item.purchaseDate { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
                        }
                        Menu {
                            Button { addAppliance(item) } label: { Label("Device / Equipment", systemImage: "refrigerator") }
                            Button { addFixture(item) } label: { Label("Fixture", systemImage: "lightbulb") }
                            Button { addSystem(item) } label: { Label("Home System", systemImage: "wrench.and.screwdriver") }
                            Button { addPaint(item) } label: { Label("Paint / Finish", systemImage: "paintbrush") }
                            Button { addHistoryOnly(item) } label: { Label("History Only", systemImage: "clock.arrow.circlepath") }
                        } label: { Label("Install / Save to My Home", systemImage: "square.and.arrow.down") }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !installed.isEmpty {
                Section("Installed / Saved") {
                    ForEach(installed) { item in installedItemLink(item) }
                    Text("Open a saved home record to add serial numbers, warranty expiration, registration links, documents, or ongoing maintenance tasks.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Close Project") {
                if project.stage == .completed {
                    Label("Project completed and preserved in Home History", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                } else {
                    Button { closeProject() } label: { Label("Mark Project Completed", systemImage: "checkmark.seal") }
                        .disabled(!canCloseProject)
                    if !canCloseProject {
                        Text("Install or save the \(purchased.count) purchased item\(purchased.count == 1 ? "" : "s") above before closing the project. This prevents researched purchases from becoming disconnected from the permanent home record.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Install & Finish")
        .alert("Project Completed", isPresented: $completedMessage) { Button("OK", role: .cancel) {} } message: { Text("The project is now part of Home History, and installed items remain linked back to this project.") }
    }

    @ViewBuilder
    private func installedItemLink(_ item: ProjectItem) -> some View {
        if let fixture = fixtures.first(where: { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.name.caseInsensitiveCompare(item.title) == .orderedSame }) {
            NavigationLink { FixtureDetailView(fixture: fixture) } label: { installedRow(item) }
        } else if let appliance = appliances.first(where: { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.name.caseInsensitiveCompare(item.title) == .orderedSame }) {
            NavigationLink { ApplianceDetailView(appliance: appliance) } label: { installedRow(item) }
        } else if let system = systems.first(where: { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.name.caseInsensitiveCompare(item.title) == .orderedSame }) {
            NavigationLink { SystemDetailView(system: system) } label: { installedRow(item) }
        } else if let paint = paints.first(where: { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.colorName.caseInsensitiveCompare(item.title) == .orderedSame }) {
            NavigationLink { PaintDetailView(paint: paint) } label: { installedRow(item) }
        } else {
            installedRow(item)
        }
    }

    @ViewBuilder
    private func installedRow(_ item: ProjectItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                Text(item.comparisonGroupName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let date = item.installedDate { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }

    private func alreadySaved(_ item: ProjectItem) -> Bool {
        appliances.contains { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.name.caseInsensitiveCompare(item.title) == .orderedSame }
            || fixtures.contains { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.name.caseInsensitiveCompare(item.title) == .orderedSame }
            || systems.contains { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.name.caseInsensitiveCompare(item.title) == .orderedSame }
            || paints.contains { $0.sourceProject?.persistentModelID == project.persistentModelID && $0.colorName.caseInsensitiveCompare(item.title) == .orderedSame }
    }

    private func addAppliance(_ item: ProjectItem) {
        guard !alreadySaved(item) else { markInstalled(item); return }
        let record = Appliance(name: item.title, category: item.category, manufacturer: item.manufacturer, model: item.model, purchaseDate: item.purchaseDate, purchasePrice: item.actualPurchaseCost ?? item.unitCost, purchasedFrom: item.store, manufacturerWebsite: item.website, notes: item.notes, room: project.room, sourceProject: project)
        modelContext.insert(record)
        copyPhoto(item, to: .appliance(record))
        addInstallHistory(item, appliance: record)
        markInstalled(item)
    }

    private func addFixture(_ item: ProjectItem) {
        guard !alreadySaved(item) else { markInstalled(item); return }
        let record = Fixture(name: item.title, category: item.category, manufacturer: item.manufacturer, model: item.model, partNumber: item.sku, finishColor: item.finishColor, installationDate: .now, purchaseDate: item.purchaseDate, purchasePrice: item.actualPurchaseCost ?? item.unitCost, purchasedFrom: item.store, productLink: item.website, notes: item.notes, room: project.room, sourceProject: project)
        modelContext.insert(record)
        copyPhoto(item, to: .fixture(record))
        addInstallHistory(item, fixture: record)
        markInstalled(item)
    }

    private func addSystem(_ item: ProjectItem) {
        guard !alreadySaved(item) else { markInstalled(item); return }
        let record = HomeSystem(name: item.title, type: item.category, manufacturer: item.manufacturer, model: item.model, installationDate: .now, purchaseCost: item.actualPurchaseCost ?? item.unitCost, location: project.locationName, notes: item.notes, website: item.website, room: project.room, sourceProject: project)
        modelContext.insert(record)
        copyPhoto(item, to: .system(record))
        addInstallHistory(item, system: record)
        markInstalled(item)
    }

    private func addPaint(_ item: ProjectItem) {
        guard !alreadySaved(item) else { markInstalled(item); return }
        let record = PaintFinish(roomName: project.locationName, room: project.room, surface: item.category, brand: item.manufacturer, productLine: item.model, colorName: item.title, colorCode: item.sku, sheen: item.finishColor, store: item.store, purchaseDate: item.purchaseDate, quantity: item.quantity, cost: item.actualPurchaseCost ?? item.unitCost, notes: item.notes, productLink: item.website, sourceProject: project)
        modelContext.insert(record)
        copyPhoto(item, to: .paint(record))
        addInstallHistory(item)
        markInstalled(item)
    }

    private func addHistoryOnly(_ item: ProjectItem) {
        addInstallHistory(item)
        markInstalled(item)
    }

    private func addInstallHistory(_ item: ProjectItem, appliance: Appliance? = nil, fixture: Fixture? = nil, system: HomeSystem? = nil) {
        let record = MaintenanceRecord(
            date: .now,
            title: "Installed \(item.title)",
            cost: item.actualPurchaseCost ?? item.estimatedTotal,
            notes: item.notes,
            vendorName: item.store,
            taskTitle: project.title,
            relatedItemName: item.title,
            eventType: .installation,
            room: project.room,
            system: system,
            appliance: appliance,
            fixture: fixture,
            project: project
        )
        modelContext.insert(record)
        copyPhoto(item, to: .maintenanceRecord(record))
    }

    private func markInstalled(_ item: ProjectItem) {
        item.status = .installed
        item.installedDate = .now
        if project.stage == .shopping || project.stage == .planning || project.stage == .scheduled { project.stage = .inProgress }
        save()
    }

    private func closeProject() {
        guard canCloseProject else { return }
        project.stage = .completed
        let exists = history.contains { $0.project?.persistentModelID == project.persistentModelID && $0.eventType == .project && $0.title.caseInsensitiveCompare("Completed \(project.title)") == .orderedSame }
        if !exists {
            let record = MaintenanceRecord(date: .now, title: "Completed \(project.title)", cost: installed.reduce(0) { $0 + ($1.actualPurchaseCost ?? $1.estimatedTotal) }, notes: project.notes, taskTitle: project.title, relatedItemName: project.title, eventType: .project, room: project.room, project: project)
            modelContext.insert(record)
        }
        save()
        completedMessage = true
    }

    private func copyPhoto(_ item: ProjectItem, to owner: AttachmentOwnerReference) {
        guard let data = item.photoData else { return }
        let attachment = HomeAttachment(name: item.title, caption: "From project: \(project.title)", category: "Photo", fileName: "\(item.title.replacingOccurrences(of: " ", with: "-"))-project-photo.jpg", typeIdentifier: "image/jpeg", fileData: data)
        owner.assign(to: attachment)
        modelContext.insert(attachment)
    }

    private func save() { try? modelContext.save() }
}
