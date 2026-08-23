import SwiftUI
import PhotosUI

struct ProjectItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let project: Project

    @State private var title = ""
    @State private var category = "Inspiration"
    @State private var isIdeaOnly = false
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var sku = ""
    @State private var finishColor = ""
    @State private var dimensions = ""
    @State private var store = ""
    @State private var website = ""
    @State private var unitCostText = ""
    @State private var quantity = 1.0
    @State private var notes = ""
    @State private var status: ProjectItemStatus = .considering
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

    private let categories = ["Inspiration", "Paint & Colors", "Flooring / Tile", "Fixtures", "Lighting", "Hardware", "Furniture", "Storage", "Appliances", "Materials", "Contractor Ideas"]

    var body: some View {
        Form {
            Section("Idea / Item") {
                TextField("Name", text: $title)
                Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                Toggle("Idea only", isOn: $isIdeaOnly)
                Picker("Status", selection: $status) { ForEach(ProjectItemStatus.allCases) { Text($0.rawValue).tag($0) } }
            }

            if !isIdeaOnly {
                Section("Product") {
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                    TextField("SKU", text: $sku)
                    TextField("Color / finish", text: $finishColor)
                    TextField("Dimensions", text: $dimensions)
                    TextField("Store", text: $store)
                    TextField("Website", text: $website)
                    TextField("Unit cost", text: $unitCostText).keyboardType(.decimalPad)
                    Stepper("Quantity: \(quantity.formatted())", value: $quantity, in: 1...1000)
                }
            }

            Section("Photo & Notes") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Add Project Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.isEmpty) }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task { photoData = try? await newValue.loadTransferable(type: Data.self) }
        }
    }

    private func save() {
        let item = ProjectItem(
            project: project,
            title: title,
            category: category,
            manufacturer: manufacturer,
            model: model,
            sku: sku,
            finishColor: finishColor,
            dimensions: dimensions,
            store: store,
            website: website,
            unitCost: Double(unitCostText),
            quantity: quantity,
            notes: notes,
            status: status,
            photoData: photoData,
            isIdeaOnly: isIdeaOnly
        )
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}
