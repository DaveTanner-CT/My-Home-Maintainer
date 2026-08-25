import SwiftUI
import SwiftData

struct FixturesListView: View {
    @Query(sort: \Fixture.name) private var fixtures: [Fixture]
    @State private var showAdd = false

    var body: some View {
        List {
            if fixtures.isEmpty {
                ContentUnavailableView("No fixtures yet", systemImage: "lightbulb", description: Text("Track faucets, sinks, toilets, lighting, fans, hardware, thermostats, and other installed fixtures."))
            }
            ForEach(fixtures) { fixture in
                NavigationLink { FixtureDetailView(fixture: fixture) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fixture.name).font(.headline)
                        Text([fixture.category, fixture.room?.name ?? "", fixture.finishColor].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
        }
        .navigationTitle("Fixtures")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { FixtureFormView() } }
    }
}

struct FixtureDetailView: View {
    let fixture: Fixture

    var body: some View {
        List {
            Section("Fixture") {
                if !fixture.category.isEmpty { LabeledContent("Category", value: fixture.category) }
                if let room = fixture.room { NavigationLink { RoomDetailView(room: room) } label: { LabeledContent("Room / Area", value: room.name) } }
                if !fixture.manufacturer.isEmpty { LabeledContent("Manufacturer", value: fixture.manufacturer) }
                if !fixture.model.isEmpty { LabeledContent("Model", value: fixture.model) }
                if !fixture.partNumber.isEmpty { LabeledContent("Part number", value: fixture.partNumber) }
                if !fixture.finishColor.isEmpty { LabeledContent("Finish / Color", value: fixture.finishColor) }
            }
            Section("Purchase & Installation") {
                if let date = fixture.installationDate { LabeledContent("Installed", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let date = fixture.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let price = fixture.purchasePrice { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
                if !fixture.purchasedFrom.isEmpty { LabeledContent("Purchased from", value: fixture.purchasedFrom) }
                if let warranty = fixture.warrantyExpiration { LabeledContent("Warranty", value: warranty.formatted(date: .abbreviated, time: .omitted)) }
                if let vendor = fixture.vendor { NavigationLink { VendorDetailView(vendor: vendor) } label: { LabeledContent("Vendor", value: vendor.businessName) } }
                if !fixture.productLink.isEmpty, let url = fixtureNormalizedURL(fixture.productLink) { Link("Product / Replacement Link", destination: url) }
            }
            AttachmentSection(owner: .fixture(fixture))
            if !fixture.notes.isEmpty { Section("Notes") { Text(fixture.notes) } }
        }
        .navigationTitle(fixture.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("Edit") { FixtureFormView(existing: fixture) } } }
    }
}

struct FixtureFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]

    let existing: Fixture?
    @State private var name: String
    @State private var category: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var partNumber: String
    @State private var finishColor: String
    @State private var selectedRoom: Room?
    @State private var selectedVendor: Vendor?
    @State private var hasInstallDate: Bool
    @State private var installDate: Date
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var price: String
    @State private var purchasedFrom: String
    @State private var hasWarrantyDate: Bool
    @State private var warrantyDate: Date
    @State private var productLink: String
    @State private var notes: String
    @State private var showDelete = false

    init(existing: Fixture? = nil, initialRoom: Room? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _category = State(initialValue: existing?.category ?? "")
        _manufacturer = State(initialValue: existing?.manufacturer ?? "")
        _model = State(initialValue: existing?.model ?? "")
        _partNumber = State(initialValue: existing?.partNumber ?? "")
        _finishColor = State(initialValue: existing?.finishColor ?? "")
        _selectedRoom = State(initialValue: existing?.room ?? initialRoom)
        _selectedVendor = State(initialValue: existing?.vendor)
        _hasInstallDate = State(initialValue: existing?.installationDate != nil)
        _installDate = State(initialValue: existing?.installationDate ?? .now)
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
            Section("Fixture") {
                TextField("Name", text: $name)
                TextField("Category", text: $category)
                Picker("Room / Area", selection: $selectedRoom) { Text("None").tag(nil as Room?); ForEach(rooms) { Text($0.name).tag(Optional($0)) } }
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model)
                TextField("Part / replacement number", text: $partNumber)
                TextField("Finish / color", text: $finishColor)
            }
            Section("Purchase & Installation") {
                Toggle("Installation date", isOn: $hasInstallDate)
                if hasInstallDate { DatePicker("Installed", selection: $installDate, displayedComponents: .date) }
                Toggle("Purchase date", isOn: $hasPurchaseDate)
                if hasPurchaseDate { DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date) }
                TextField("Purchase price", text: $price).keyboardType(.decimalPad)
                TextField("Purchased from", text: $purchasedFrom)
                Toggle("Warranty expiration", isOn: $hasWarrantyDate)
                if hasWarrantyDate { DatePicker("Warranty", selection: $warrantyDate, displayedComponents: .date) }
                Picker("Vendor", selection: $selectedVendor) { Text("None").tag(nil as Vendor?); ForEach(vendors) { Text($0.businessName).tag(Optional($0)) } }
            }
            Section("Reference") {
                TextField("Product / replacement link", text: $productLink).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            if existing != nil { Section { Button("Delete Fixture", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add Fixture" : "Edit Fixture")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
        .confirmationDialog("Delete this fixture?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Fixture", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func save() {
        let record = existing ?? Fixture(name: name)
        if existing == nil { modelContext.insert(record) }
        record.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        record.category = category
        record.manufacturer = manufacturer
        record.model = model
        record.partNumber = partNumber
        record.finishColor = finishColor
        record.room = selectedRoom
        record.vendor = selectedVendor
        record.installationDate = hasInstallDate ? installDate : nil
        record.purchaseDate = hasPurchaseDate ? purchaseDate : nil
        record.purchasePrice = Double(price)
        record.purchasedFrom = purchasedFrom
        record.warrantyExpiration = hasWarrantyDate ? warrantyDate : nil
        record.productLink = productLink
        record.notes = notes
        try? modelContext.save()
        dismiss()
    }
}


private func fixtureNormalizedURL(_ value: String) -> URL? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil { return url }
    return URL(string: "https://\(trimmed)")
}
