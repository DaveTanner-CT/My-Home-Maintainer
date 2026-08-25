import SwiftUI
import SwiftData

struct RoomFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let existing: Room?
    @State private var name: String
    @State private var notes: String
    @State private var favorite: Bool
    @State private var areaType: HomeAreaType
    @State private var showDelete = false

    init(existing: Room? = nil, initialAreaType: HomeAreaType = .interior) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _favorite = State(initialValue: existing?.isFavorite ?? false)
        _areaType = State(initialValue: existing?.areaType ?? initialAreaType)
    }

    var body: some View {
        Form {
            Section("Room / Area") {
                TextField("Name", text: $name)
                Picker("Type", selection: $areaType) {
                    ForEach(HomeAreaType.allCases) { type in
                        Label(type.rawValue, systemImage: type.iconName).tag(type)
                    }
                }
                Toggle("Favorite", isOn: $favorite)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            if existing != nil { deleteSection(label: "Delete Room / Area") }
        }
        .navigationTitle(existing == nil ? "Add Room / Area" : "Edit Room / Area")
        .toolbar { formToolbar(save: save) }
        .confirmationDialog("Delete this room / area?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Room / Area", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Related records will be kept, but may no longer have a room or area assigned.") }
    }

    private func save() {
        let record = existing ?? Room(name: name, areaType: areaType)
        if existing == nil { modelContext.insert(record) }
        record.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        record.notes = notes
        record.isFavorite = favorite
        record.areaType = areaType
        try? modelContext.save(); dismiss()
    }
    private func delete() { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }
    @ViewBuilder private func deleteSection(label: String) -> some View { Section { Button(label, role: .destructive) { showDelete = true } } }
    @ToolbarContentBuilder private func formToolbar(save: @escaping () -> Void) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    }
}

struct SystemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @Query(sort: \Room.name) private var rooms: [Room]
    let existing: HomeSystem?
    @State private var name: String; @State private var type: String; @State private var manufacturer: String
    @State private var model: String; @State private var serial: String; @State private var location: String
    @State private var notes: String; @State private var website: String
    @State private var hasInstallDate: Bool; @State private var installDate: Date
    @State private var hasWarrantyDate: Bool; @State private var warrantyDate: Date
    @State private var purchaseCost: String; @State private var serviceLife: Int
    @State private var selectedVendor: Vendor?; @State private var selectedRoom: Room?; @State private var showDelete = false

    init(existing: HomeSystem? = nil, initialRoom: Room? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? ""); _type = State(initialValue: existing?.type ?? "")
        _manufacturer = State(initialValue: existing?.manufacturer ?? ""); _model = State(initialValue: existing?.model ?? "")
        _serial = State(initialValue: existing?.serialNumber ?? ""); _location = State(initialValue: existing?.location ?? "")
        _notes = State(initialValue: existing?.notes ?? ""); _website = State(initialValue: existing?.website ?? "")
        _hasInstallDate = State(initialValue: existing?.installationDate != nil); _installDate = State(initialValue: existing?.installationDate ?? .now)
        _hasWarrantyDate = State(initialValue: existing?.warrantyExpiration != nil); _warrantyDate = State(initialValue: existing?.warrantyExpiration ?? .now)
        _purchaseCost = State(initialValue: existing?.purchaseCost.map { String($0) } ?? "")
        _serviceLife = State(initialValue: existing?.expectedServiceLifeYears ?? 0)
        _selectedVendor = State(initialValue: existing?.vendor)
        _selectedRoom = State(initialValue: existing?.room ?? initialRoom)
    }

    var body: some View {
        Form {
            Section("System") {
                TextField("Name", text: $name); TextField("Type", text: $type); TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model); TextField("Serial number", text: $serial)
                Picker("Room / Area", selection: $selectedRoom) { Text("None").tag(nil as Room?); ForEach(rooms) { Text($0.name).tag(Optional($0)) } }
                if selectedRoom == nil { TextField("Location", text: $location) }
            }
            Section("Ownership") {
                Toggle("Installation date", isOn: $hasInstallDate); if hasInstallDate { DatePicker("Installed", selection: $installDate, displayedComponents: .date) }
                TextField("Purchase / installation cost", text: $purchaseCost).keyboardType(.decimalPad)
                Toggle("Warranty expiration", isOn: $hasWarrantyDate); if hasWarrantyDate { DatePicker("Warranty", selection: $warrantyDate, displayedComponents: .date) }
                Stepper("Expected service life: \(serviceLife == 0 ? "Not set" : "\(serviceLife) years")", value: $serviceLife, in: 0...75)
                Picker("Vendor", selection: $selectedVendor) { Text("None").tag(nil as Vendor?); ForEach(vendors) { Text($0.businessName).tag(Optional($0)) } }
            }
            Section("Reference") { TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never); TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete System", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add System" : "Edit System")
        .toolbar { editToolbar(save: save) }
        .confirmationDialog("Delete this system?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete System", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { }
        } message: { Text("Maintenance history will be preserved where possible.") }
    }
    private func save() {
        let record = existing ?? HomeSystem(name: name, type: type); if existing == nil { modelContext.insert(record) }
        record.name = name; record.type = type; record.manufacturer = manufacturer; record.model = model; record.serialNumber = serial
        record.room = selectedRoom; record.location = selectedRoom?.name ?? location; record.notes = notes; record.website = website; record.installationDate = hasInstallDate ? installDate : nil
        record.purchaseCost = Double(purchaseCost); record.warrantyExpiration = hasWarrantyDate ? warrantyDate : nil
        record.expectedServiceLifeYears = serviceLife == 0 ? nil : serviceLife; record.vendor = selectedVendor
        try? modelContext.save(); dismiss()
    }
    @ToolbarContentBuilder private func editToolbar(save: @escaping () -> Void) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    }
}

struct ApplianceFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]
    let existing: Appliance?
    @State private var name: String; @State private var category: String; @State private var manufacturer: String; @State private var model: String; @State private var serial: String
    @State private var purchasedFrom: String; @State private var price: String; @State private var hasPurchaseDate: Bool; @State private var purchaseDate: Date
    @State private var hasWarrantyDate: Bool; @State private var warrantyDate: Date; @State private var manufacturerWebsite: String; @State private var registrationLink: String
    @State private var notes: String; @State private var selectedRoom: Room?; @State private var showDelete = false

    init(existing: Appliance? = nil, initialRoom: Room? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? ""); _category = State(initialValue: existing?.category ?? ""); _manufacturer = State(initialValue: existing?.manufacturer ?? "")
        _model = State(initialValue: existing?.model ?? ""); _serial = State(initialValue: existing?.serialNumber ?? ""); _purchasedFrom = State(initialValue: existing?.purchasedFrom ?? "")
        _price = State(initialValue: existing?.purchasePrice.map { String($0) } ?? ""); _hasPurchaseDate = State(initialValue: existing?.purchaseDate != nil); _purchaseDate = State(initialValue: existing?.purchaseDate ?? .now)
        _hasWarrantyDate = State(initialValue: existing?.warrantyExpiration != nil); _warrantyDate = State(initialValue: existing?.warrantyExpiration ?? .now)
        _manufacturerWebsite = State(initialValue: existing?.manufacturerWebsite ?? ""); _registrationLink = State(initialValue: existing?.productRegistrationLink ?? "")
        _notes = State(initialValue: existing?.notes ?? ""); _selectedRoom = State(initialValue: existing?.room ?? initialRoom)
    }
    var body: some View {
        Form {
            Section("Appliance / Equipment") {
                TextField("Name", text: $name); TextField("Category", text: $category); TextField("Manufacturer", text: $manufacturer); TextField("Model", text: $model); TextField("Serial number", text: $serial)
                Picker("Room", selection: $selectedRoom) { Text("None").tag(nil as Room?); ForEach(rooms) { Text($0.name).tag(Optional($0)) } }
            }
            Section("Purchase & Warranty") {
                Toggle("Purchase date", isOn: $hasPurchaseDate); if hasPurchaseDate { DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date) }
                TextField("Purchase price", text: $price).keyboardType(.decimalPad); TextField("Purchased from", text: $purchasedFrom)
                Toggle("Warranty expiration", isOn: $hasWarrantyDate); if hasWarrantyDate { DatePicker("Warranty", selection: $warrantyDate, displayedComponents: .date) }
            }
            Section("Links & Notes") {
                TextField("Manufacturer website", text: $manufacturerWebsite).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Product registration link", text: $registrationLink).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            if existing != nil { Section { Button("Delete Appliance", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add Appliance" : "Edit Appliance")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty) } }
        .confirmationDialog("Delete this appliance?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete Appliance", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } }
    }
    private func save() {
        let record = existing ?? Appliance(name: name, category: category); if existing == nil { modelContext.insert(record) }
        record.name = name; record.category = category; record.manufacturer = manufacturer; record.model = model; record.serialNumber = serial; record.room = selectedRoom
        record.purchaseDate = hasPurchaseDate ? purchaseDate : nil; record.purchasePrice = Double(price); record.purchasedFrom = purchasedFrom
        record.warrantyExpiration = hasWarrantyDate ? warrantyDate : nil; record.manufacturerWebsite = manufacturerWebsite; record.productRegistrationLink = registrationLink; record.notes = notes
        try? modelContext.save(); dismiss()
    }
}

struct PaintFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]

    let existing: PaintFinish?
    let initialRoom: Room?

    @State private var selectedRoom: Room?
    @State private var surface: String
    @State private var brand: String
    @State private var productLine: String
    @State private var colorName: String
    @State private var colorCode: String
    @State private var sheen: String
    @State private var store: String
    @State private var cost: String
    @State private var quantity: String
    @State private var containerSize: String
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var productLink: String
    @State private var notes: String
    @State private var showDelete = false

    init(existing: PaintFinish? = nil, initialRoom: Room? = nil) {
        self.existing = existing
        self.initialRoom = initialRoom
        _selectedRoom = State(initialValue: existing?.room ?? initialRoom)
        _surface = State(initialValue: existing?.surface ?? "Walls")
        _brand = State(initialValue: existing?.brand ?? "")
        _productLine = State(initialValue: existing?.productLine ?? "")
        _colorName = State(initialValue: existing?.colorName ?? "")
        _colorCode = State(initialValue: existing?.colorCode ?? "")
        _sheen = State(initialValue: existing?.sheen ?? "")
        _store = State(initialValue: existing?.store ?? "")
        _cost = State(initialValue: existing?.cost.map { String($0) } ?? "")
        _quantity = State(initialValue: existing?.quantity.map { String($0) } ?? "")
        _containerSize = State(initialValue: existing?.containerSize ?? "")
        _hasPurchaseDate = State(initialValue: existing?.purchaseDate != nil)
        _purchaseDate = State(initialValue: existing?.purchaseDate ?? .now)
        _productLink = State(initialValue: existing?.productLink ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Location") {
                Picker("Room / Area", selection: $selectedRoom) {
                    Text("Choose room / area").tag(nil as Room?)
                    ForEach(rooms) { Text($0.name).tag(Optional($0)) }
                }
                Picker("Surface", selection: $surface) {
                    ForEach(["Walls","Ceiling","Trim","Doors","Cabinets","Built-ins","Flooring / Finish","Exterior Siding","Exterior Trim","Deck / Stain"], id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Paint / Finish") {
                TextField("Brand", text: $brand)
                TextField("Product line", text: $productLine)
                TextField("Color name", text: $colorName)
                TextField("Color code", text: $colorCode)
                TextField("Sheen / finish", text: $sheen)
            }
            Section("Purchase") {
                TextField("Purchased at", text: $store)
                Toggle("Purchase date", isOn: $hasPurchaseDate)
                if hasPurchaseDate { DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date) }
                TextField("Quantity", text: $quantity).keyboardType(.decimalPad)
                TextField("Container size", text: $containerSize)
                TextField("Cost", text: $cost).keyboardType(.decimalPad)
                TextField("Product link", text: $productLink).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Paint Record", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add Paint" : "Edit Paint")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(selectedRoom == nil || colorName.isEmpty) }
        }
        .onAppear { resolveLegacyRoomIfNeeded() }
        .confirmationDialog("Delete this paint record?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func resolveLegacyRoomIfNeeded() {
        guard selectedRoom == nil, let existing, !existing.roomName.isEmpty else { return }
        selectedRoom = rooms.first { $0.name.caseInsensitiveCompare(existing.roomName) == .orderedSame }
    }

    private func save() {
        guard let room = selectedRoom else { return }
        let record = existing ?? PaintFinish(room: room, surface: surface)
        if existing == nil { modelContext.insert(record) }
        record.room = room
        record.roomName = room.name
        record.surface = surface
        record.brand = brand
        record.productLine = productLine
        record.colorName = colorName
        record.colorCode = colorCode
        record.sheen = sheen
        record.store = store
        record.purchaseDate = hasPurchaseDate ? purchaseDate : nil
        record.quantity = Double(quantity)
        record.containerSize = containerSize
        record.cost = Double(cost)
        record.productLink = productLink
        record.notes = notes
        try? modelContext.save()
        dismiss()
    }
}

struct VendorFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    let existing: Vendor?
    @State private var businessName: String; @State private var contactName: String; @State private var category: String; @State private var phone: String; @State private var email: String; @State private var website: String; @State private var address: String; @State private var notes: String; @State private var favorite: Bool; @State private var showDelete = false
    init(existing: Vendor? = nil) {
        self.existing = existing; _businessName = State(initialValue: existing?.businessName ?? ""); _contactName = State(initialValue: existing?.contactName ?? ""); _category = State(initialValue: existing?.category ?? "")
        _phone = State(initialValue: existing?.phone ?? ""); _email = State(initialValue: existing?.email ?? ""); _website = State(initialValue: existing?.website ?? ""); _address = State(initialValue: existing?.address ?? ""); _notes = State(initialValue: existing?.notes ?? ""); _favorite = State(initialValue: existing?.isFavorite ?? false)
    }
    var body: some View {
        Form {
            Section("Vendor") { TextField("Business name", text: $businessName); TextField("Contact name", text: $contactName); TextField("Service category", text: $category); Toggle("Favorite", isOn: $favorite) }
            Section("Contact") { TextField("Phone", text: $phone).keyboardType(.phonePad); TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never); TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never); TextField("Address", text: $address) }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Vendor", role: .destructive) { showDelete = true } } }
        }
        .navigationTitle(existing == nil ? "Add Vendor" : "Edit Vendor")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(businessName.isEmpty) } }
        .confirmationDialog("Delete this vendor?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete Vendor", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } } message: { Text("Historical maintenance records retain vendor names already recorded.") }
    }
    private func save() { let r = existing ?? Vendor(businessName: businessName); if existing == nil { modelContext.insert(r) }; r.businessName = businessName; r.contactName = contactName; r.category = category; r.phone = phone; r.email = email; r.website = website; r.address = address; r.notes = notes; r.isFavorite = favorite; try? modelContext.save(); dismiss() }
}

struct DetectorFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    let existing: Detector?
    @State private var location: String; @State private var type: String; @State private var manufacturer: String; @State private var model: String; @State private var batteryType: String; @State private var isHardwired: Bool
    @State private var hasManufactureDate: Bool; @State private var manufactureDate: Date; @State private var hasInstallDate: Bool; @State private var installDate: Date; @State private var notes: String; @State private var showDelete = false
    init(existing: Detector? = nil) {
        self.existing = existing; _location = State(initialValue: existing?.location ?? ""); _type = State(initialValue: existing?.type ?? "Combination"); _manufacturer = State(initialValue: existing?.manufacturer ?? ""); _model = State(initialValue: existing?.model ?? ""); _batteryType = State(initialValue: existing?.batteryType ?? ""); _isHardwired = State(initialValue: existing?.isHardwired ?? false)
        _hasManufactureDate = State(initialValue: existing?.manufactureDate != nil); _manufactureDate = State(initialValue: existing?.manufactureDate ?? .now); _hasInstallDate = State(initialValue: existing?.installationDate != nil); _installDate = State(initialValue: existing?.installationDate ?? .now); _notes = State(initialValue: existing?.notes ?? "")
    }
    var body: some View {
        Form {
            Section("Detector") { TextField("Location", text: $location); Picker("Type", selection: $type) { ForEach(["Smoke","CO","Combination"], id: \.self) { Text($0).tag($0) } }; TextField("Manufacturer", text: $manufacturer); TextField("Model", text: $model); Toggle("Hardwired", isOn: $isHardwired); TextField("Battery type", text: $batteryType) }
            Section("Dates") { Toggle("Manufacture date", isOn: $hasManufactureDate); if hasManufactureDate { DatePicker("Manufactured", selection: $manufactureDate, displayedComponents: .date) }; Toggle("Installation date", isOn: $hasInstallDate); if hasInstallDate { DatePicker("Installed", selection: $installDate, displayedComponents: .date) } }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Detector", role: .destructive) { showDelete = true } } }
        }.navigationTitle(existing == nil ? "Add Detector" : "Edit Detector")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(location.isEmpty) } }
        .confirmationDialog("Delete this detector?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } }
    }
    private func save() { let r = existing ?? Detector(location: location); if existing == nil { modelContext.insert(r) }; r.location = location; r.type = type; r.manufacturer = manufacturer; r.model = model; r.manufactureDate = hasManufactureDate ? manufactureDate : nil; r.installationDate = hasInstallDate ? installDate : nil; r.batteryType = batteryType; r.isHardwired = isHardwired; r.replacementDate = Detector.calculateReplacementDate(manufactureDate: r.manufactureDate, installationDate: r.installationDate); r.notes = notes; try? modelContext.save(); dismiss() }
}

struct ConsumableFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    let existing: Consumable?
    @State private var name: String; @State private var type: String; @State private var size: String; @State private var manufacturer: String; @State private var partNumber: String; @State private var purchaseLink: String; @State private var intervalMonths: Int; @State private var hasLastReplaced: Bool; @State private var lastReplaced: Date; @State private var notes: String; @State private var showDelete = false
    init(existing: Consumable? = nil) { self.existing = existing; _name = State(initialValue: existing?.name ?? ""); _type = State(initialValue: existing?.type ?? ""); _size = State(initialValue: existing?.size ?? ""); _manufacturer = State(initialValue: existing?.manufacturer ?? ""); _partNumber = State(initialValue: existing?.modelPartNumber ?? ""); _purchaseLink = State(initialValue: existing?.purchaseLink ?? ""); _intervalMonths = State(initialValue: existing?.replacementIntervalMonths ?? 0); _hasLastReplaced = State(initialValue: existing?.lastReplaced != nil); _lastReplaced = State(initialValue: existing?.lastReplaced ?? .now); _notes = State(initialValue: existing?.notes ?? "") }
    var body: some View {
        Form {
            Section("Consumable") { TextField("Name", text: $name); TextField("Type", text: $type); TextField("Size", text: $size); TextField("Manufacturer", text: $manufacturer); TextField("Model / part number", text: $partNumber); TextField("Purchase link", text: $purchaseLink).keyboardType(.URL).textInputAutocapitalization(.never) }
            Section("Replacement") { Stepper("Interval: \(intervalMonths == 0 ? "Not set" : "\(intervalMonths) months")", value: $intervalMonths, in: 0...120); Toggle("Last replacement date", isOn: $hasLastReplaced); if hasLastReplaced { DatePicker("Last replaced", selection: $lastReplaced, displayedComponents: .date) } }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Consumable", role: .destructive) { showDelete = true } } }
        }.navigationTitle(existing == nil ? "Add Consumable" : "Edit Consumable")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty) } }
        .confirmationDialog("Delete this consumable?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } }
    }
    private func save() { let r = existing ?? Consumable(name: name); if existing == nil { modelContext.insert(r) }; r.name = name; r.type = type; r.size = size; r.manufacturer = manufacturer; r.modelPartNumber = partNumber; r.purchaseLink = purchaseLink; r.replacementIntervalMonths = intervalMonths == 0 ? nil : intervalMonths; r.lastReplaced = hasLastReplaced ? lastReplaced : nil; if let months = r.replacementIntervalMonths, let last = r.lastReplaced { r.nextReplacement = Calendar.current.date(byAdding: .month, value: months, to: last) } else { r.nextReplacement = nil }; r.notes = notes; try? modelContext.save(); dismiss() }
}

struct MaintenanceRecordFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext
    let existing: MaintenanceRecord?
    @State private var date: Date; @State private var title: String; @State private var cost: String; @State private var vendorName: String; @State private var taskTitle: String; @State private var relatedItemName: String; @State private var notes: String; @State private var showDelete = false
    init(existing: MaintenanceRecord? = nil) { self.existing = existing; _date = State(initialValue: existing?.date ?? .now); _title = State(initialValue: existing?.title ?? ""); _cost = State(initialValue: existing?.cost.map { String($0) } ?? ""); _vendorName = State(initialValue: existing?.vendorName ?? ""); _taskTitle = State(initialValue: existing?.taskTitle ?? ""); _relatedItemName = State(initialValue: existing?.relatedItemName ?? ""); _notes = State(initialValue: existing?.notes ?? "") }
    var body: some View {
        Form {
            Section("Maintenance Record") { TextField("Title", text: $title); DatePicker("Date", selection: $date, displayedComponents: .date); TextField("Cost", text: $cost).keyboardType(.decimalPad) }
            Section("Related") { TextField("Vendor", text: $vendorName); TextField("Task", text: $taskTitle); TextField("System / appliance / project", text: $relatedItemName) }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
            if existing != nil { Section { Button("Delete Record", role: .destructive) { showDelete = true } } }
        }.navigationTitle(existing == nil ? "Add Maintenance" : "Edit Maintenance")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(title.isEmpty) } }
        .confirmationDialog("Delete this maintenance record?", isPresented: $showDelete, titleVisibility: .visible) { Button("Delete", role: .destructive) { if let existing { modelContext.delete(existing); try? modelContext.save(); dismiss() } }; Button("Cancel", role: .cancel) { } }
    }
    private func save() { let r = existing ?? MaintenanceRecord(title: title); if existing == nil { modelContext.insert(r) }; r.date = date; r.title = title; r.cost = Double(cost); r.vendorName = vendorName; r.taskTitle = taskTitle; r.relatedItemName = relatedItemName; r.notes = notes; try? modelContext.save(); dismiss() }
}
