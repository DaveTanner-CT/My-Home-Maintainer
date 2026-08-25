import SwiftUI
import PhotosUI

struct ProjectItemFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    let project: Project; let existing: ProjectItem?
    @State private var title: String; @State private var category: String; @State private var isIdeaOnly: Bool; @State private var manufacturer: String; @State private var model: String; @State private var sku: String; @State private var finishColor: String; @State private var dimensions: String; @State private var store: String; @State private var website: String; @State private var unitCostText: String; @State private var quantity: Double; @State private var actualCostText: String; @State private var purchaseDate: Date; @State private var notes: String; @State private var status: ProjectItemStatus; @State private var selectedPhoto: PhotosPickerItem?; @State private var photoData: Data?; @State private var showDelete = false
    private let categories = ["Inspiration", "Paint & Colors", "Flooring / Tile", "Fixtures", "Lighting", "Hardware", "Furniture", "Storage", "Appliances", "Materials", "Contractor Ideas"]

    init(project: Project, existing: ProjectItem? = nil) {
        self.project = project; self.existing = existing
        _title = State(initialValue: existing?.title ?? ""); _category = State(initialValue: existing?.category ?? "Inspiration"); _isIdeaOnly = State(initialValue: existing?.isIdeaOnly ?? false)
        _manufacturer = State(initialValue: existing?.manufacturer ?? ""); _model = State(initialValue: existing?.model ?? ""); _sku = State(initialValue: existing?.sku ?? ""); _finishColor = State(initialValue: existing?.finishColor ?? ""); _dimensions = State(initialValue: existing?.dimensions ?? ""); _store = State(initialValue: existing?.store ?? ""); _website = State(initialValue: existing?.website ?? ""); _unitCostText = State(initialValue: existing?.unitCost.map { String($0) } ?? ""); _quantity = State(initialValue: existing?.quantity ?? 1); _actualCostText = State(initialValue: existing?.actualPurchaseCost.map { String($0) } ?? ""); _purchaseDate = State(initialValue: existing?.purchaseDate ?? .now); _notes = State(initialValue: existing?.notes ?? ""); _status = State(initialValue: existing?.status ?? .considering); _photoData = State(initialValue: existing?.photoData)
    }

    var body: some View {
        Form {
            Section("Idea / Item") { TextField("Name", text: $title); Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }; Toggle("Idea only", isOn: $isIdeaOnly); Picker("Status", selection: $status) { ForEach(ProjectItemStatus.allCases) { Text($0.rawValue).tag($0) } } }
            if !isIdeaOnly { Section("Product") { TextField("Manufacturer", text: $manufacturer); TextField("Model", text: $model); TextField("SKU", text: $sku); TextField("Color / finish", text: $finishColor); TextField("Dimensions", text: $dimensions); TextField("Store", text: $store); TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never); TextField("Unit cost", text: $unitCostText).keyboardType(.decimalPad); Stepper("Quantity: \(quantity.formatted())", value: $quantity, in: 1...1000); if status == .purchased { DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date); TextField("Actual purchase cost", text: $actualCostText).keyboardType(.decimalPad) } } }
            Section("Photo & Notes") { PhotosPicker(selection: $selectedPhoto, matching: .images) { Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo") }; if photoData != nil { Button("Remove Photo", role: .destructive) { photoData = nil } }; TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Project Item", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add Project Item" : "Edit Project Item").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.isEmpty) } }
        .onChange(of: selectedPhoto) { _, newValue in guard let newValue else { return }; Task { photoData = try? await newValue.loadTransferable(type: Data.self) } }
        .confirmationDialog("Delete this project item?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete Item", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } }
    }
    private func save() { let item = existing ?? ProjectItem(project: project, title: title); if existing == nil { modelContext.insert(item) }; item.project = project; item.title = title; item.category = category; item.isIdeaOnly = isIdeaOnly; item.manufacturer = manufacturer; item.model = model; item.sku = sku; item.finishColor = finishColor; item.dimensions = dimensions; item.store = store; item.website = website; item.unitCost = Double(unitCostText); item.quantity = quantity; item.actualPurchaseCost = Double(actualCostText); item.purchaseDate = status == .purchased ? purchaseDate : nil; item.notes = notes; item.status = status; item.photoData = photoData; try? modelContext.save(); dismiss() }
}

struct ProjectMeasurementFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    let project: Project; let existing: ProjectMeasurement?
    @State private var name: String; @State private var valueText: String; @State private var unit: String; @State private var notes: String; @State private var showDelete = false
    init(project: Project, existing: ProjectMeasurement? = nil) { self.project = project; self.existing = existing; _name = State(initialValue: existing?.name ?? ""); _valueText = State(initialValue: existing.map { String($0.value) } ?? ""); _unit = State(initialValue: existing?.unit ?? "in"); _notes = State(initialValue: existing?.notes ?? "") }
    var body: some View { Form { Section("Measurement") { TextField("Name", text: $name); TextField("Value", text: $valueText).keyboardType(.decimalPad); Picker("Unit", selection: $unit) { ForEach(["in","ft","sq ft","cm","m","sq m"], id: \.self) { Text($0).tag($0) } }; TextField("Notes", text: $notes, axis: .vertical) }; if existing != nil { Section { Button("Delete Measurement", role: .destructive) { showDelete = true } } } }.navigationTitle(existing == nil ? "Add Measurement" : "Edit Measurement").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty || Double(valueText) == nil) } }.confirmationDialog("Delete this measurement?", isPresented: $showDelete) { Button("Delete", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } } }
    private func save() { guard let value = Double(valueText) else { return }; let m = existing ?? ProjectMeasurement(project: project, name: name, value: value, unit: unit); if existing == nil { modelContext.insert(m) }; m.project = project; m.name = name; m.value = value; m.unit = unit; m.notes = notes; try? modelContext.save(); dismiss() }
}
