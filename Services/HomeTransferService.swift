import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct HomeTransferArchive: Codable {
    let formatVersion: Int
    let appVersion: String
    let packageType: String
    let exportedAt: Date
    let home: TransferHome?
    let rooms: [TransferRoom]
    let vendors: [TransferVendor]
    let systems: [TransferSystem]
    let appliances: [TransferAppliance]
    let fixtures: [TransferFixture]
    let paints: [TransferPaint]
    let projects: [TransferProject]
    let projectItems: [TransferProjectItem]
    let measurements: [TransferMeasurement]
    let tasks: [TransferTask]
    let history: [TransferHistory]
    let detectors: [TransferDetector]
    let consumables: [TransferConsumable]
    let attachments: [TransferAttachment]
}

struct TransferHome: Codable { let id, name, address, notes: String; let yearBuilt, squareFeet: Int?; let purchaseDate: Date? }
struct TransferRoom: Codable {
    let id, name, notes, areaType: String
    let isFavorite: Bool
    var dimensionUnit: String? = nil
    var dimensionLength: Double? = nil
    var dimensionWidth: Double? = nil
    var ceilingHeight: Double? = nil
}
struct TransferVendor: Codable { let id, businessName, contactName, category, phone, email, website, address, notes: String; let isFavorite: Bool }
struct TransferSystem: Codable { let id, name, type, manufacturer, model, serialNumber, location, notes, website: String; let installationDate, warrantyExpiration: Date?; let purchaseCost: Double?; let expectedServiceLifeYears: Int?; let roomID, vendorID, sourceProjectID: String? }
struct TransferAppliance: Codable { let id, name, category, manufacturer, model, serialNumber, purchasedFrom, manufacturerWebsite, productRegistrationLink, notes: String; let purchaseDate, warrantyExpiration: Date?; let purchasePrice: Double?; let roomID, sourceProjectID: String? }
struct TransferFixture: Codable { let id, name, category, manufacturer, model, partNumber, finishColor, purchasedFrom, productLink, notes: String; let installationDate, purchaseDate, warrantyExpiration: Date?; let purchasePrice: Double?; let roomID, vendorID, sourceProjectID: String? }
struct TransferPaint: Codable { let id, roomName, surface, brand, productLine, colorName, colorCode, sheen, store, containerSize, notes, productLink: String; let purchaseDate: Date?; let quantity, cost: Double?; let roomID, sourceProjectID: String? }
struct TransferProject: Codable { let id, title, projectDescription, stage, notes, roomName: String; let targetDate: Date?; let budget: Double?; let roomID: String?; let coverPhotoData: Data? }
struct TransferProjectItem: Codable { let id, projectID, title, category, comparisonGroup, manufacturer, model, sku, finishColor, dimensions, store, website, notes, status: String; let unitCost, quantity, actualPurchaseCost: Double?; let purchaseDate, installedDate: Date?; let photoData: Data?; let isIdeaOnly: Bool }
struct TransferMeasurement: Codable { let id, projectID, name, unit, notes: String; let value: Double }
struct TransferTask: Codable { let id, title, taskDescription, category, recurrence, recurrenceAnchor, notes, instructions, contactName, phone, email, website: String; let dueDate, completedDate: Date?; let leadTimeDays, priority: Int; let isCompleted: Bool; let roomID, systemID, applianceID, fixtureID, projectID, vendorID: String? }
struct TransferHistory: Codable { let id, title, notes, vendorName, taskTitle, relatedItemName, eventType: String; let date: Date; let cost: Double?; let roomID, systemID, applianceID, fixtureID, projectID, vendorID: String? }
struct TransferDetector: Codable { let id, location, type, manufacturer, model, batteryType, notes: String; let manufactureDate, installationDate, replacementDate: Date?; let isHardwired: Bool }
struct TransferConsumable: Codable { let id, name, type, size, manufacturer, modelPartNumber, purchaseLink, notes: String; let replacementIntervalMonths: Int?; let lastReplaced, nextReplacement: Date? }
struct TransferAttachment: Codable { let id, name, caption, category, fileName, typeIdentifier: String; let createdAt: Date; let fileData: Data; let ownerType: String; let ownerID: String? }

struct TransferPreview {
    let homeName: String
    let address: String
    let exportedAt: Date
    let packageType: String
    let rooms: Int
    let assets: Int
    let projects: Int
    let tasks: Int
    let history: Int
    let attachments: Int
}

@MainActor
enum HomeTransferService {
    static func encodedArchive(context: ModelContext, packageType: String = "Owner Transfer") throws -> Data {
        let archive = try makeArchive(context: context, packageType: packageType)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> HomeTransferArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(HomeTransferArchive.self, from: data)
        guard archive.formatVersion == 1 else { throw TransferError.unsupportedVersion }
        try validateForImport(archive)
        return archive
    }

    static func preview(_ archive: HomeTransferArchive) -> TransferPreview {
        TransferPreview(
            homeName: archive.home?.name ?? "Home",
            address: archive.home?.address ?? "",
            exportedAt: archive.exportedAt,
            packageType: archive.packageType,
            rooms: archive.rooms.count,
            assets: archive.systems.count + archive.appliances.count + archive.fixtures.count + archive.paints.count + archive.detectors.count + archive.consumables.count,
            projects: archive.projects.count,
            tasks: archive.tasks.count,
            history: archive.history.count,
            attachments: archive.attachments.count
        )
    }

    static func validationWarnings(for archive: HomeTransferArchive) -> [String] {
        var warnings: [String] = []
        if archive.home == nil { warnings.append("The package does not contain a home profile.") }
        if archive.rooms.isEmpty { warnings.append("No rooms or areas are included.") }
        if archive.attachments.contains(where: { !$0.ownerType.isEmpty && $0.ownerID == nil }) {
            warnings.append("At least one attachment has no connected owner and will import as an unassigned file.")
        }
        return warnings
    }

    static func validateForImport(_ archive: HomeTransferArchive) throws {
        func requireUnique(_ ids: [String], label: String) throws {
            if Set(ids).count != ids.count { throw TransferError.invalidArchive("Duplicate IDs were found in \(label).") }
            if ids.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                throw TransferError.invalidArchive("A blank ID was found in \(label).")
            }
        }
        try requireUnique(archive.rooms.map(\.id), label: "rooms")
        try requireUnique(archive.vendors.map(\.id), label: "vendors")
        try requireUnique(archive.projects.map(\.id), label: "projects")
        try requireUnique(archive.systems.map(\.id), label: "systems")
        try requireUnique(archive.appliances.map(\.id), label: "devices and equipment")
        try requireUnique(archive.fixtures.map(\.id), label: "fixtures")
        try requireUnique(archive.paints.map(\.id), label: "paint and finishes")
        try requireUnique(archive.projectItems.map(\.id), label: "project items")
        try requireUnique(archive.tasks.map(\.id), label: "tasks")
        try requireUnique(archive.history.map(\.id), label: "history")
        try requireUnique(archive.attachments.map(\.id), label: "attachments")

        let roomIDs = Set(archive.rooms.map(\.id))
        let vendorIDs = Set(archive.vendors.map(\.id))
        let projectIDs = Set(archive.projects.map(\.id))
        let systemIDs = Set(archive.systems.map(\.id))
        let applianceIDs = Set(archive.appliances.map(\.id))
        let fixtureIDs = Set(archive.fixtures.map(\.id))
        let paintIDs = Set(archive.paints.map(\.id))
        let itemIDs = Set(archive.projectItems.map(\.id))
        let taskIDs = Set(archive.tasks.map(\.id))
        let historyIDs = Set(archive.history.map(\.id))
        let detectorIDs = Set(archive.detectors.map(\.id))
        let consumableIDs = Set(archive.consumables.map(\.id))

        func valid(_ id: String?, in set: Set<String>) -> Bool { id == nil || set.contains(id!) }
        guard archive.systems.allSatisfy({ valid($0.roomID, in: roomIDs) && valid($0.vendorID, in: vendorIDs) && valid($0.sourceProjectID, in: projectIDs) }) else { throw TransferError.invalidArchive("A home-system relationship points to a missing record.") }
        guard archive.appliances.allSatisfy({ valid($0.roomID, in: roomIDs) && valid($0.sourceProjectID, in: projectIDs) }) else { throw TransferError.invalidArchive("A device or equipment relationship points to a missing record.") }
        guard archive.fixtures.allSatisfy({ valid($0.roomID, in: roomIDs) && valid($0.vendorID, in: vendorIDs) && valid($0.sourceProjectID, in: projectIDs) }) else { throw TransferError.invalidArchive("A fixture relationship points to a missing record.") }
        guard archive.paints.allSatisfy({ valid($0.roomID, in: roomIDs) && valid($0.sourceProjectID, in: projectIDs) }) else { throw TransferError.invalidArchive("A paint relationship points to a missing record.") }
        guard archive.projects.allSatisfy({ valid($0.roomID, in: roomIDs) }) else { throw TransferError.invalidArchive("A project points to a missing room or area.") }
        guard archive.projectItems.allSatisfy({ projectIDs.contains($0.projectID) }) else { throw TransferError.invalidArchive("A project item points to a missing project.") }
        guard archive.measurements.allSatisfy({ projectIDs.contains($0.projectID) }) else { throw TransferError.invalidArchive("A measurement points to a missing project.") }
        guard archive.tasks.allSatisfy({ valid($0.roomID, in: roomIDs) && valid($0.systemID, in: systemIDs) && valid($0.applianceID, in: applianceIDs) && valid($0.fixtureID, in: fixtureIDs) && valid($0.projectID, in: projectIDs) && valid($0.vendorID, in: vendorIDs) }) else { throw TransferError.invalidArchive("A task relationship points to a missing record.") }
        guard archive.history.allSatisfy({ valid($0.roomID, in: roomIDs) && valid($0.systemID, in: systemIDs) && valid($0.applianceID, in: applianceIDs) && valid($0.fixtureID, in: fixtureIDs) && valid($0.projectID, in: projectIDs) && valid($0.vendorID, in: vendorIDs) }) else { throw TransferError.invalidArchive("A history relationship points to a missing record.") }

        let owners: [String: Set<String>] = [
            "room": roomIDs, "vendor": vendorIDs, "system": systemIDs, "appliance": applianceIDs,
            "fixture": fixtureIDs, "paint": paintIDs, "project": projectIDs, "projectItem": itemIDs,
            "task": taskIDs, "history": historyIDs, "detector": detectorIDs, "consumable": consumableIDs
        ]
        for attachment in archive.attachments where !attachment.ownerType.isEmpty {
            guard let ownerID = attachment.ownerID, let allowed = owners[attachment.ownerType], allowed.contains(ownerID) else {
                throw TransferError.invalidArchive("An attachment points to a missing or unsupported owner.")
            }
        }
    }

    static func isStoreEmpty(context: ModelContext) throws -> Bool {
        let counts = [
            try context.fetchCount(FetchDescriptor<Home>()),
            try context.fetchCount(FetchDescriptor<Room>()),
            try context.fetchCount(FetchDescriptor<Vendor>()),
            try context.fetchCount(FetchDescriptor<HomeSystem>()),
            try context.fetchCount(FetchDescriptor<Appliance>()),
            try context.fetchCount(FetchDescriptor<Fixture>()),
            try context.fetchCount(FetchDescriptor<PaintFinish>()),
            try context.fetchCount(FetchDescriptor<Project>()),
            try context.fetchCount(FetchDescriptor<ProjectItem>()),
            try context.fetchCount(FetchDescriptor<ProjectMeasurement>()),
            try context.fetchCount(FetchDescriptor<MaintenanceTask>()),
            try context.fetchCount(FetchDescriptor<MaintenanceRecord>()),
            try context.fetchCount(FetchDescriptor<Detector>()),
            try context.fetchCount(FetchDescriptor<Consumable>()),
            try context.fetchCount(FetchDescriptor<HomeAttachment>())
        ]
        return counts.allSatisfy { $0 == 0 }
    }

    static func importIntoEmptyStore(_ archive: HomeTransferArchive, context: ModelContext) throws {
        try validateForImport(archive)
        guard try isStoreEmpty(context: context) else { throw TransferError.storeNotEmpty }

        var rooms: [String: Room] = [:]
        var vendors: [String: Vendor] = [:]
        var projects: [String: Project] = [:]
        var systems: [String: HomeSystem] = [:]
        var appliances: [String: Appliance] = [:]
        var fixtures: [String: Fixture] = [:]
        var paints: [String: PaintFinish] = [:]
        var tasks: [String: MaintenanceTask] = [:]
        var history: [String: MaintenanceRecord] = [:]
        var detectors: [String: Detector] = [:]
        var consumables: [String: Consumable] = [:]
        var projectItems: [String: ProjectItem] = [:]

        if let h = archive.home {
            context.insert(Home(name: h.name, address: h.address, yearBuilt: h.yearBuilt, purchaseDate: h.purchaseDate, squareFeet: h.squareFeet, notes: h.notes))
        }
        for r in archive.rooms {
            let item = Room(
                name: r.name,
                notes: r.notes,
                isFavorite: r.isFavorite,
                areaType: HomeAreaType(rawValue: r.areaType) ?? .interior,
                dimensionUnit: RoomDimensionUnit(rawValue: r.dimensionUnit ?? "") ?? .feet,
                dimensionLength: r.dimensionLength,
                dimensionWidth: r.dimensionWidth,
                ceilingHeight: r.ceilingHeight
            )
            context.insert(item); rooms[r.id] = item
        }
        for v in archive.vendors {
            let item = Vendor(businessName: v.businessName, contactName: v.contactName, category: v.category, phone: v.phone, email: v.email, website: v.website, address: v.address, notes: v.notes, isFavorite: v.isFavorite)
            context.insert(item); vendors[v.id] = item
        }
        for p in archive.projects {
            let item = Project(title: p.title, projectDescription: p.projectDescription, stage: ProjectStage(rawValue: p.stage) ?? .idea, targetDate: p.targetDate, budget: p.budget, notes: p.notes, roomName: p.roomName, room: p.roomID.flatMap { rooms[$0] }, coverPhotoData: p.coverPhotoData)
            context.insert(item); projects[p.id] = item
        }
        for s in archive.systems {
            let item = HomeSystem(name: s.name, type: s.type, manufacturer: s.manufacturer, model: s.model, serialNumber: s.serialNumber, installationDate: s.installationDate, purchaseCost: s.purchaseCost, warrantyExpiration: s.warrantyExpiration, expectedServiceLifeYears: s.expectedServiceLifeYears, location: s.location, notes: s.notes, website: s.website, vendor: s.vendorID.flatMap { vendors[$0] }, room: s.roomID.flatMap { rooms[$0] }, sourceProject: s.sourceProjectID.flatMap { projects[$0] })
            context.insert(item); systems[s.id] = item
        }
        for a in archive.appliances {
            let item = Appliance(name: a.name, category: a.category, manufacturer: a.manufacturer, model: a.model, serialNumber: a.serialNumber, purchaseDate: a.purchaseDate, purchasePrice: a.purchasePrice, purchasedFrom: a.purchasedFrom, warrantyExpiration: a.warrantyExpiration, manufacturerWebsite: a.manufacturerWebsite, productRegistrationLink: a.productRegistrationLink, notes: a.notes, room: a.roomID.flatMap { rooms[$0] }, sourceProject: a.sourceProjectID.flatMap { projects[$0] })
            context.insert(item); appliances[a.id] = item
        }
        for f in archive.fixtures {
            let item = Fixture(name: f.name, category: f.category, manufacturer: f.manufacturer, model: f.model, partNumber: f.partNumber, finishColor: f.finishColor, installationDate: f.installationDate, purchaseDate: f.purchaseDate, purchasePrice: f.purchasePrice, purchasedFrom: f.purchasedFrom, warrantyExpiration: f.warrantyExpiration, productLink: f.productLink, notes: f.notes, room: f.roomID.flatMap { rooms[$0] }, vendor: f.vendorID.flatMap { vendors[$0] }, sourceProject: f.sourceProjectID.flatMap { projects[$0] })
            context.insert(item); fixtures[f.id] = item
        }
        for p in archive.paints {
            let item = PaintFinish(roomName: p.roomName, room: p.roomID.flatMap { rooms[$0] }, surface: p.surface, brand: p.brand, productLine: p.productLine, colorName: p.colorName, colorCode: p.colorCode, sheen: p.sheen, store: p.store, purchaseDate: p.purchaseDate, quantity: p.quantity, containerSize: p.containerSize, cost: p.cost, notes: p.notes, productLink: p.productLink, sourceProject: p.sourceProjectID.flatMap { projects[$0] })
            context.insert(item); paints[p.id] = item
        }
        for d in archive.detectors {
            let item = Detector(location: d.location, type: d.type, manufacturer: d.manufacturer, model: d.model, manufactureDate: d.manufactureDate, installationDate: d.installationDate, batteryType: d.batteryType, isHardwired: d.isHardwired, replacementDate: d.replacementDate, notes: d.notes)
            context.insert(item); detectors[d.id] = item
        }
        for c in archive.consumables {
            let item = Consumable(name: c.name, type: c.type, size: c.size, manufacturer: c.manufacturer, modelPartNumber: c.modelPartNumber, purchaseLink: c.purchaseLink, replacementIntervalMonths: c.replacementIntervalMonths, lastReplaced: c.lastReplaced, nextReplacement: c.nextReplacement, notes: c.notes)
            context.insert(item); consumables[c.id] = item
        }
        for i in archive.projectItems {
            let item = ProjectItem(project: projects[i.projectID], title: i.title, category: i.category, comparisonGroup: i.comparisonGroup.isEmpty ? nil : i.comparisonGroup, manufacturer: i.manufacturer, model: i.model, sku: i.sku, finishColor: i.finishColor, dimensions: i.dimensions, store: i.store, website: i.website, unitCost: i.unitCost, quantity: i.quantity ?? 1, actualPurchaseCost: i.actualPurchaseCost, purchaseDate: i.purchaseDate, installedDate: i.installedDate, notes: i.notes, status: ProjectItemStatus(rawValue: i.status) ?? .considering, photoData: i.photoData, isIdeaOnly: i.isIdeaOnly)
            context.insert(item); projectItems[i.id] = item
        }
        for m in archive.measurements {
            context.insert(ProjectMeasurement(project: projects[m.projectID], name: m.name, value: m.value, unit: m.unit, notes: m.notes))
        }
        for t in archive.tasks {
            let item = MaintenanceTask(title: t.title, taskDescription: t.taskDescription, category: TaskCategory(rawValue: t.category) ?? .general, dueDate: t.dueDate ?? .now, leadTimeDays: t.leadTimeDays, recurrence: RecurrenceRule(rawValue: t.recurrence) ?? .oneTime, recurrenceAnchor: RecurrenceAnchor(rawValue: t.recurrenceAnchor) ?? .scheduledDate, priority: t.priority, notes: t.notes, instructions: t.instructions, contactName: t.contactName, phone: t.phone, email: t.email, website: t.website, room: t.roomID.flatMap { rooms[$0] }, system: t.systemID.flatMap { systems[$0] }, appliance: t.applianceID.flatMap { appliances[$0] }, fixture: t.fixtureID.flatMap { fixtures[$0] }, project: t.projectID.flatMap { projects[$0] }, vendor: t.vendorID.flatMap { vendors[$0] })
            item.isCompleted = t.isCompleted; item.completedDate = t.completedDate
            context.insert(item); tasks[t.id] = item
        }
        for h in archive.history {
            let item = MaintenanceRecord(date: h.date, title: h.title, cost: h.cost, notes: h.notes, vendorName: h.vendorName, taskTitle: h.taskTitle, relatedItemName: h.relatedItemName, eventType: HomeEventType(rawValue: h.eventType) ?? .maintenance, room: h.roomID.flatMap { rooms[$0] }, system: h.systemID.flatMap { systems[$0] }, appliance: h.applianceID.flatMap { appliances[$0] }, fixture: h.fixtureID.flatMap { fixtures[$0] }, project: h.projectID.flatMap { projects[$0] }, vendor: h.vendorID.flatMap { vendors[$0] })
            context.insert(item); history[h.id] = item
        }
        for a in archive.attachments {
            let item = HomeAttachment(name: a.name, caption: a.caption, category: a.category, fileName: a.fileName, typeIdentifier: a.typeIdentifier, createdAt: a.createdAt, fileData: a.fileData)
            switch a.ownerType {
            case "room": item.room = a.ownerID.flatMap { rooms[$0] }
            case "vendor": item.vendor = a.ownerID.flatMap { vendors[$0] }
            case "system": item.system = a.ownerID.flatMap { systems[$0] }
            case "appliance": item.appliance = a.ownerID.flatMap { appliances[$0] }
            case "fixture": item.fixture = a.ownerID.flatMap { fixtures[$0] }
            case "paint": item.paint = a.ownerID.flatMap { paints[$0] }
            case "project": item.project = a.ownerID.flatMap { projects[$0] }
            case "projectItem": item.projectItem = a.ownerID.flatMap { projectItems[$0] }
            case "task": item.task = a.ownerID.flatMap { tasks[$0] }
            case "history": item.maintenanceRecord = a.ownerID.flatMap { history[$0] }
            case "detector": item.detector = a.ownerID.flatMap { detectors[$0] }
            case "consumable": item.consumable = a.ownerID.flatMap { consumables[$0] }
            default: break
            }
            context.insert(item)
        }
        try context.save()
    }

    private static func makeArchive(context: ModelContext, packageType: String) throws -> HomeTransferArchive {
        let homes = try context.fetch(FetchDescriptor<Home>())
        let rooms = try context.fetch(FetchDescriptor<Room>())
        let vendors = try context.fetch(FetchDescriptor<Vendor>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        let systems = try context.fetch(FetchDescriptor<HomeSystem>())
        let appliances = try context.fetch(FetchDescriptor<Appliance>())
        let fixtures = try context.fetch(FetchDescriptor<Fixture>())
        let paints = try context.fetch(FetchDescriptor<PaintFinish>())
        let tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())
        let history = try context.fetch(FetchDescriptor<MaintenanceRecord>())
        let detectors = try context.fetch(FetchDescriptor<Detector>())
        let consumables = try context.fetch(FetchDescriptor<Consumable>())
        let projectItems = try context.fetch(FetchDescriptor<ProjectItem>())
        let measurements = try context.fetch(FetchDescriptor<ProjectMeasurement>())
        let attachments = try context.fetch(FetchDescriptor<HomeAttachment>())

        func idMap<T: PersistentModel>(_ values: [T]) -> [PersistentIdentifier: String] {
            Dictionary(uniqueKeysWithValues: values.map { ($0.persistentModelID, UUID().uuidString) })
        }
        let roomIDs = idMap(rooms), vendorIDs = idMap(vendors), projectIDs = idMap(projects), systemIDs = idMap(systems), applianceIDs = idMap(appliances), fixtureIDs = idMap(fixtures), paintIDs = idMap(paints), taskIDs = idMap(tasks), historyIDs = idMap(history), detectorIDs = idMap(detectors), consumableIDs = idMap(consumables), projectItemIDs = idMap(projectItems)
        func rid<T: PersistentModel>(_ object: T?, _ map: [PersistentIdentifier: String]) -> String? { object.flatMap { map[$0.persistentModelID] } }

        let h = homes.first.map { TransferHome(id: UUID().uuidString, name: $0.name, address: $0.address, notes: $0.notes, yearBuilt: $0.yearBuilt, squareFeet: $0.squareFeet, purchaseDate: $0.purchaseDate) }
        let attachmentDTOs = attachments.map { a -> TransferAttachment in
            var type = "", owner: String?
            if let v = a.room { type = "room"; owner = rid(v, roomIDs) }
            else if let v = a.vendor { type = "vendor"; owner = rid(v, vendorIDs) }
            else if let v = a.system { type = "system"; owner = rid(v, systemIDs) }
            else if let v = a.appliance { type = "appliance"; owner = rid(v, applianceIDs) }
            else if let v = a.fixture { type = "fixture"; owner = rid(v, fixtureIDs) }
            else if let v = a.paint { type = "paint"; owner = rid(v, paintIDs) }
            else if let v = a.project { type = "project"; owner = rid(v, projectIDs) }
            else if let v = a.projectItem { type = "projectItem"; owner = rid(v, projectItemIDs) }
            else if let v = a.task { type = "task"; owner = rid(v, taskIDs) }
            else if let v = a.maintenanceRecord { type = "history"; owner = rid(v, historyIDs) }
            else if let v = a.detector { type = "detector"; owner = rid(v, detectorIDs) }
            else if let v = a.consumable { type = "consumable"; owner = rid(v, consumableIDs) }
            return .init(id: UUID().uuidString, name: a.name, caption: a.caption, category: a.category, fileName: a.fileName, typeIdentifier: a.typeIdentifier, createdAt: a.createdAt, fileData: a.fileData, ownerType: type, ownerID: owner)
        }

        return HomeTransferArchive(
            formatVersion: 1, appVersion: "0.22", packageType: packageType, exportedAt: .now, home: h,
            rooms: rooms.map { .init(
                id: roomIDs[$0.persistentModelID]!,
                name: $0.name,
                notes: $0.notes,
                areaType: $0.areaType.rawValue,
                isFavorite: $0.isFavorite,
                dimensionUnit: $0.dimensionUnit.rawValue,
                dimensionLength: $0.dimensionLength,
                dimensionWidth: $0.dimensionWidth,
                ceilingHeight: $0.ceilingHeight
            ) },
            vendors: vendors.map { .init(id: vendorIDs[$0.persistentModelID]!, businessName: $0.businessName, contactName: $0.contactName, category: $0.category, phone: $0.phone, email: $0.email, website: $0.website, address: $0.address, notes: $0.notes, isFavorite: $0.isFavorite) },
            systems: systems.map { .init(id: systemIDs[$0.persistentModelID]!, name: $0.name, type: $0.type, manufacturer: $0.manufacturer, model: $0.model, serialNumber: $0.serialNumber, location: $0.location, notes: $0.notes, website: $0.website, installationDate: $0.installationDate, warrantyExpiration: $0.warrantyExpiration, purchaseCost: $0.purchaseCost, expectedServiceLifeYears: $0.expectedServiceLifeYears, roomID: rid($0.room, roomIDs), vendorID: rid($0.vendor, vendorIDs), sourceProjectID: rid($0.sourceProject, projectIDs)) },
            appliances: appliances.map { .init(id: applianceIDs[$0.persistentModelID]!, name: $0.name, category: $0.category, manufacturer: $0.manufacturer, model: $0.model, serialNumber: $0.serialNumber, purchasedFrom: $0.purchasedFrom, manufacturerWebsite: $0.manufacturerWebsite, productRegistrationLink: $0.productRegistrationLink, notes: $0.notes, purchaseDate: $0.purchaseDate, warrantyExpiration: $0.warrantyExpiration, purchasePrice: $0.purchasePrice, roomID: rid($0.room, roomIDs), sourceProjectID: rid($0.sourceProject, projectIDs)) },
            fixtures: fixtures.map { .init(id: fixtureIDs[$0.persistentModelID]!, name: $0.name, category: $0.category, manufacturer: $0.manufacturer, model: $0.model, partNumber: $0.partNumber, finishColor: $0.finishColor, purchasedFrom: $0.purchasedFrom, productLink: $0.productLink, notes: $0.notes, installationDate: $0.installationDate, purchaseDate: $0.purchaseDate, warrantyExpiration: $0.warrantyExpiration, purchasePrice: $0.purchasePrice, roomID: rid($0.room, roomIDs), vendorID: rid($0.vendor, vendorIDs), sourceProjectID: rid($0.sourceProject, projectIDs)) },
            paints: paints.map { .init(id: paintIDs[$0.persistentModelID]!, roomName: $0.roomName, surface: $0.surface, brand: $0.brand, productLine: $0.productLine, colorName: $0.colorName, colorCode: $0.colorCode, sheen: $0.sheen, store: $0.store, containerSize: $0.containerSize, notes: $0.notes, productLink: $0.productLink, purchaseDate: $0.purchaseDate, quantity: $0.quantity, cost: $0.cost, roomID: rid($0.room, roomIDs), sourceProjectID: rid($0.sourceProject, projectIDs)) },
            projects: projects.map { .init(id: projectIDs[$0.persistentModelID]!, title: $0.title, projectDescription: $0.projectDescription, stage: $0.stage.rawValue, notes: $0.notes, roomName: $0.roomName, targetDate: $0.targetDate, budget: $0.budget, roomID: rid($0.room, roomIDs), coverPhotoData: $0.coverPhotoData) },
            projectItems: projectItems.map { .init(id: projectItemIDs[$0.persistentModelID]!, projectID: rid($0.project, projectIDs) ?? "", title: $0.title, category: $0.category, comparisonGroup: $0.comparisonGroup ?? "", manufacturer: $0.manufacturer, model: $0.model, sku: $0.sku, finishColor: $0.finishColor, dimensions: $0.dimensions, store: $0.store, website: $0.website, notes: $0.notes, status: $0.status.rawValue, unitCost: $0.unitCost, quantity: $0.quantity, actualPurchaseCost: $0.actualPurchaseCost, purchaseDate: $0.purchaseDate, installedDate: $0.installedDate, photoData: $0.photoData, isIdeaOnly: $0.isIdeaOnly) },
            measurements: measurements.map { .init(id: UUID().uuidString, projectID: rid($0.project, projectIDs) ?? "", name: $0.name, unit: $0.unit, notes: $0.notes, value: $0.value) },
            tasks: tasks.map { .init(id: taskIDs[$0.persistentModelID]!, title: $0.title, taskDescription: $0.taskDescription, category: $0.category.rawValue, recurrence: $0.recurrence.rawValue, recurrenceAnchor: $0.recurrenceAnchor.rawValue, notes: $0.notes, instructions: $0.instructions, contactName: $0.contactName, phone: $0.phone, email: $0.email, website: $0.website, dueDate: $0.dueDate, completedDate: $0.completedDate, leadTimeDays: $0.leadTimeDays, priority: $0.priority, isCompleted: $0.isCompleted, roomID: rid($0.room, roomIDs), systemID: rid($0.system, systemIDs), applianceID: rid($0.appliance, applianceIDs), fixtureID: rid($0.fixture, fixtureIDs), projectID: rid($0.project, projectIDs), vendorID: rid($0.vendor, vendorIDs)) },
            history: history.map { .init(id: historyIDs[$0.persistentModelID]!, title: $0.title, notes: $0.notes, vendorName: $0.vendorName, taskTitle: $0.taskTitle, relatedItemName: $0.relatedItemName, eventType: $0.eventType.rawValue, date: $0.date, cost: $0.cost, roomID: rid($0.room, roomIDs), systemID: rid($0.system, systemIDs), applianceID: rid($0.appliance, applianceIDs), fixtureID: rid($0.fixture, fixtureIDs), projectID: rid($0.project, projectIDs), vendorID: rid($0.vendor, vendorIDs)) },
            detectors: detectors.map { .init(id: detectorIDs[$0.persistentModelID]!, location: $0.location, type: $0.type, manufacturer: $0.manufacturer, model: $0.model, batteryType: $0.batteryType, notes: $0.notes, manufactureDate: $0.manufactureDate, installationDate: $0.installationDate, replacementDate: $0.replacementDate, isHardwired: $0.isHardwired) },
            consumables: consumables.map { .init(id: consumableIDs[$0.persistentModelID]!, name: $0.name, type: $0.type, size: $0.size, manufacturer: $0.manufacturer, modelPartNumber: $0.modelPartNumber, purchaseLink: $0.purchaseLink, notes: $0.notes, replacementIntervalMonths: $0.replacementIntervalMonths, lastReplaced: $0.lastReplaced, nextReplacement: $0.nextReplacement) },
            attachments: attachmentDTOs
        )
    }
}

enum TransferError: LocalizedError {
    case unsupportedVersion
    case storeNotEmpty
    case invalidArchive(String)
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This transfer package was created by an unsupported archive format."
        case .storeNotEmpty: return "For safety, a home transfer can only be imported into a fresh Home Maintainer data store."
        case .invalidArchive(let detail): return "This transfer package did not pass its integrity check. \(detail)"
        }
    }
}

struct HomeTransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data = Data()
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
