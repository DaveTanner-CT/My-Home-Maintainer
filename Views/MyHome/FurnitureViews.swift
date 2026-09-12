import SwiftUI
import SwiftData

struct FurnitureListView: View {
    @Query(sort: \Furniture.name) private var furniture: [Furniture]
    @State private var showAdd = false

    var body: some View {
        List {
            if furniture.isEmpty {
                ContentUnavailableView(
                    "No furniture yet",
                    systemImage: "sofa",
                    description: Text("Track furniture that belongs with the home, including purchase details, rooms, warranties, photos, and documents.")
                )
            }
            ForEach(furniture) { item in
                NavigationLink { FurnitureDetailView(furniture: item) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.headline)
                        Text([item.category, item.linkedRooms.map(\.name).joined(separator: ", "), item.materialFinish].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
        }
        .navigationTitle("Furniture")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { FurnitureFormView() } }
    }
}

struct FurnitureDetailView: View {
    let furniture: Furniture
    @Query private var history: [MaintenanceRecord]
    @State private var showAddHistory = false

    private var linkedHistory: [MaintenanceRecord] {
        history.filter {
            $0.relatedItemName.caseInsensitiveCompare(furniture.name) == .orderedSame ||
            $0.relatedItemName.localizedCaseInsensitiveContains(furniture.name)
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Furniture") {
                if !furniture.category.isEmpty { LabeledContent("Category", value: furniture.category) }
                ForEach(furniture.linkedRooms) { linkedRoom in
                    NavigationLink { RoomDetailView(room: linkedRoom) } label: { LabeledContent("Room / Area", value: linkedRoom.name) }
                }
                if let project = furniture.sourceProject { NavigationLink { ProjectDetailView(project: project) } label: { LabeledContent("Added from project", value: project.title) } }
                if !furniture.brand.isEmpty { LabeledContent("Brand / Maker", value: furniture.brand) }
                if !furniture.model.isEmpty { LabeledContent("Model / Collection", value: furniture.model) }
                if !furniture.serialNumber.isEmpty { LabeledContent("Serial / ID", value: furniture.serialNumber) }
                if !furniture.materialFinish.isEmpty { LabeledContent("Material / Finish", value: furniture.materialFinish) }
                if !furniture.dimensions.isEmpty { LabeledContent("Dimensions", value: furniture.dimensions) }
            }
            Section("Purchase & Warranty") {
                if let date = furniture.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let price = furniture.purchasePrice { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
                if !furniture.purchasedFrom.isEmpty { LabeledContent("Purchased from", value: furniture.purchasedFrom) }
                if let warranty = furniture.warrantyExpiration {
                    WarrantyStatusView(expiration: warranty)
                    LabeledContent("Warranty expires", value: warranty.formatted(date: .abbreviated, time: .omitted))
                }
                if let vendor = furniture.vendor { NavigationLink { VendorDetailView(vendor: vendor) } label: { LabeledContent("Vendor", value: vendor.businessName) } }
                if !furniture.productLink.isEmpty, let url = furnitureNormalizedURL(furniture.productLink) { Link("Product / Reference Link", destination: url) }
            }
            Section {
                if linkedHistory.isEmpty { CompactEmptyStateRow("No furniture history yet", icon: "clock") }
                ForEach(linkedHistory.prefix(6)) { record in NavigationLink { MaintenanceRecordDetailView(record: record) } label: { MaintenanceRecordRow(record: record) } }
            } header: {
                CompactSectionHeader(
                    title: "Home History",
                    count: linkedHistory.count,
                    primarySystemImage: "clock.badge.plus",
                    primaryAccessibilityLabel: "Add History Event",
                    primaryAction: { showAddHistory = true }
                )
            }
            AttachmentSection(owner: .furniture(furniture))
            if !furniture.notes.isEmpty { Section("Notes") { Text(furniture.notes) } }
        }
        .listSectionSpacing(.compact)
        .navigationTitle(furniture.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("Edit") { FurnitureFormView(existing: furniture) } } }
        .sheet(isPresented: $showAddHistory) {
            NavigationStack {
                MaintenanceRecordFormView(
                    initialRoom: furniture.room,
                    initialProject: furniture.sourceProject,
                    initialVendor: furniture.vendor,
                    initialTitle: "Furniture: \(furniture.name)",
                    initialRelatedItemName: furniture.name
                )
            }
        }
    }
}

struct FurnitureFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @Query(sort: \Project.title) private var projects: [Project]

    let existing: Furniture?
    @State private var name: String
    @State private var category: String
    @State private var brand: String
    @State private var model: String
    @State private var serialNumber: String
    @State private var materialFinish: String
    @State private var dimensions: String
    @State private var selectedRoom: Room?
    @State private var selectedRooms: [Room]
    @State private var selectedVendor: Vendor?
    @State private var selectedProject: Project?
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var price: String
    @State private var purchasedFrom: String
    @State private var hasWarrantyDate: Bool
    @State private var warrantyDate: Date
    @State private var productLink: String
    @State private var notes: String
    @State private var pendingPhotoData: Data?
    @State private var showDelete = false

    private let categories = ["", "Sofa / Sectional", "Chair / Recliner", "Table", "Desk", "Bed / Headboard", "Dresser / Chest", "Bookcase / Shelving", "Cabinet / Storage", "Bench / Ottoman", "Outdoor Furniture", "Other"]

    init(existing: Furniture? = nil, initialRoom: Room? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? "")
        _brand = State(initialValue: existing?.brand ?? "")
        _model = State(initialValue: existing?.model ?? "")
        _serialNumber = State(initialValue: existing?.serialNumber ?? "")
        _materialFinish = State(initialValue: existing?.materialFinish ?? "")
        _dimensions = State(initialValue: existing?.dimensions ?? "")
        _selectedRoom = State(initialValue: existing?.room ?? initialRoom)
        _selectedRooms = State(initialValue: existing?.linkedRooms ?? [initialRoom].compactMap { $0 })
        _selectedVendor = State(initialValue: existing?.vendor)
        _selectedProject = State(initialValue: existing?.sourceProject)
        _hasPurchaseDate = State(initialValue: existing?.purchaseDate != nil)
        _purchaseDate = State(initialValue: existing?.purchaseDate ?? .now)
        _price = State(initialValue: existing?.purchasePrice.map { String($0) } ?? "")
        _purchasedFrom = State(initialValue: existing?.purchasedFrom ?? "")
        _hasWarrantyDate = State(initialValue: existing?.warrantyExpiration != nil)
        _warrantyDate = State(initialValue: existing?.warrantyExpiration ?? .now)
        _productLink = State(initialValue: existing?.productLink ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Furniture") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0.isEmpty ? "Select category" : $0).tag($0) }
                }
                TextField("Brand / maker", text: $brand)
                TextField("Model / collection", text: $model)
                TextField("Serial / inventory ID", text: $serialNumber)
                TextField("Material / finish", text: $materialFinish)
                TextField("Dimensions", text: $dimensions)
            }
            MultiRoomSelectionSection(rooms: rooms, primaryRoom: $selectedRoom, selectedRooms: $selectedRooms, title: "Rooms / Areas")
            Section("Purchase & Warranty") {
                Toggle("Purchase date", isOn: $hasPurchaseDate)
                if hasPurchaseDate { DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date) }
                TextField("Purchase price", text: $price).keyboardType(.decimalPad)
                TextField("Purchased from", text: $purchasedFrom)
                Toggle("Warranty expiration", isOn: $hasWarrantyDate)
                if hasWarrantyDate { DatePicker("Warranty", selection: $warrantyDate, displayedComponents: .date) }
                Picker("Vendor", selection: $selectedVendor) { Text("None").tag(nil as Vendor?); ForEach(vendors) { Text($0.businessName).tag(Optional($0)) } }
                Picker("Related Project", selection: $selectedProject) { Text("None").tag(nil as Project?); ForEach(projects) { Text($0.title).tag(Optional($0)) } }
            }
            Section("Reference") {
                TextField("Product / reference link", text: $productLink).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            PendingRecordPhotoSection(photoData: $pendingPhotoData, title: "Photo", addLabel: existing == nil ? "Add Photo" : "Add Another Photo")
            if existing != nil { Section { Button("Delete Furniture", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add Furniture" : "Edit Furniture")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .confirmationDialog("Delete this furniture item?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Furniture", role: .destructive) {
                if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func save() {
        let record = existing ?? Furniture(name: name)
        if existing == nil { modelContext.insert(record) }
        record.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        record.category = category
        record.brand = brand
        record.model = model
        record.serialNumber = serialNumber
        record.materialFinish = materialFinish
        record.dimensions = dimensions
        record.setPrimaryRoom(selectedRoom)
        record.additionalRooms = selectedRooms.filter { $0.persistentModelID != selectedRoom?.persistentModelID }
        record.vendor = selectedVendor
        record.sourceProject = selectedProject
        record.purchaseDate = hasPurchaseDate ? purchaseDate : nil
        record.purchasePrice = Double(price)
        record.purchasedFrom = purchasedFrom
        record.warrantyExpiration = hasWarrantyDate ? warrantyDate : nil
        record.productLink = productLink
        record.notes = notes
        savePendingRecordPhoto(pendingPhotoData, owner: .furniture(record), modelContext: modelContext)
        try? modelContext.save()
        dismiss()
    }
}

private func furnitureNormalizedURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil { return url }
    return URL(string: "https://\(trimmed)")
}
