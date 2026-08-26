import SwiftUI
import SwiftData

struct ProjectShoppingView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ProjectItem]

    @State private var statusFilter = "Need to Buy"
    @State private var grouping = "Item / Decision"
    @State private var showAddOption = false
    @State private var addToGroup = ""
    @State private var addToCategory = "Inspiration"

    private let statusOptions = ["Need to Buy", "All", "Considering", "Favorite", "Purchased", "Installed"]
    private let groupingOptions = ["Item / Decision", "Store", "Category"]

    private var projectItems: [ProjectItem] {
        allItems.filter { $0.project?.persistentModelID == project.persistentModelID && !$0.isIdeaOnly }
    }

    private var items: [ProjectItem] {
        projectItems.filter { item in
            switch statusFilter {
            case "Need to Buy": return item.status == .considering || item.status == .favorite
            case "Considering": return item.status == .considering
            case "Favorite": return item.status == .favorite
            case "Purchased": return item.status == .purchased
            case "Installed": return item.status == .installed
            default: return item.status != .rejected
            }
        }
    }

    private var groups: [String] { Array(Set(items.map { groupName(for: $0) })).sorted() }
    private var decisionGroups: [String] { Array(Set(projectItems.filter { $0.status != .rejected }.map(\.comparisonGroupName))).sorted() }
    private var purchasedCount: Int { projectItems.filter { $0.status == .purchased }.count }
    private var installedCount: Int { projectItems.filter { $0.status == .installed }.count }

    var body: some View {
        List {
            Section("Shopping Progress") {
                Button { addToGroup = ""; addToCategory = "Inspiration"; showAddOption = true } label: {
                    progressRow(number: "1", title: "Add Options", detail: "Start with everything you are considering.", value: "\(projectItems.filter { $0.status != .rejected }.count)", icon: "plus.circle")
                }

                NavigationLink { ProjectComparisonView(project: project) } label: {
                    progressRow(number: "2", title: "Compare", detail: "Compare options by buying decision.", value: "\(decisionGroups.count)", icon: "rectangle.split.3x1")
                }

                progressRow(number: "3", title: "Choose & Purchase", detail: "Choose a winner from the list below and record the purchase.", value: "\(purchasedCount)", icon: "cart.badge.plus")

                NavigationLink { ProjectCompletionView(project: project) } label: {
                    progressRow(number: "4", title: "Install & Save", detail: purchasedCount == 0 ? "Purchased items will appear here when ready." : "\(purchasedCount) purchased item\(purchasedCount == 1 ? "" : "s") ready for the home record.", value: "\(installedCount)", icon: "house.and.flag")
                }
            } footer: {
                Text("Think in terms of what you are choosing — for example, Kitchen Faucet. Add several options to that decision, compare them, purchase one, then save the installed item to the permanent home record.")
            }

            Section("Shopping List") {
                Picker("Show", selection: $statusFilter) {
                    ForEach(statusOptions, id: \.self) { Text($0).tag($0) }
                }
                Picker("Group by", selection: $grouping) {
                    ForEach(groupingOptions, id: \.self) { Text($0).tag($0) }
                }
            }

            if items.isEmpty {
                ContentUnavailableView("No matching shopping items", systemImage: "cart", description: Text("Add an option here or change the filter."))
            } else {
                ForEach(groups, id: \.self) { group in
                    Section {
                        ForEach(items.filter { groupName(for: $0) == group }) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink { ProjectItemDetailView(project: project, item: item) } label: { shoppingRow(item) }
                                if item.status == .considering || item.status == .favorite {
                                    HStack(spacing: 16) {
                                        Button { item.status = .favorite; save() } label: { Label(item.status == .favorite ? "Favorite" : "Favorite", systemImage: item.status == .favorite ? "star.fill" : "star") }
                                            .buttonStyle(.borderless)
                                        NavigationLink { ProjectPurchaseView(project: project, item: item) } label: { Label("Choose & Purchase", systemImage: "cart.badge.plus") }
                                            .buttonStyle(.borderless)
                                    }
                                    .font(.caption)
                                } else if item.status == .purchased {
                                    Label("Purchased — ready to install/save", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                                } else if item.status == .installed {
                                    Label("Installed / saved to home", systemImage: "house.circle.fill").font(.caption).foregroundStyle(.green)
                                }
                            }
                            .padding(.vertical, 3)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if item.status != .installed {
                                    Button(role: .destructive) { item.status = .rejected; save() } label: { Label("Reject", systemImage: "xmark") }
                                }
                            }
                        }
                        if grouping == "Item / Decision" {
                            Button { addToGroup = group; addToCategory = categoryForGroup(group); showAddOption = true } label: { Label("Add Another Option for \(group)", systemImage: "plus.circle") }
                        }
                    } header: {
                        HStack { Text(group); if grouping == "Item / Decision" { Spacer(); Text("\(items.filter { groupName(for: $0) == group }.count) options").font(.caption).foregroundStyle(.secondary) } }
                    }
                }
            }

            Section("Project Spending") {
                LabeledContent("Planned", value: plannedTotal.formatted(AppFormatting.currency))
                LabeledContent("Purchased", value: purchasedTotal.formatted(AppFormatting.currency))
                if let budget = project.budget { LabeledContent("Budget remaining", value: (budget - purchasedTotal).formatted(AppFormatting.currency)) }
            }
        }
        .navigationTitle("Shopping")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { addToGroup = ""; addToCategory = "Inspiration"; showAddOption = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAddOption) { NavigationStack { ProjectItemFormView(project: project, initialComparisonGroup: addToGroup, initialCategory: addToCategory) } }
    }

    @ViewBuilder
    private func progressRow(number: String, title: String, detail: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 30, height: 30)
                Text(number).font(.headline).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 3) {
                Text(value).font(.headline)
                Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func shoppingRow(_ item: ProjectItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon(for: item)).foregroundStyle(statusColor(for: item)).font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                Text([item.manufacturer, item.model].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                Text("Qty \(item.quantity.formatted()) · \(item.estimatedTotal.formatted(AppFormatting.currency))").font(.caption).foregroundStyle(.secondary)
                if !item.store.isEmpty && grouping != "Store" { Text(item.store).font(.caption) }
                if !item.finishColor.isEmpty { Text(item.finishColor).font(.caption) }
            }
        }
    }

    private var plannedTotal: Double { projectItems.filter { $0.status != .rejected }.reduce(0) { $0 + $1.estimatedTotal } }
    private var purchasedTotal: Double { projectItems.filter { $0.status == .purchased || $0.status == .installed }.reduce(0) { $0 + ($1.actualPurchaseCost ?? $1.estimatedTotal) } }

    private func groupName(for item: ProjectItem) -> String {
        if grouping == "Category" { return item.category.isEmpty ? "Uncategorized" : item.category }
        if grouping == "Store" { return item.store.isEmpty ? "Store Not Set" : item.store }
        return item.comparisonGroupName
    }


    private func categoryForGroup(_ group: String) -> String {
        projectItems.first { $0.comparisonGroupName.caseInsensitiveCompare(group) == .orderedSame }?.category ?? "Inspiration"
    }
    private func save() { try? modelContext.save() }

    private func statusColor(for item: ProjectItem) -> Color {
        switch item.status {
        case .purchased, .installed: return .green
        case .favorite: return .orange
        case .rejected: return .red
        case .considering: return .secondary
        }
    }
    private func statusIcon(for item: ProjectItem) -> String {
        switch item.status {
        case .purchased: return "checkmark.circle.fill"
        case .installed: return "house.circle.fill"
        case .favorite: return "star.fill"
        case .rejected: return "xmark.circle"
        case .considering: return "circle"
        }
    }
}
