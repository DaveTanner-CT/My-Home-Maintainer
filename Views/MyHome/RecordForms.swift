import SwiftUI
import SwiftData

struct RoomFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var notes = ""
    @State private var favorite = false

    var body: some View {
        Form {
            Section("Room / Area") {
                TextField("Name", text: $name)
                Toggle("Favorite", isOn: $favorite)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Add Room")
        .toolbar { formToolbar(save: save) }
    }

    private func save() {
        modelContext.insert(Room(name: name, notes: notes, isFavorite: favorite))
        try? modelContext.save()
        dismiss()
    }

    @ToolbarContentBuilder
    private func formToolbar(save: @escaping () -> Void) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(name.isEmpty) }
    }
}

struct SystemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]

    @State private var name = ""
    @State private var type = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serial = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var hasInstallDate = false
    @State private var installDate = Date()
    @State private var serviceLife = 0
    @State private var selectedVendor: Vendor?

    var body: some View {
        Form {
            Section("System") {
                TextField("Name", text: $name)
                TextField("Type", text: $type)
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model)
                TextField("Serial number", text: $serial)
                TextField("Location", text: $location)
            }
            Section("Ownership") {
                Toggle("Installation date", isOn: $hasInstallDate)
                if hasInstallDate { DatePicker("Installed", selection: $installDate, displayedComponents: .date) }
                Stepper("Expected service life: \(serviceLife == 0 ? "Not set" : "\(serviceLife) years")", value: $serviceLife, in: 0...50)
                Picker("Vendor", selection: $selectedVendor) {
                    Text("None").tag(nil as Vendor?)
                    ForEach(vendors) { Text($0.businessName).tag(Optional($0)) }
                }
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Add System")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty) }
        }
    }

    private func save() {
        let item = HomeSystem(name: name, type: type, manufacturer: manufacturer, model: model, serialNumber: serial, installationDate: hasInstallDate ? installDate : nil, expectedServiceLifeYears: serviceLife == 0 ? nil : serviceLife, location: location, notes: notes, vendor: selectedVendor)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

struct ApplianceFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var name = ""
    @State private var category = ""
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var serial = ""
    @State private var purchasedFrom = ""
    @State private var price = ""
    @State private var hasPurchaseDate = false
    @State private var purchaseDate = Date()
    @State private var notes = ""
    @State private var selectedRoom: Room?

    var body: some View {
        Form {
            Section("Appliance / Equipment") {
                TextField("Name", text: $name)
                TextField("Category", text: $category)
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model)
                TextField("Serial number", text: $serial)
                Picker("Room", selection: $selectedRoom) {
                    Text("None").tag(nil as Room?)
                    ForEach(rooms) { Text($0.name).tag(Optional($0)) }
                }
            }
            Section("Purchase") {
                Toggle("Purchase date", isOn: $hasPurchaseDate)
                if hasPurchaseDate { DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date) }
                TextField("Purchase price", text: $price).keyboardType(.decimalPad)
                TextField("Purchased from", text: $purchasedFrom)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Add Appliance")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty) }
        }
    }

    private func save() {
        let item = Appliance(name: name, category: category, manufacturer: manufacturer, model: model, serialNumber: serial, purchaseDate: hasPurchaseDate ? purchaseDate : nil, purchasePrice: Double(price), purchasedFrom: purchasedFrom, notes: notes, room: selectedRoom)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

struct PaintFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.name) private var rooms: [Room]

    @State private var roomName = ""
    @State private var surface = "Walls"
    @State private var brand = ""
    @State private var productLine = ""
    @State private var colorName = ""
    @State private var colorCode = ""
    @State private var sheen = ""
    @State private var store = ""
    @State private var cost = ""
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Location") {
                Picker("Room", selection: $roomName) {
                    Text("Choose room").tag("")
                    ForEach(rooms) { Text($0.name).tag($0.name) }
                }
                Picker("Surface", selection: $surface) {
                    ForEach(["Walls", "Ceiling", "Trim", "Doors", "Cabinets", "Built-ins", "Exterior Siding", "Exterior Trim", "Deck / Stain"], id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Paint / Finish") {
                TextField("Brand", text: $brand)
                TextField("Product line", text: $productLine)
                TextField("Color name", text: $colorName)
                TextField("Color code", text: $colorCode)
                TextField("Sheen / finish", text: $sheen)
                TextField("Purchased at", text: $store)
                TextField("Cost", text: $cost).keyboardType(.decimalPad)
                TextField("Notes", text: $notes, axis: .vertical)
            }
        }
        .navigationTitle("Add Paint")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(roomName.isEmpty || colorName.isEmpty) }
        }
    }

    private func save() {
        let item = PaintFinish(roomName: roomName, surface: surface, brand: brand, productLine: productLine, colorName: colorName, colorCode: colorCode, sheen: sheen, store: store, cost: Double(cost), notes: notes)
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

struct VendorFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var businessName = ""
    @State private var contactName = ""
    @State private var category = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var favorite = false

    var body: some View {
        Form {
            Section("Vendor") {
                TextField("Business name", text: $businessName)
                TextField("Contact name", text: $contactName)
                TextField("Service category", text: $category)
                Toggle("Favorite", isOn: $favorite)
            }
            Section("Contact") {
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never)
                TextField("Address", text: $address)
            }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle("Add Vendor")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(businessName.isEmpty) }
        }
    }

    private func save() {
        modelContext.insert(Vendor(businessName: businessName, contactName: contactName, category: category, phone: phone, email: email, website: website, address: address, notes: notes, isFavorite: favorite))
        try? modelContext.save()
        dismiss()
    }
}

struct DetectorFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var location = ""
    @State private var type = "Combination"
    @State private var manufacturer = ""
    @State private var model = ""
    @State private var batteryType = ""
    @State private var isHardwired = false
    @State private var hasManufactureDate = false
    @State private var manufactureDate = Date()
    @State private var hasInstallDate = false
    @State private var installDate = Date()
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Detector") {
                TextField("Location", text: $location)
                Picker("Type", selection: $type) {
                    ForEach(["Smoke", "CO", "Combination"], id: \.self) { Text($0).tag($0) }
                }
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model", text: $model)
                Toggle("Hardwired", isOn: $isHardwired)
                TextField("Battery type", text: $batteryType)
            }
            Section("Dates") {
                Toggle("Manufacture date", isOn: $hasManufactureDate)
                if hasManufactureDate { DatePicker("Manufactured", selection: $manufactureDate, displayedComponents: .date) }
                Toggle("Installation date", isOn: $hasInstallDate)
                if hasInstallDate { DatePicker("Installed", selection: $installDate, displayedComponents: .date) }
            }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle("Add Detector")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(location.isEmpty) }
        }
    }

    private func save() {
        modelContext.insert(Detector(location: location, type: type, manufacturer: manufacturer, model: model, manufactureDate: hasManufactureDate ? manufactureDate : nil, installationDate: hasInstallDate ? installDate : nil, batteryType: batteryType, isHardwired: isHardwired, notes: notes))
        try? modelContext.save()
        dismiss()
    }
}

struct ConsumableFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var type = ""
    @State private var size = ""
    @State private var manufacturer = ""
    @State private var partNumber = ""
    @State private var purchaseLink = ""
    @State private var intervalMonths = 0
    @State private var hasLastReplaced = false
    @State private var lastReplaced = Date()
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Consumable") {
                TextField("Name", text: $name)
                TextField("Type", text: $type)
                TextField("Size", text: $size)
                TextField("Manufacturer", text: $manufacturer)
                TextField("Model / part number", text: $partNumber)
                TextField("Purchase link", text: $purchaseLink).keyboardType(.URL).textInputAutocapitalization(.never)
            }
            Section("Replacement") {
                Stepper("Interval: \(intervalMonths == 0 ? "Not set" : "\(intervalMonths) months")", value: $intervalMonths, in: 0...120)
                Toggle("Last replacement date", isOn: $hasLastReplaced)
                if hasLastReplaced { DatePicker("Last replaced", selection: $lastReplaced, displayedComponents: .date) }
            }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle("Add Consumable")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.isEmpty) }
        }
    }

    private func save() {
        modelContext.insert(Consumable(name: name, type: type, size: size, manufacturer: manufacturer, modelPartNumber: partNumber, purchaseLink: purchaseLink, replacementIntervalMonths: intervalMonths == 0 ? nil : intervalMonths, lastReplaced: hasLastReplaced ? lastReplaced : nil, notes: notes))
        try? modelContext.save()
        dismiss()
    }
}
