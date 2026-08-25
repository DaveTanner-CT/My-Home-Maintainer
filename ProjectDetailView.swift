import SwiftUI
import SwiftData
import UIKit

struct ProjectDetailView: View {
    let project: Project
    @Query private var allItems: [ProjectItem]
    @Query private var allMeasurements: [ProjectMeasurement]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]
    @Query private var systems: [HomeSystem]
    @Query private var paints: [PaintFinish]
    @State private var showAddItem = false
    @State private var showAddMeasurement = false

    private var items: [ProjectItem] {
        allItems.filter { $0.project?.persistentModelID == project.persistentModelID }
    }

    private var measurements: [ProjectMeasurement] {
        allMeasurements.filter { $0.project?.persistentModelID == project.persistentModelID }
    }

    private var plannedItems: [ProjectItem] { items.filter { $0.status != .rejected } }
    private var plannedTotal: Double { plannedItems.reduce(0) { $0 + $1.estimatedTotal } }
    private var purchasedTotal: Double {
        items.filter { $0.status == .purchased || $0.status == .installed }.reduce(0) { $0 + ($1.actualPurchaseCost ?? $1.estimatedTotal) }
    }
    private var shoppingItems: [ProjectItem] { items.filter { !$0.isIdeaOnly && $0.status != .rejected } }
    private var decisionCount: Int { Set(shoppingItems.map(\.comparisonGroupName)).count }
    private var optionCount: Int { shoppingItems.filter { $0.status == .considering || $0.status == .favorite }.count }
    private var purchasedCount: Int { shoppingItems.filter { $0.status == .purchased }.count }
    private var installedCount: Int { shoppingItems.filter { $0.status == .installed }.count }
    private var linkedAppliances: [Appliance] { appliances.filter { $0.sourceProject?.persistentModelID == project.persistentModelID } }
    private var linkedFixtures: [Fixture] { fixtures.filter { $0.sourceProject?.persistentModelID == project.persistentModelID } }
    private var linkedSystems: [HomeSystem] { systems.filter { $0.sourceProject?.persistentModelID == project.persistentModelID } }
    private var linkedPaints: [PaintFinish] { paints.filter { $0.sourceProject?.persistentModelID == project.persistentModelID } }
    private var hasPermanentRecords: Bool { !linkedAppliances.isEmpty || !linkedFixtures.isEmpty || !linkedSystems.isEmpty || !linkedPaints.isEmpty }

    var body: some View {
        List {
            if let data = project.coverPhotoData, let image = UIImage(data: data) {
                Section {
                    ExpandablePhoto(image: image, height: 190, fill: true, cornerRadius: 14)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Project") {
                LabeledContent("Stage", value: project.stageRaw)
                if let room = project.room {
                    NavigationLink {
                        RoomDetailView(room: room)
                    } label: {
                        LabeledContent("Room / Area", value: room.name)
                    }
                } else if !project.roomName.isEmpty {
                    LabeledContent("Room / Area", value: project.roomName)
                }
                if let target = project.targetDate {
                    LabeledContent("Target", value: target.formatted(date: .abbreviated, time: .omitted))
                }
                if !project.projectDescription.isEmpty { Text(project.projectDescription) }
            }

            Section("Project Lifecycle") {
                lifecycleRow("1", "Plan", detail: "Capture ideas, measurements, and what the project needs.", count: items.filter { $0.isIdeaOnly }.count)
                NavigationLink { ProjectShoppingView(project: project) } label: {
                    lifecycleRow("2", "Shop & Compare", detail: "\(decisionCount) buying decision\(decisionCount == 1 ? "" : "s") · \(optionCount) active option\(optionCount == 1 ? "" : "s")", count: nil)
                }
                NavigationLink { ProjectShoppingView(project: project) } label: {
                    lifecycleRow("3", "Purchase", detail: purchasedCount == 0 ? "Choose winners and record actual purchase details." : "\(purchasedCount) purchased item\(purchasedCount == 1 ? "" : "s") waiting for installation.", count: purchasedCount)
                }
                NavigationLink { ProjectCompletionView(project: project) } label: {
                    lifecycleRow("4", "Install & Save to Home", detail: "\(installedCount) item\(installedCount == 1 ? "" : "s") preserved in the permanent home record.", count: installedCount)
                }
                HStack {
                    Image(systemName: project.stage == .completed ? "checkmark.circle.fill" : "circle").foregroundStyle(project.stage == .completed ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) { Text("5  Complete").font(.headline); Text(project.stage == .completed ? "Project is preserved in Home History." : "Close the project after purchased items have been installed or saved.").font(.caption).foregroundStyle(.secondary) }
                }
            }

            if hasPermanentRecords {
                Section("Permanent Home Records") {
                    ForEach(linkedFixtures) { item in NavigationLink { FixtureDetailView(fixture: item) } label: { Label(item.name, systemImage: "lightbulb") } }
                    ForEach(linkedAppliances) { item in NavigationLink { ApplianceDetailView(appliance: item) } label: { Label(item.name, systemImage: "refrigerator") } }
                    ForEach(linkedSystems) { item in NavigationLink { SystemDetailView(system: item) } label: { Label(item.name, systemImage: "wrench.and.screwdriver") } }
                    ForEach(linkedPaints) { item in NavigationLink { PaintDetailView(paint: item) } label: { Label("\(item.surface): \(item.colorName)", systemImage: "paintbrush") } }
                    Text("These records were installed from this project and now carry their own room, warranty, task, document, and maintenance connections.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            Section("Budget") {
                if let budget = project.budget { LabeledContent("Budget", value: budget.formatted(AppFormatting.currency)) }
                LabeledContent("Planned", value: plannedTotal.formatted(AppFormatting.currency))
                LabeledContent("Purchased", value: purchasedTotal.formatted(AppFormatting.currency))
                if let budget = project.budget {
                    LabeledContent("Remaining", value: (budget - purchasedTotal).formatted(AppFormatting.currency))
                }
            }

            if !items.isEmpty {
                ForEach(groupedCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(items.filter { $0.category == category }) { item in
                            NavigationLink {
                                ProjectItemDetailView(project: project, item: item)
                            } label: {
                                ProjectItemRow(item: item)
                            }
                        }
                    }
                }
            } else {
                Section("Design Board") {
                    Text("No ideas or products yet.").foregroundStyle(.secondary)
                    Button { showAddItem = true } label: {
                        Label("Add First Idea / Item", systemImage: "plus")
                    }
                }
            }

            Section("Measurements") {
                if measurements.isEmpty { Text("No measurements yet").foregroundStyle(.secondary) }
                ForEach(measurements) { measurement in
                    NavigationLink {
                        ProjectMeasurementDetailView(project: project, measurement: measurement)
                    } label: {
                        LabeledContent(measurement.name, value: "\(measurement.value.formatted()) \(measurement.unit)")
                    }
                }
                Button { showAddMeasurement = true } label: {
                    Label("Add Measurement", systemImage: "ruler")
                }
            }

            AttachmentSection(owner: .project(project))

            if !project.notes.isEmpty {
                Section("Notes") { Text(project.notes) }
            }
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink("Edit") { ProjectFormView(existing: project) }
                Menu {
                    Button { showAddItem = true } label: { Label("Idea / Product", systemImage: "lightbulb") }
                    Button { showAddMeasurement = true } label: { Label("Measurement", systemImage: "ruler") }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            NavigationStack { ProjectItemFormView(project: project) }
        }
        .sheet(isPresented: $showAddMeasurement) {
            NavigationStack { ProjectMeasurementFormView(project: project) }
        }
    }

    @ViewBuilder
    private func lifecycleRow(_ number: String, _ title: String, detail: String, count: Int?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.caption.bold()).frame(width: 24, height: 24).background(Color.accentColor.opacity(0.12), in: Circle()).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            if let count, count > 0 { Text("\(count)").font(.caption.bold()).foregroundStyle(.secondary) }
        }
    }

    private var groupedCategories: [String] {
        Array(Set(items.map(\.category))).sorted()
    }
}

struct ProjectItemDetailView: View {
    let project: Project
    let item: ProjectItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            if let data = item.photoData, let image = UIImage(data: data) {
                Section {
                    ExpandablePhoto(image: image, cornerRadius: 12)
                }
            }

            Section("Item") {
                LabeledContent("Category", value: item.category)
                if !item.isIdeaOnly { LabeledContent("Buying decision", value: item.comparisonGroupName) }
                LabeledContent("Status", value: item.status.rawValue)
                if item.isIdeaOnly { Text("Idea only").foregroundStyle(.secondary) }
            }

            if !item.isIdeaOnly {
                Section("Product") {
                    if !item.manufacturer.isEmpty { LabeledContent("Manufacturer", value: item.manufacturer) }
                    if !item.model.isEmpty { LabeledContent("Model", value: item.model) }
                    if !item.sku.isEmpty { LabeledContent("SKU", value: item.sku) }
                    if !item.finishColor.isEmpty { LabeledContent("Color / finish", value: item.finishColor) }
                    if !item.dimensions.isEmpty { LabeledContent("Dimensions", value: item.dimensions) }
                    if !item.store.isEmpty { LabeledContent("Store", value: item.store) }
                    if let cost = item.unitCost {
                        LabeledContent("Unit cost", value: cost.formatted(AppFormatting.currency))
                        LabeledContent("Quantity", value: item.quantity.formatted())
                        LabeledContent("Estimated total", value: item.estimatedTotal.formatted(AppFormatting.currency))
                    }
                    if let date = item.purchaseDate {
                        LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted))
                    }
                    if let actual = item.actualPurchaseCost {
                        LabeledContent("Actual cost", value: actual.formatted(AppFormatting.currency))
                    }
                    if !item.website.isEmpty,
                       let url = URL(string: item.website.hasPrefix("http") ? item.website : "https://\(item.website)") {
                        Link("Open Product Link", destination: url)
                    }
                }

                Section("Next Step") {
                    if item.status == .considering || item.status == .favorite {
                        Button { item.status = .favorite; try? modelContext.save() } label: { Label(item.status == .favorite ? "Favorite" : "Mark Favorite", systemImage: item.status == .favorite ? "star.fill" : "star") }
                        NavigationLink { ProjectPurchaseView(project: project, item: item) } label: { Label("Choose & Record Purchase", systemImage: "cart.badge.plus") }
                        Button(role: .destructive) { item.status = .rejected; try? modelContext.save() } label: { Label("Reject Option", systemImage: "xmark.circle") }
                    } else if item.status == .purchased {
                        NavigationLink { ProjectCompletionView(project: project) } label: { Label("Install / Save to My Home", systemImage: "house.and.flag") }
                        Text("Purchase recorded. The next step is to install it and preserve it as a permanent home record.").font(.footnote).foregroundStyle(.secondary)
                    } else if item.status == .installed {
                        Label("Installed / saved to the permanent home record", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        if let date = item.installedDate { LabeledContent("Installed / saved", value: date.formatted(date: .abbreviated, time: .omitted)) }
                    }
                }
            }

            AttachmentSection(owner: .projectItem(item))

            if !item.notes.isEmpty {
                Section("Notes") { Text(item.notes) }
            }
        }
        .navigationTitle(item.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") { ProjectItemFormView(project: project, existing: item) }
            }
        }
    }
}

struct ProjectMeasurementDetailView: View {
    let project: Project
    let measurement: ProjectMeasurement

    var body: some View {
        List {
            Section("Measurement") {
                LabeledContent("Value", value: "\(measurement.value.formatted()) \(measurement.unit)")
                if !measurement.notes.isEmpty { Text(measurement.notes) }
            }
        }
        .navigationTitle(measurement.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") { ProjectMeasurementFormView(project: project, existing: measurement) }
            }
        }
    }
}

struct ProjectItemRow: View {
    let item: ProjectItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    if item.status == .favorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    if item.status == .purchased { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                    if item.status == .rejected { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
                if item.isIdeaOnly {
                    Text("Idea").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                } else {
                    let detail = [item.manufacturer, item.finishColor, item.store].filter { !$0.isEmpty }.joined(separator: " · ")
                    if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                    if item.unitCost != nil {
                        Text("\(item.quantity.formatted()) × \((item.unitCost ?? 0).formatted(AppFormatting.currency)) = \(item.estimatedTotal.formatted(AppFormatting.currency))")
                            .font(.caption)
                    }
                }
                if !item.notes.isEmpty {
                    Text(item.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
