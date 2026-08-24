import SwiftUI
import SwiftData
import UIKit

struct ProjectDetailView: View {
    let project: Project
    @Query private var allItems: [ProjectItem]
    @Query private var allMeasurements: [ProjectMeasurement]
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
        items.filter { $0.status == .purchased }.reduce(0) { $0 + ($1.actualPurchaseCost ?? $1.estimatedTotal) }
    }

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
                if !project.locationName.isEmpty { LabeledContent("Room / Area", value: project.locationName) }
                if let target = project.targetDate {
                    LabeledContent("Target", value: target.formatted(date: .abbreviated, time: .omitted))
                }
                if !project.projectDescription.isEmpty { Text(project.projectDescription) }
            }

            Section("Budget") {
                if let budget = project.budget { LabeledContent("Budget", value: budget.formatted(AppFormatting.currency)) }
                LabeledContent("Planned", value: plannedTotal.formatted(AppFormatting.currency))
                LabeledContent("Purchased", value: purchasedTotal.formatted(AppFormatting.currency))
                if let budget = project.budget {
                    LabeledContent("Remaining", value: (budget - purchasedTotal).formatted(AppFormatting.currency))
                }
                NavigationLink {
                    ProjectShoppingView(project: project)
                } label: {
                    Label("Shopping Mode", systemImage: "cart")
                }
                NavigationLink {
                    ProjectComparisonView(project: project)
                } label: {
                    Label("Compare Options", systemImage: "rectangle.split.3x1")
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

                Section("Quick Status") {
                    Button {
                        item.status = .favorite
                        try? modelContext.save()
                    } label: {
                        Label("Mark Favorite", systemImage: "star")
                    }
                    Button {
                        item.status = .purchased
                        if item.purchaseDate == nil { item.purchaseDate = .now }
                        try? modelContext.save()
                    } label: {
                        Label("Mark Purchased", systemImage: "checkmark.circle")
                    }
                    Button(role: .destructive) {
                        item.status = .rejected
                        try? modelContext.save()
                    } label: {
                        Label("Reject Option", systemImage: "xmark.circle")
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
