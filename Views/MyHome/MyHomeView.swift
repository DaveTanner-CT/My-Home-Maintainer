import SwiftUI
import SwiftData

struct MyHomeView: View {
    @Query private var records: [MaintenanceRecord]

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
                NavigationLink { MaintenanceHistoryView() } label: {
                    Label("Maintenance History", systemImage: "clock.arrow.circlepath")
                }
                LabeledContent("Recorded events", value: "\(records.count)")
            }
        }
        .navigationTitle("My Home")
    }
}

struct RoomsListView: View {
    @Query(sort: \Room.name) private var rooms: [Room]
    @State private var showAdd = false

    var body: some View {
        List(rooms) { room in
            HStack {
                Image(systemName: "door.left.hand.open").foregroundStyle(.secondary)
                Text(room.name)
                Spacer()
                if room.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            }
        }
        .navigationTitle("Rooms & Areas")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { RoomFormView() } }
    }
}

struct SystemsListView: View {
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @State private var showAdd = false

    var body: some View {
        List(systems) { system in
            NavigationLink { SystemDetailView(system: system) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(system.name).font(.headline)
                    Text([system.type, system.location].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Home Systems")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { SystemFormView() } }
    }
}

struct SystemDetailView: View {
    let system: HomeSystem

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
                if let years = system.expectedServiceLifeYears { LabeledContent("Expected service life", value: "~\(years) years") }
                if let vendor = system.vendor { LabeledContent("Vendor", value: vendor.businessName) }
            }
            if !system.notes.isEmpty { Section("Notes") { Text(system.notes) } }
        }
        .navigationTitle(system.name)
    }
}

struct AppliancesListView: View {
    @Query(sort: \Appliance.name) private var appliances: [Appliance]
    @State private var showAdd = false

    var body: some View {
        List(appliances) { appliance in
            NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appliance.name).font(.headline)
                    Text([appliance.manufacturer, appliance.model].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Appliances")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { ApplianceFormView() } }
    }
}

struct ApplianceDetailView: View {
    let appliance: Appliance

    var body: some View {
        List {
            Section("Appliance") {
                LabeledContent("Category", value: appliance.category)
                if !appliance.manufacturer.isEmpty { LabeledContent("Manufacturer", value: appliance.manufacturer) }
                if !appliance.model.isEmpty { LabeledContent("Model", value: appliance.model) }
                if !appliance.serialNumber.isEmpty { LabeledContent("Serial", value: appliance.serialNumber) }
                if let room = appliance.room { LabeledContent("Room", value: room.name) }
            }
            Section("Purchase & Warranty") {
                if let date = appliance.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }
                if let price = appliance.purchasePrice { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
                if !appliance.purchasedFrom.isEmpty { LabeledContent("Store", value: appliance.purchasedFrom) }
                if let warranty = appliance.warrantyExpiration { LabeledContent("Warranty", value: warranty.formatted(date: .abbreviated, time: .omitted)) }
            }
            if !appliance.notes.isEmpty { Section("Notes") { Text(appliance.notes) } }
        }
        .navigationTitle(appliance.name)
    }
}

struct PaintListView: View {
    @Query(sort: \PaintFinish.roomName) private var paints: [PaintFinish]
    @State private var showAdd = false

    var body: some View {
        List(paints) { paint in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(paint.roomName) · \(paint.surface)").font(.headline)
                Text([paint.brand, paint.colorName, paint.colorCode].filter { !$0.isEmpty }.joined(separator: " · "))
                if !paint.sheen.isEmpty || !paint.store.isEmpty {
                    Text([paint.sheen, paint.store].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Paint & Finishes")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { PaintFormView() } }
    }
}

struct VendorsListView: View {
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]
    @State private var showAdd = false

    var body: some View {
        List(vendors) { vendor in
            VendorRow(vendor: vendor)
        }
        .navigationTitle("Vendors")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { VendorFormView() } }
    }
}

struct VendorRow: View {
    let vendor: Vendor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(vendor.businessName).font(.headline)
                if vendor.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            }
            Text([vendor.category, vendor.contactName].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                if !vendor.phone.isEmpty, let url = URL(string: "tel:\(vendor.phone.filter { $0.isNumber })") { Link("Call", destination: url) }
                if !vendor.email.isEmpty, let url = URL(string: "mailto:\(vendor.email)") { Link("Email", destination: url) }
                if !vendor.website.isEmpty, let url = URL(string: vendor.website) { Link("Website", destination: url) }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 3)
    }
}

struct MaintenanceHistoryView: View {
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var records: [MaintenanceRecord]

    var body: some View {
        List(records) { record in
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title).font(.headline)
                Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                if !record.vendorName.isEmpty { Text(record.vendorName).font(.subheadline) }
                if let cost = record.cost { Text(cost.formatted(AppFormatting.currency)).font(.subheadline.weight(.semibold)) }
                if !record.notes.isEmpty { Text(record.notes).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Maintenance History")
    }
}

struct DetectorsListView: View {
    @Query(sort: \Detector.location) private var detectors: [Detector]
    @State private var showAdd = false

    var body: some View {
        List {
            if detectors.isEmpty {
                Text("Add smoke and CO detectors to track location, battery type, and ten-year replacement dates.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(detectors) { detector in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detector.location).font(.headline)
                        Text([detector.type, detector.manufacturer, detector.model].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        if let date = detector.replacementDate { Text("Replace by \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                    }
                }
            }
        }
        .navigationTitle("Smoke & CO Detectors")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { DetectorFormView() } }
    }
}

struct ConsumablesListView: View {
    @Query(sort: \Consumable.name) private var consumables: [Consumable]
    @State private var showAdd = false

    var body: some View {
        List {
            if consumables.isEmpty {
                Text("Add filters, batteries, humidifier pads, and other replacement supplies.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(consumables) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.headline)
                        Text([item.size, item.modelPartNumber].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        if let date = item.nextReplacement { Text("Next replacement \(date.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                    }
                }
            }
        }
        .navigationTitle("Consumables")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { NavigationStack { ConsumableFormView() } }
    }
}
