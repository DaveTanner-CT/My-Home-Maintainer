import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    @Query private var allItems: [ProjectItem]
    @Query private var allMeasurements: [ProjectMeasurement]
    @State private var showAddItem = false

    private var items: [ProjectItem] { allItems.filter { $0.project?.persistentModelID == project.persistentModelID } }
    private var measurements: [ProjectMeasurement] { allMeasurements.filter { $0.project?.persistentModelID == project.persistentModelID } }
    private var plannedTotal: Double { items.reduce(0) { $0 + $1.estimatedTotal } }
    private var purchasedTotal: Double { items.filter { $0.status == .purchased }.reduce(0) { $0 + ($1.actualPurchaseCost ?? $1.estimatedTotal) } }

    var body: some View {
        List {
            Section("Project") {
                LabeledContent("Stage", value: project.stageRaw)
                if !project.roomName.isEmpty { LabeledContent("Room", value: project.roomName) }
                if let target = project.targetDate { LabeledContent("Target", value: target.formatted(date: .abbreviated, time: .omitted)) }
                if !project.projectDescription.isEmpty { Text(project.projectDescription) }
            }

            Section("Budget") {
                if let budget = project.budget { LabeledContent("Budget", value: budget.formatted(AppFormatting.currency)) }
                LabeledContent("Planned", value: plannedTotal.formatted(AppFormatting.currency))
                LabeledContent("Purchased", value: purchasedTotal.formatted(AppFormatting.currency))
                if let budget = project.budget { LabeledContent("Remaining", value: (budget - purchasedTotal).formatted(AppFormatting.currency)) }
                NavigationLink { ProjectShoppingView(project: project) } label: {
                    Label("Open Shopping List", systemImage: "cart")
                }
            }

            if !items.isEmpty {
                ForEach(groupedCategories, id: \.self) { category in
                    Section(category) {
                        ForEach(items.filter { $0.category == category }) { item in
                            ProjectItemRow(item: item)
                        }
                    }
                }
            }

            if !measurements.isEmpty {
                Section("Measurements") {
                    ForEach(measurements) { measurement in
                        LabeledContent(measurement.name, value: "\(measurement.value.formatted()) \(measurement.unit)")
                    }
                }
            }

            if !project.notes.isEmpty { Section("Notes") { Text(project.notes) } }
        }
        .navigationTitle(project.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddItem = true } label: { Label("Add Item", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showAddItem) { NavigationStack { ProjectItemFormView(project: project) } }
    }

    private var groupedCategories: [String] {
        Array(Set(items.map(\.category))).sorted()
    }
}

private struct ProjectItemRow: View {
    let item: ProjectItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.title).font(.headline)
                Spacer()
                if item.status == .favorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                if item.status == .purchased { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            if item.isIdeaOnly {
                Text("Idea").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            } else {
                let detail = [item.manufacturer, item.finishColor, item.store].filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                if item.unitCost != nil { Text("\(item.quantity.formatted()) × \((item.unitCost ?? 0).formatted(AppFormatting.currency)) = \(item.estimatedTotal.formatted(AppFormatting.currency))").font(.caption) }
            }
            if !item.notes.isEmpty { Text(item.notes).font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 4)
    }
}
