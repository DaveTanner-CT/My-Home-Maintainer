import SwiftUI
import SwiftData

struct ProjectShoppingView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ProjectItem]

    @State private var statusFilter = "Need to Buy"
    @State private var grouping = "Store"

    private let statusOptions = ["Need to Buy", "All", "Considering", "Favorite", "Purchased"]
    private let groupingOptions = ["Store", "Category"]

    private var projectItems: [ProjectItem] {
        allItems.filter {
            $0.project?.persistentModelID == project.persistentModelID &&
            !$0.isIdeaOnly
        }
    }

    private var items: [ProjectItem] {
        projectItems.filter { item in
            switch statusFilter {
            case "Need to Buy": return item.status == .considering || item.status == .favorite
            case "Considering": return item.status == .considering
            case "Favorite": return item.status == .favorite
            case "Purchased": return item.status == .purchased
            default: return item.status != .rejected
            }
        }
    }

    private var groups: [String] {
        Array(Set(items.map { groupName(for: $0) })).sorted()
    }

    var body: some View {
        List {
            Section("Shopping View") {
                Picker("Show", selection: $statusFilter) {
                    ForEach(statusOptions, id: \.self) { Text($0).tag($0) }
                }
                Picker("Group by", selection: $grouping) {
                    ForEach(groupingOptions, id: \.self) { Text($0).tag($0) }
                }
            }

            if items.isEmpty {
                ContentUnavailableView("No matching shopping items", systemImage: "cart", description: Text("Change the filter or add product items to this project."))
            } else {
                ForEach(groups, id: \.self) { group in
                    Section(group) {
                        ForEach(items.filter { groupName(for: $0) == group }) { item in
                            NavigationLink {
                                ProjectItemDetailView(project: project, item: item)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: statusIcon(for: item))
                                        .foregroundStyle(statusColor(for: item))
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title).font(.headline)
                                        Text("Qty \(item.quantity.formatted()) · \(item.estimatedTotal.formatted(AppFormatting.currency))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !item.store.isEmpty && grouping != "Store" { Text(item.store).font(.caption) }
                                        if !item.finishColor.isEmpty { Text(item.finishColor).font(.caption) }
                                        if !item.sku.isEmpty { Text("SKU: \(item.sku)").font(.caption2).foregroundStyle(.secondary) }
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    item.status = .purchased
                                    if item.purchaseDate == nil { item.purchaseDate = .now }
                                    try? modelContext.save()
                                } label: {
                                    Label("Purchased", systemImage: "checkmark")
                                }
                                .tint(.green)

                                Button {
                                    item.status = .favorite
                                    try? modelContext.save()
                                } label: {
                                    Label("Favorite", systemImage: "star")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    item.status = .rejected
                                    try? modelContext.save()
                                } label: {
                                    Label("Reject", systemImage: "xmark")
                                }
                            }
                        }
                    }
                }
            }

            Section("Project Spending") {
                LabeledContent("Planned", value: plannedTotal.formatted(AppFormatting.currency))
                LabeledContent("Purchased", value: purchasedTotal.formatted(AppFormatting.currency))
                if let budget = project.budget {
                    LabeledContent("Budget remaining", value: (budget - purchasedTotal).formatted(AppFormatting.currency))
                }
            }
        }
        .navigationTitle("Shopping Mode")
    }

    private var plannedTotal: Double {
        projectItems.filter { $0.status != .rejected }.reduce(0) { $0 + $1.estimatedTotal }
    }

    private var purchasedTotal: Double {
        projectItems.filter { $0.status == .purchased }.reduce(0) { $0 + ($1.actualPurchaseCost ?? $1.estimatedTotal) }
    }

    private func groupName(for item: ProjectItem) -> String {
        if grouping == "Category" { return item.category.isEmpty ? "Uncategorized" : item.category }
        return item.store.isEmpty ? "Store Not Set" : item.store
    }

    private func statusColor(for item: ProjectItem) -> Color {
        switch item.status {
        case .purchased: return .green
        case .favorite: return .orange
        case .rejected: return .red
        case .considering: return .secondary
        }
    }

    private func statusIcon(for item: ProjectItem) -> String {
        switch item.status {
        case .purchased: return "checkmark.circle.fill"
        case .favorite: return "star.fill"
        case .rejected: return "xmark.circle"
        case .considering: return "circle"
        }
    }
}
