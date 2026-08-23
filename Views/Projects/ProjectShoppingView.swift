import SwiftUI
import SwiftData

struct ProjectShoppingView: View {
    let project: Project
    @Query private var allItems: [ProjectItem]
    @State private var storeFilter = "All"

    private var items: [ProjectItem] {
        allItems.filter { item in
            item.project?.persistentModelID == project.persistentModelID &&
            !item.isIdeaOnly &&
            item.status != .rejected &&
            (storeFilter == "All" || item.store == storeFilter)
        }
    }

    private var stores: [String] {
        Array(Set(allItems.filter { $0.project?.persistentModelID == project.persistentModelID && !$0.store.isEmpty }.map(\.store))).sorted()
    }

    var body: some View {
        List {
            if !stores.isEmpty {
                Section {
                    Picker("Store", selection: $storeFilter) {
                        Text("All Stores").tag("All")
                        ForEach(stores, id: \.self) { Text($0).tag($0) }
                    }
                }
            }

            if items.isEmpty {
                ContentUnavailableView("No shopping items", systemImage: "cart", description: Text("Add product items to this project to build a shopping list."))
            } else {
                ForEach(groupedStores, id: \.self) { store in
                    Section(store) {
                        ForEach(items.filter { displayStore(for: $0) == store }) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.status == .purchased ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.status == .purchased ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.headline)
                                    Text("Qty \(item.quantity.formatted()) · \(item.estimatedTotal.formatted(AppFormatting.currency))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !item.finishColor.isEmpty { Text(item.finishColor).font(.caption) }
                                    if !item.sku.isEmpty { Text("SKU: \(item.sku)").font(.caption2).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Shopping List")
    }

    private var groupedStores: [String] {
        Array(Set(items.map { displayStore(for: $0) })).sorted()
    }

    private func displayStore(for item: ProjectItem) -> String {
        item.store.isEmpty ? "Store Not Set" : item.store
    }
}
