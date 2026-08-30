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
    @Query private var tasks: [MaintenanceTask]
    @Query private var history: [MaintenanceRecord]
    @State private var showAddTask = false

    private var linkedTasks: [MaintenanceTask] {
        tasks.filter { $0.fixture?.persistentModelID == fixture.persistentModelID }
    }
    private var linkedHistory: [MaintenanceRecord] {
        history.filter {
            $0.fixture?.persistentModelID == fixture.persistentModelID ||
            ($0.fixture == nil && $0.relatedItemName.localizedCaseInsensitiveContains(fixture.name))
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section("Fixture") {
                if !fixture.category.isEmpty { LabeledContent("Category", value: fixture.category) }
                ForEach(fixture.linkedRooms) { linkedRoom in
                    NavigationLink { RoomDetailView(room: linkedRoom) } label: { LabeledContent("Room / Area", value: linkedRoom.name) }
                }
                if let project = fixture.sourceProject { NavigationLink { ProjectDetailView(project: project) } label: { LabeledContent("Added from project", value: project.title) } }
                if !fixture.manufacturer.isEmpty { LabeledContent("Manufacturer", value: fixture.manufacturer) }
                if !fixture.model.isEmpty { LabeledContent("Model", value: fixture.model) }
                if !fixture.partNumber.isEmpty { LabeledContent("Part number", value: fixture.partNumber) }
                if !fixture.finishColor.isEmpty { LabeledContent("Finish / Color", value: fixture.finishColor) }
            }
            Section("Purchase, Installation & Warranty") {
                if let date = fixture.installationDate { LabeledContent("Installed", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let date = fixture.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let price = fixture.purchasePrice { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
                if !fixture.purchasedFrom.isEmpty { LabeledContent("Purchased from", value: fixture.purchasedFrom) }
                if let warranty = fixture.warrantyExpiration {
                    WarrantyStatusView(expiration: warranty)
                    LabeledContent("Warranty expires", value: warranty.formatted(date: .abbreviated, time: .omitted))
                    NavigationLink {
                        TaskFormView(initialRoom: fixture.room, initialFixture: fixture, initialProject: fixture.sourceProject, initialTitle: "Review warranty: \(fixture.name)", initialDueDate: warranty, initialLeadTimeDays: 30)
                    } label: { Label("Add Warranty Reminder", systemImage: "shield.badge.clock") }
                }
                if let vendor = fixture.vendor { NavigationLink { VendorDetailView(vendor: vendor) } label: { LabeledContent("Vendor", value: vendor.businessName) } }
                if !fixture.productLink.isEmpty, let url = fixtureNormalizedURL(fixture.productLink) { Link("Product / Replacement Link", destination: url) }
            }
            Section("Connected Tasks") {
                if linkedTasks.isEmpty { Text("No linked tasks").foregroundStyle(.secondary) }
                ForEach(linkedTasks) { task in NavigationLink { TaskDetailView(task: task) } label: { TaskRowView(task: task) } }
                Button { showAddTask = true } label: { Label("Add Task for This Fixture", systemImage: "plus") }
            }
            Section("Home History") {
                if linkedHistory.isEmpty { Text("No maintenance or installation history yet").foregroundStyle(.secondary) }
                ForEach(linkedHistory.prefix(6)) { record in NavigationLink { MaintenanceRecordDetailView(record: record) } label: { MaintenanceRecordRow(record: record) } }
            }
            AttachmentSection(owner: .fixture(fixture))
            if !fixture.notes.isEmpty { Section("Notes") { Text(fixture.notes) } }
        }
        .navigationTitle(fixture.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("Edit") { FixtureFormView(existing: fixture) } } }
        .sheet(isPresented: $showAddTask) { NavigationStack { TaskFormView(initialRoom: fixture.room, initialFixture: fixture, initialProject: fixture.sourceProject) } }
    }
}

struct FixtureFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @Query(sort: \Project.title) private var projects: [Project]

    let existing: Fixture?
    @State private var name: String
    @State private var category: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var partNumber: String
    @State private var finishColor: String
    @State private var selectedRoom: Room?
    @State private var selectedVendor: Vendor?
    @State private var selectedProject: Project?
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
        _selectedProject = State(initialValue: existing?.sourceProject)
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
                Picker("Related Project", selection: $selectedProject) { Text("None").tag(nil as Project?); ForEach(projects) { Text($0.title).tag(Optional($0)) } }
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
        record.setPrimaryRoom(selectedRoom)
        record.vendor = selectedVendor
        record.sourceProject = selectedProject
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
