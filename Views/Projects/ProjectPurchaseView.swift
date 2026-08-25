import SwiftUI
import SwiftData

struct ProjectPurchaseView: View {
    let project: Project
    let item: ProjectItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ProjectItem]

    @State private var purchaseDate: Date
    @State private var actualCostText: String
    @State private var store: String
    @State private var closeOtherOptions: Bool = true

    init(project: Project, item: ProjectItem) {
        self.project = project
        self.item = item
        _purchaseDate = State(initialValue: item.purchaseDate ?? .now)
        let startingCost = item.actualPurchaseCost ?? (item.estimatedTotal > 0 ? item.estimatedTotal : nil)
        _actualCostText = State(initialValue: startingCost.map { String($0) } ?? "")
        _store = State(initialValue: item.store)
    }

    var body: some View {
        Form {
            Section("Selected Option") {
                LabeledContent("Decision", value: item.comparisonGroupName)
                LabeledContent("Option", value: item.title)
                if !item.manufacturer.isEmpty { LabeledContent("Manufacturer", value: item.manufacturer) }
                if !item.model.isEmpty { LabeledContent("Model", value: item.model) }
                if item.estimatedTotal > 0 { LabeledContent("Planned total", value: item.estimatedTotal.formatted(AppFormatting.currency)) }
            }

            Section("Record Purchase") {
                DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                TextField("Actual total paid", text: $actualCostText).keyboardType(.decimalPad)
                TextField("Purchased from", text: $store)
            }

            Section("Other Options") {
                Toggle("Close other options for this decision", isOn: $closeOtherOptions)
                Text("When on, the other Considering or Favorite options in \(item.comparisonGroupName) are marked Rejected. They remain in the project history and can still be reopened later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button { savePurchase() } label: { Label("Confirm Purchase", systemImage: "cart.badge.checkmark") }
                    .disabled(!actualCostText.isEmpty && Double(actualCostText) == nil)
            }
        }
        .navigationTitle("Record Purchase")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func savePurchase() {
        item.status = .purchased
        item.purchaseDate = purchaseDate
        item.actualPurchaseCost = Double(actualCostText)
        item.store = store
        if closeOtherOptions {
            let projectItems = allItems.filter { $0.project?.persistentModelID == project.persistentModelID }
            for other in projectItems where other.persistentModelID != item.persistentModelID && other.comparisonGroupName.caseInsensitiveCompare(item.comparisonGroupName) == .orderedSame && (other.status == .considering || other.status == .favorite) {
                other.status = .rejected
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
