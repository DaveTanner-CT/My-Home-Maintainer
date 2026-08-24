import SwiftUI
import SwiftData

struct MyHomeView: View {
    @Query private var records: [MaintenanceRecord]
    @State private var showAddMaintenance = false

    var body: some View {
        List {
            Section("Home Records") {
                NavigationLink { RoomsListView() } label: { Label("Rooms & Areas", systemImage: "door.left.hand.open") }
                NavigationLink { SystemsListView() } label: { Label("Home Systems", systemImage: "wrench.and.screwdriver") }
                NavigationLink { AppliancesListView() } label: { Label("Appliances & Equipment", systemImage: "refrigerator") }
                NavigationLink { PaintListView() } label: { Label("Paint & Finishes", systemImage: "paintbrush") }
                NavigationLink { DetectorsListView() } label: { Label("Smoke & CO Detectors", systemImage: "sensor.tag.radiowaves.forward") }
                NavigationLink { ConsumablesListView() } label: { Label("Filters & Consumables", systemImage: "shippingbox") }
                NavigationLink { VendorsListView() } label: { Label("Vendors", systemImage: "person.2") }
            }
            Section("History") {
                NavigationLink { MaintenanceHistoryView() } label: { Label("Maintenance History", systemImage: "clock.arrow.circlepath") }
                LabeledContent("Recorded events", value: "\(records.count)")
                Button { showAddMaintenance = true } label: { Label("Add Maintenance Record", systemImage: "plus.circle") }
            }
        }
        .navigationTitle("My Home")
        .sheet(isPresented: $showAddMaintenance) { NavigationStack { MaintenanceRecordFormView() } }
    }
}

struct RoomsListView: View {
    @Query(sort: \Room.name) private var rooms: [Room]
    @State private var showAdd = false
    var body: some View {
        List {
            if rooms.isEmpty { ContentUnavailableView("No rooms yet", systemImage: "door.left.hand.open", description: Text("Add rooms to connect paint, appliances, systems, projects, and tasks.")) }
            ForEach(rooms) { room in
                NavigationLink { RoomDetailView(room: room) } label: {
                    HStack { Image(systemName: "door.left.hand.open").foregroundStyle(.secondary); Text(room.name); Spacer(); if room.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) } }
                }
            }
        }
        .navigationTitle("Rooms & Areas")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { RoomFormView() } }
    }
}

struct RoomDetailView: View {
    let room: Room
    @Query private var appliances: [Appliance]
    @Query private var tasks: [MaintenanceTask]
    @Query private var paints: [PaintFinish]
    @State private var showEdit = false
    private var roomAppliances: [Appliance] { appliances.filter { $0.room?.persistentModelID == room.persistentModelID } }
    private var roomTasks: [MaintenanceTask] { tasks.filter { $0.room?.persistentModelID == room.persistentModelID } }
    private var roomPaints: [PaintFinish] { paints.filter { $0.roomName.caseInsensitiveCompare(room.name) == .orderedSame } }
    var body: some View {
        List {
            if room.isFavorite { Section { Label("Favorite", systemImage: "star.fill").foregroundStyle(.yellow) } }
            if !room.notes.isEmpty { Section("Notes") { Text(room.notes) } }
            Section("Paint & Finishes") {
                if roomPaints.isEmpty { Text("No paint records").foregroundStyle(.secondary) }
                ForEach(roomPaints) { paint in NavigationLink { PaintDetailView(paint: paint) } label: { VStack(alignment: .leading) { Text("\(paint.surface): \(paint.colorName)"); if !paint.colorCode.isEmpty { Text(paint.colorCode).font(.caption).foregroundStyle(.secondary) } } } }
            }
            Section("Appliances & Equipment") {
                if roomAppliances.isEmpty { Text("No appliances").foregroundStyle(.secondary) }
                ForEach(roomAppliances) { item in NavigationLink(item.name) { ApplianceDetailView(appliance: item) } }
            }
            Section("Tasks") {
                if roomTasks.isEmpty { Text("No linked tasks").foregroundStyle(.secondary) }
                ForEach(roomTasks) { task in NavigationLink { TaskDetailView(task: task) } label: { TaskRowView(task: task) } }
            }
        }
        .navigationTitle(room.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) { NavigationStack { RoomFormView(existing: room) } }
    }
}

struct SystemsListView: View {
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @State private var showAdd = false
    var body: some View {
        List {
            if systems.isEmpty { ContentUnavailableView("No systems yet", systemImage: "wrench.and.screwdriver", description: Text("Add HVAC, water heaters, plumbing, generators, and other home systems.")) }
            ForEach(systems) { system in NavigationLink { SystemDetailView(system: system) } label: { VStack(alignment: .leading, spacing: 3) { Text(system.name).font(.headline); Text([system.type, system.location].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) } } }
        }.navigationTitle("Home Systems")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { SystemFormView() } }
    }
}

struct SystemDetailView: View {
    let system: HomeSystem
    @Query private var tasks: [MaintenanceTask]
    @Query private var history: [MaintenanceRecord]
    @State private var showEdit = false
    private var linkedTasks: [MaintenanceTask] { tasks.filter { $0.system?.persistentModelID == system.persistentModelID } }
    private var linkedHistory: [MaintenanceRecord] { history.filter { $0.relatedItemName.localizedCaseInsensitiveContains(system.name) } }
    var body: some View {
        List {
            Section("Equipment") {
                LabeledContent("Type", value: system.type)
                if !system.manufacturer.isEmpty { LabeledContent("Manufacturer", value: system.manufacturer) }
                if !system.model.isEmpty { LabeledContent("Model", value: system.model) }
                if !system.serialNumber.isEmpty { LabeledContent("Serial", value: system.serialNumber) }
                if !system.location.isEmpty { LabeledContent("Location", value: system.location) }
            }
            Section("Ownership") {
                if let date = system.installationDate { LabeledContent("Installed", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let cost = system.purchaseCost { LabeledContent("Cost", value: cost.formatted(AppFormatting.currency)) }
                if let warranty = system.warrantyExpiration { LabeledContent("Warranty expires", value: warranty.formatted(date: .abbreviated, time: .omitted)) }
                if let years = system.expectedServiceLifeYears { LabeledContent("Expected service life", value: "~\(years) years") }
                if let vendor = system.vendor { NavigationLink { VendorDetailView(vendor: vendor) } label: { LabeledContent("Vendor", value: vendor.businessName) } }
                if !system.website.isEmpty, let url = normalizedURL(system.website) { Link(destination: url) { Label("Open Website", systemImage: "safari") } }
            }
            Section("Tasks") { if linkedTasks.isEmpty { Text("No linked tasks").foregroundStyle(.secondary) }; ForEach(linkedTasks) { task in NavigationLink { TaskDetailView(task: task) } label: { TaskRowView(task: task) } } }
            Section("Maintenance History") { if linkedHistory.isEmpty { Text("No recorded maintenance").foregroundStyle(.secondary) }; ForEach(linkedHistory) { record in NavigationLink { MaintenanceRecordDetailView(record: record) } label: { MaintenanceRecordRow(record: record) } } }
            if !system.notes.isEmpty { Section("Notes") { Text(system.notes) } }
        }.navigationTitle(system.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) { NavigationStack { SystemFormView(existing: system) } }
    }
}

struct AppliancesListView: View {
    @Query(sort: \Appliance.name) private var appliances: [Appliance]
    @State private var showAdd = false
    var body: some View {
        List {
            if appliances.isEmpty { ContentUnavailableView("No appliances yet", systemImage: "refrigerator", description: Text("Add appliances to track warranties, models, purchases, and maintenance.")) }
            ForEach(appliances) { appliance in NavigationLink { ApplianceDetailView(appliance: appliance) } label: { VStack(alignment: .leading, spacing: 3) { Text(appliance.name).font(.headline); Text([appliance.manufacturer, appliance.model].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) } } }
        }.navigationTitle("Appliances")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { ApplianceFormView() } }
    }
}

struct ApplianceDetailView: View {
    let appliance: Appliance
    @Query private var tasks: [MaintenanceTask]
    @Query private var history: [MaintenanceRecord]
    @State private var showEdit = false
    private var linkedTasks: [MaintenanceTask] { tasks.filter { $0.appliance?.persistentModelID == appliance.persistentModelID } }
    private var linkedHistory: [MaintenanceRecord] { history.filter { $0.relatedItemName.localizedCaseInsensitiveContains(appliance.name) } }
    var body: some View {
        List {
            Section("Appliance") {
                if !appliance.category.isEmpty { LabeledContent("Category", value: appliance.category) }
                if !appliance.manufacturer.isEmpty { LabeledContent("Manufacturer", value: appliance.manufacturer) }
                if !appliance.model.isEmpty { LabeledContent("Model", value: appliance.model) }
                if !appliance.serialNumber.isEmpty { LabeledContent("Serial", value: appliance.serialNumber) }
                if let room = appliance.room { NavigationLink { RoomDetailView(room: room) } label: { LabeledContent("Room", value: room.name) } }
            }
            Section("Purchase & Warranty") {
                if let date = appliance.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let price = appliance.purchasePrice { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
                if !appliance.purchasedFrom.isEmpty { LabeledContent("Store", value: appliance.purchasedFrom) }
                if let warranty = appliance.warrantyExpiration { LabeledContent("Warranty", value: warranty.formatted(date: .abbreviated, time: .omitted)) }
                if !appliance.manufacturerWebsite.isEmpty, let url = normalizedURL(appliance.manufacturerWebsite) { Link("Manufacturer Website", destination: url) }
                if !appliance.productRegistrationLink.isEmpty, let url = normalizedURL(appliance.productRegistrationLink) { Link("Product Registration", destination: url) }
            }
            Section("Tasks") { if linkedTasks.isEmpty { Text("No linked tasks").foregroundStyle(.secondary) }; ForEach(linkedTasks) { task in NavigationLink { TaskDetailView(task: task) } label: { TaskRowView(task: task) } } }
            Section("Maintenance History") { if linkedHistory.isEmpty { Text("No recorded maintenance").foregroundStyle(.secondary) }; ForEach(linkedHistory) { record in NavigationLink { MaintenanceRecordDetailView(record: record) } label: { MaintenanceRecordRow(record: record) } } }
            if !appliance.notes.isEmpty { Section("Notes") { Text(appliance.notes) } }
        }.navigationTitle(appliance.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) { NavigationStack { ApplianceFormView(existing: appliance) } }
    }
}

struct PaintListView: View {
    @Query(sort: \PaintFinish.roomName) private var paints: [PaintFinish]
    @State private var showAdd = false
    var body: some View {
        List {
            if paints.isEmpty { ContentUnavailableView("No paint records", systemImage: "paintbrush", description: Text("Save paint colors so you never have to guess which color was used.")) }
            ForEach(paints) { paint in NavigationLink { PaintDetailView(paint: paint) } label: { VStack(alignment: .leading, spacing: 4) { Text("\(paint.roomName) · \(paint.surface)").font(.headline); Text([paint.brand, paint.colorName, paint.colorCode].filter { !$0.isEmpty }.joined(separator: " · ")); if !paint.sheen.isEmpty || !paint.store.isEmpty { Text([paint.sheen, paint.store].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) } } } }
        }.navigationTitle("Paint & Finishes")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { PaintFormView() } }
    }
}

struct PaintDetailView: View {
    let paint: PaintFinish
    @State private var showEdit = false
    @State private var showDuplicate = false
    var body: some View {
        List {
            Section("Location") { LabeledContent("Room / Area", value: paint.roomName); LabeledContent("Surface", value: paint.surface) }
            Section("Paint / Finish") { if !paint.brand.isEmpty { LabeledContent("Brand", value: paint.brand) }; if !paint.productLine.isEmpty { LabeledContent("Product line", value: paint.productLine) }; LabeledContent("Color", value: paint.colorName); if !paint.colorCode.isEmpty { LabeledContent("Color code", value: paint.colorCode) }; if !paint.sheen.isEmpty { LabeledContent("Sheen", value: paint.sheen) } }
            Section("Purchase") { if !paint.store.isEmpty { LabeledContent("Store", value: paint.store) }; if let date = paint.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }; if let q = paint.quantity { LabeledContent("Quantity", value: q.formatted()) }; if !paint.containerSize.isEmpty { LabeledContent("Container", value: paint.containerSize) }; if let cost = paint.cost { LabeledContent("Cost", value: cost.formatted(AppFormatting.currency)) }; if !paint.productLink.isEmpty, let url = normalizedURL(paint.productLink) { Link("Open Product Link", destination: url) } }
            if !paint.notes.isEmpty { Section("Notes") { Text(paint.notes) } }
            Section { Button { showDuplicate = true } label: { Label("Duplicate Paint Record", systemImage: "square.on.square") } }
        }.navigationTitle(paint.colorName)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) { NavigationStack { PaintFormView(existing: paint) } }
        .sheet(isPresented: $showDuplicate) { NavigationStack { PaintDuplicateFormView(source: paint) } }
    }
}

struct PaintDuplicateFormView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext; @Query(sort: \Room.name) private var rooms: [Room]
    let source: PaintFinish; @State private var roomName = ""
    var body: some View { Form { Section("Duplicate To") { Picker("Room", selection: $roomName) { Text("Choose room").tag(""); ForEach(rooms) { Text($0.name).tag($0.name) } }; LabeledContent("Color", value: [source.colorName, source.colorCode].filter { !$0.isEmpty }.joined(separator: " · ")); LabeledContent("Surface", value: source.surface) } }.navigationTitle("Duplicate Paint").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { let copy = PaintFinish(roomName: roomName, surface: source.surface, brand: source.brand, productLine: source.productLine, colorName: source.colorName, colorCode: source.colorCode, sheen: source.sheen, store: source.store, purchaseDate: source.purchaseDate, quantity: source.quantity, containerSize: source.containerSize, cost: source.cost, notes: source.notes, productLink: source.productLink); modelContext.insert(copy); try? modelContext.save(); dismiss() }.disabled(roomName.isEmpty) } } }
}

struct VendorsListView: View {
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @State private var showAdd = false
    var body: some View { List { if vendors.isEmpty { ContentUnavailableView("No vendors", systemImage: "person.2", description: Text("Keep contractors and service providers connected to your home records.")) }; ForEach(vendors) { vendor in NavigationLink { VendorDetailView(vendor: vendor) } label: { VendorRow(vendor: vendor) } } }.navigationTitle("Vendors").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }.sheet(isPresented: $showAdd) { NavigationStack { VendorFormView() } } }
}

struct VendorDetailView: View {
    let vendor: Vendor
    @Query private var systems: [HomeSystem]; @Query private var tasks: [MaintenanceTask]; @Query private var history: [MaintenanceRecord]
    @State private var showEdit = false
    private var vendorSystems: [HomeSystem] { systems.filter { $0.vendor?.persistentModelID == vendor.persistentModelID } }
    private var vendorTasks: [MaintenanceTask] { tasks.filter { $0.vendor?.persistentModelID == vendor.persistentModelID } }
    private var vendorHistory: [MaintenanceRecord] { history.filter { $0.vendorName.localizedCaseInsensitiveContains(vendor.businessName) } }
    private var totalSpending: Double { vendorHistory.compactMap(\.cost).reduce(0,+) }
    var body: some View {
        List {
            Section("Vendor") { if !vendor.category.isEmpty { LabeledContent("Service", value: vendor.category) }; if !vendor.contactName.isEmpty { LabeledContent("Contact", value: vendor.contactName) }; if vendor.isFavorite { Label("Favorite", systemImage: "star.fill").foregroundStyle(.yellow) } }
            Section("Contact") { if !vendor.phone.isEmpty, let url = URL(string: "tel:\(vendor.phone.filter { $0.isNumber })") { Link(destination: url) { Label(vendor.phone, systemImage: "phone") } }; if !vendor.email.isEmpty, let url = URL(string: "mailto:\(vendor.email)") { Link(destination: url) { Label(vendor.email, systemImage: "envelope") } }; if !vendor.website.isEmpty, let url = normalizedURL(vendor.website) { Link(destination: url) { Label("Website", systemImage: "safari") } }; if !vendor.address.isEmpty, let encoded = vendor.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: "http://maps.apple.com/?q=\(encoded)") { Link(destination: url) { Label(vendor.address, systemImage: "map") } } }
            if !vendorSystems.isEmpty { Section("Related Systems") { ForEach(vendorSystems) { item in NavigationLink(item.name) { SystemDetailView(system: item) } } } }
            if !vendorTasks.isEmpty { Section("Tasks") { ForEach(vendorTasks) { task in NavigationLink { TaskDetailView(task: task) } label: { TaskRowView(task: task) } } } }
            Section("Work History") { if vendorHistory.isEmpty { Text("No recorded work").foregroundStyle(.secondary) }; ForEach(vendorHistory) { record in NavigationLink { MaintenanceRecordDetailView(record: record) } label: { MaintenanceRecordRow(record: record) } }; if totalSpending > 0 { LabeledContent("Total recorded spending", value: totalSpending.formatted(AppFormatting.currency)) } }
            if !vendor.notes.isEmpty { Section("Notes") { Text(vendor.notes) } }
        }.navigationTitle(vendor.businessName).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }.sheet(isPresented: $showEdit) { NavigationStack { VendorFormView(existing: vendor) } }
    }
}

struct VendorRow: View { let vendor: Vendor; var body: some View { VStack(alignment: .leading, spacing: 4) { HStack { Text(vendor.businessName).font(.headline); if vendor.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) } }; Text([vendor.category, vendor.contactName].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 3) } }

struct MaintenanceHistoryView: View {
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var records: [MaintenanceRecord]
    @State private var showAdd = false
    var body: some View { List { if records.isEmpty { ContentUnavailableView("No maintenance history", systemImage: "clock.arrow.circlepath", description: Text("Completed tasks and manually entered work will appear here.")) }; ForEach(records) { record in NavigationLink { MaintenanceRecordDetailView(record: record) } label: { MaintenanceRecordRow(record: record) } } }.navigationTitle("Maintenance History").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }.sheet(isPresented: $showAdd) { NavigationStack { MaintenanceRecordFormView() } } }
}

struct MaintenanceRecordRow: View { let record: MaintenanceRecord; var body: some View { VStack(alignment: .leading, spacing: 4) { Text(record.title).font(.headline); Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary); if !record.vendorName.isEmpty { Text(record.vendorName).font(.subheadline) }; if let cost = record.cost { Text(cost.formatted(AppFormatting.currency)).font(.subheadline.weight(.semibold)) } }.padding(.vertical, 2) } }

struct MaintenanceRecordDetailView: View {
    let record: MaintenanceRecord; @State private var showEdit = false
    var body: some View { List { Section("Record") { LabeledContent("Date", value: record.date.formatted(date: .long, time: .omitted)); if let cost = record.cost { LabeledContent("Cost", value: cost.formatted(AppFormatting.currency)) }; if !record.vendorName.isEmpty { LabeledContent("Vendor", value: record.vendorName) }; if !record.taskTitle.isEmpty { LabeledContent("Task", value: record.taskTitle) }; if !record.relatedItemName.isEmpty { LabeledContent("Related item", value: record.relatedItemName) } }; if !record.notes.isEmpty { Section("Notes") { Text(record.notes) } } }.navigationTitle(record.title).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }.sheet(isPresented: $showEdit) { NavigationStack { MaintenanceRecordFormView(existing: record) } } }
}

struct DetectorsListView: View {
    @Query(sort: \Detector.location) private var detectors: [Detector]; @State private var showAdd = false
    var body: some View { List { if detectors.isEmpty { ContentUnavailableView("No detectors yet", systemImage: "sensor.tag.radiowaves.forward", description: Text("Track detector locations, batteries, and ten-year replacement dates.")) }; ForEach(detectors) { detector in NavigationLink { DetectorDetailView(detector: detector) } label: { VStack(alignment: .leading, spacing: 4) { Text(detector.location).font(.headline); Text([detector.type, detector.manufacturer, detector.model].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary); if let date = detector.replacementDate { Text("Replace by \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) } } } } }.navigationTitle("Smoke & CO Detectors").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }.sheet(isPresented: $showAdd) { NavigationStack { DetectorFormView() } } }
}

struct DetectorDetailView: View { let detector: Detector; @State private var showEdit = false; var body: some View { List { Section("Detector") { LabeledContent("Type", value: detector.type); if !detector.manufacturer.isEmpty { LabeledContent("Manufacturer", value: detector.manufacturer) }; if !detector.model.isEmpty { LabeledContent("Model", value: detector.model) }; LabeledContent("Hardwired", value: detector.isHardwired ? "Yes" : "No"); if !detector.batteryType.isEmpty { LabeledContent("Battery", value: detector.batteryType) } }; Section("Dates") { if let d = detector.manufactureDate { LabeledContent("Manufactured", value: d.formatted(date: .abbreviated, time: .omitted)) }; if let d = detector.installationDate { LabeledContent("Installed", value: d.formatted(date: .abbreviated, time: .omitted)) }; if let d = detector.replacementDate { LabeledContent("Replace by", value: d.formatted(date: .long, time: .omitted)) } }; if !detector.notes.isEmpty { Section("Notes") { Text(detector.notes) } } }.navigationTitle(detector.location).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }.sheet(isPresented: $showEdit) { NavigationStack { DetectorFormView(existing: detector) } } } }

struct ConsumablesListView: View {
    @Query(sort: \Consumable.name) private var consumables: [Consumable]; @State private var showAdd = false
    var body: some View { List { if consumables.isEmpty { ContentUnavailableView("No consumables yet", systemImage: "shippingbox", description: Text("Add filters, batteries, humidifier pads, and other replacement supplies.")) }; ForEach(consumables) { item in NavigationLink { ConsumableDetailView(item: item) } label: { VStack(alignment: .leading, spacing: 4) { Text(item.name).font(.headline); Text([item.size, item.modelPartNumber].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary); if let date = item.nextReplacement { Text("Next replacement \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) } } } } }.navigationTitle("Consumables").toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }.sheet(isPresented: $showAdd) { NavigationStack { ConsumableFormView() } } }
}

struct ConsumableDetailView: View { let item: Consumable; @State private var showEdit = false; var body: some View { List { Section("Item") { if !item.type.isEmpty { LabeledContent("Type", value: item.type) }; if !item.size.isEmpty { LabeledContent("Size", value: item.size) }; if !item.manufacturer.isEmpty { LabeledContent("Manufacturer", value: item.manufacturer) }; if !item.modelPartNumber.isEmpty { LabeledContent("Part number", value: item.modelPartNumber) }; if !item.purchaseLink.isEmpty, let url = normalizedURL(item.purchaseLink) { Link("Purchase Link", destination: url) } }; Section("Replacement") { if let months = item.replacementIntervalMonths { LabeledContent("Interval", value: "Every \(months) months") }; if let date = item.lastReplaced { LabeledContent("Last replaced", value: date.formatted(date: .abbreviated, time: .omitted)) }; if let date = item.nextReplacement { LabeledContent("Next replacement", value: date.formatted(date: .long, time: .omitted)) } }; if !item.notes.isEmpty { Section("Notes") { Text(item.notes) } } }.navigationTitle(item.name).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }.sheet(isPresented: $showEdit) { NavigationStack { ConsumableFormView(existing: item) } } } }

private func normalizedURL(_ value: String) -> URL? { if let url = URL(string: value), url.scheme != nil { return url }; return URL(string: "https://\(value)") }
