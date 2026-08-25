import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

struct HomeArchive: Codable {
    var exportedAt: Date
    var appVersion: String
    var homes: [HomeSnapshot]
    var rooms: [RoomSnapshot]
    var vendors: [VendorSnapshot]
    var systems: [SystemSnapshot]
    var appliances: [ApplianceSnapshot]
    var paint: [PaintSnapshot]
    var fixtures: [FixtureSnapshot]
    var tasks: [TaskSnapshot]
    var maintenanceRecords: [MaintenanceRecordSnapshot]
    var detectors: [DetectorSnapshot]
    var consumables: [ConsumableSnapshot]
    var projects: [ProjectSnapshot]
    var projectItems: [ProjectItemSnapshot]
    var measurements: [MeasurementSnapshot]
    var attachments: [AttachmentSnapshot]
}

struct HomeSnapshot: Codable { let name, address, notes: String; let yearBuilt, squareFeet: Int?; let purchaseDate: Date? }
struct RoomSnapshot: Codable { let name, notes, areaType: String; let isFavorite: Bool }
struct VendorSnapshot: Codable { let businessName, contactName, category, phone, email, website, address, notes: String; let isFavorite: Bool }
struct SystemSnapshot: Codable { let name, type, manufacturer, model, serialNumber, location, roomName, notes, website, vendorName, sourceProjectName: String; let installationDate, warrantyExpiration: Date?; let purchaseCost: Double?; let expectedServiceLifeYears: Int? }
struct ApplianceSnapshot: Codable { let name, category, manufacturer, model, serialNumber, purchasedFrom, manufacturerWebsite, productRegistrationLink, notes, roomName, sourceProjectName: String; let purchaseDate, warrantyExpiration: Date?; let purchasePrice: Double? }
struct FixtureSnapshot: Codable { let name, category, manufacturer, model, partNumber, finishColor, purchasedFrom, productLink, notes, roomName, vendorName, sourceProjectName: String; let installationDate, purchaseDate, warrantyExpiration: Date?; let purchasePrice: Double? }
struct PaintSnapshot: Codable { let roomName, surface, brand, productLine, colorName, colorCode, sheen, store, containerSize, notes, productLink, sourceProjectName: String; let purchaseDate: Date?; let quantity, cost: Double? }
struct TaskSnapshot: Codable { let title, taskDescription, category, recurrence, recurrenceAnchor, notes, instructions, contactName, phone, email, website, roomName, systemName, applianceName, fixtureName, projectName, vendorName: String; let dueDate, completedDate: Date?; let leadTimeDays, priority: Int; let isCompleted: Bool }
struct MaintenanceRecordSnapshot: Codable { let date: Date; let title, notes, vendorName, taskTitle, relatedItemName, eventType, roomName, systemName, applianceName, fixtureName, projectName: String; let cost: Double? }
struct DetectorSnapshot: Codable { let location, type, manufacturer, model, batteryType, notes: String; let manufactureDate, installationDate, replacementDate: Date?; let isHardwired: Bool }
struct ConsumableSnapshot: Codable { let name, type, size, manufacturer, modelPartNumber, purchaseLink, notes: String; let replacementIntervalMonths: Int?; let lastReplaced, nextReplacement: Date? }
struct ProjectSnapshot: Codable { let title, projectDescription, stage, notes, roomName: String; let targetDate: Date?; let budget: Double? }
struct ProjectItemSnapshot: Codable { let projectName, title, category, comparisonGroup, manufacturer, model, sku, finishColor, dimensions, store, website, notes, status: String; let unitCost, quantity, actualPurchaseCost: Double?; let purchaseDate, installedDate: Date?; let isIdeaOnly: Bool }
struct MeasurementSnapshot: Codable { let projectName, name, unit, notes: String; let value: Double }
struct AttachmentSnapshot: Codable { let name, caption, category, fileName, typeIdentifier, ownerType, ownerName: String; let createdAt: Date; let fileData: Data }

@MainActor
enum HomeExportService {
    static func makeArchive(context: ModelContext) throws -> HomeArchive {
        let homes = try context.fetch(FetchDescriptor<Home>())
        let rooms = try context.fetch(FetchDescriptor<Room>())
        let vendors = try context.fetch(FetchDescriptor<Vendor>())
        let systems = try context.fetch(FetchDescriptor<HomeSystem>())
        let appliances = try context.fetch(FetchDescriptor<Appliance>())
        let paints = try context.fetch(FetchDescriptor<PaintFinish>())
        let fixtures = try context.fetch(FetchDescriptor<Fixture>())
        let tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())
        let records = try context.fetch(FetchDescriptor<MaintenanceRecord>())
        let detectors = try context.fetch(FetchDescriptor<Detector>())
        let consumables = try context.fetch(FetchDescriptor<Consumable>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        let items = try context.fetch(FetchDescriptor<ProjectItem>())
        let measurements = try context.fetch(FetchDescriptor<ProjectMeasurement>())
        let attachments = try context.fetch(FetchDescriptor<HomeAttachment>())

        return HomeArchive(
            exportedAt: .now,
            appVersion: "0.12",
            homes: homes.map { .init(name: $0.name, address: $0.address, notes: $0.notes, yearBuilt: $0.yearBuilt, squareFeet: $0.squareFeet, purchaseDate: $0.purchaseDate) },
            rooms: rooms.map { .init(name: $0.name, notes: $0.notes, areaType: $0.areaType.rawValue, isFavorite: $0.isFavorite) },
            vendors: vendors.map { .init(businessName: $0.businessName, contactName: $0.contactName, category: $0.category, phone: $0.phone, email: $0.email, website: $0.website, address: $0.address, notes: $0.notes, isFavorite: $0.isFavorite) },
            systems: systems.map { .init(name: $0.name, type: $0.type, manufacturer: $0.manufacturer, model: $0.model, serialNumber: $0.serialNumber, location: $0.location, roomName: $0.room?.name ?? "", notes: $0.notes, website: $0.website, vendorName: $0.vendor?.businessName ?? "", sourceProjectName: $0.sourceProject?.title ?? "", installationDate: $0.installationDate, warrantyExpiration: $0.warrantyExpiration, purchaseCost: $0.purchaseCost, expectedServiceLifeYears: $0.expectedServiceLifeYears) },
            appliances: appliances.map { .init(name: $0.name, category: $0.category, manufacturer: $0.manufacturer, model: $0.model, serialNumber: $0.serialNumber, purchasedFrom: $0.purchasedFrom, manufacturerWebsite: $0.manufacturerWebsite, productRegistrationLink: $0.productRegistrationLink, notes: $0.notes, roomName: $0.room?.name ?? "", sourceProjectName: $0.sourceProject?.title ?? "", purchaseDate: $0.purchaseDate, warrantyExpiration: $0.warrantyExpiration, purchasePrice: $0.purchasePrice) },
            paint: paints.map { .init(roomName: $0.locationName, surface: $0.surface, brand: $0.brand, productLine: $0.productLine, colorName: $0.colorName, colorCode: $0.colorCode, sheen: $0.sheen, store: $0.store, containerSize: $0.containerSize, notes: $0.notes, productLink: $0.productLink, sourceProjectName: $0.sourceProject?.title ?? "", purchaseDate: $0.purchaseDate, quantity: $0.quantity, cost: $0.cost) },
            fixtures: fixtures.map { .init(name: $0.name, category: $0.category, manufacturer: $0.manufacturer, model: $0.model, partNumber: $0.partNumber, finishColor: $0.finishColor, purchasedFrom: $0.purchasedFrom, productLink: $0.productLink, notes: $0.notes, roomName: $0.room?.name ?? "", vendorName: $0.vendor?.businessName ?? "", sourceProjectName: $0.sourceProject?.title ?? "", installationDate: $0.installationDate, purchaseDate: $0.purchaseDate, warrantyExpiration: $0.warrantyExpiration, purchasePrice: $0.purchasePrice) },
            tasks: tasks.map { .init(title: $0.title, taskDescription: $0.taskDescription, category: $0.category.rawValue, recurrence: $0.recurrence.rawValue, recurrenceAnchor: $0.recurrenceAnchor.rawValue, notes: $0.notes, instructions: $0.instructions, contactName: $0.contactName, phone: $0.phone, email: $0.email, website: $0.website, roomName: $0.room?.name ?? "", systemName: $0.system?.name ?? "", applianceName: $0.appliance?.name ?? "", fixtureName: $0.fixture?.name ?? "", projectName: $0.project?.title ?? "", vendorName: $0.vendor?.businessName ?? "", dueDate: $0.dueDate, completedDate: $0.completedDate, leadTimeDays: $0.leadTimeDays, priority: $0.priority, isCompleted: $0.isCompleted) },
            maintenanceRecords: records.map { .init(date: $0.date, title: $0.title, notes: $0.notes, vendorName: $0.vendor?.businessName ?? $0.vendorName, taskTitle: $0.taskTitle, relatedItemName: $0.relatedItemName, eventType: $0.eventType.rawValue, roomName: $0.room?.name ?? "", systemName: $0.system?.name ?? "", applianceName: $0.appliance?.name ?? "", fixtureName: $0.fixture?.name ?? "", projectName: $0.project?.title ?? "", cost: $0.cost) },
            detectors: detectors.map { .init(location: $0.location, type: $0.type, manufacturer: $0.manufacturer, model: $0.model, batteryType: $0.batteryType, notes: $0.notes, manufactureDate: $0.manufactureDate, installationDate: $0.installationDate, replacementDate: $0.replacementDate, isHardwired: $0.isHardwired) },
            consumables: consumables.map { .init(name: $0.name, type: $0.type, size: $0.size, manufacturer: $0.manufacturer, modelPartNumber: $0.modelPartNumber, purchaseLink: $0.purchaseLink, notes: $0.notes, replacementIntervalMonths: $0.replacementIntervalMonths, lastReplaced: $0.lastReplaced, nextReplacement: $0.nextReplacement) },
            projects: projects.map { .init(title: $0.title, projectDescription: $0.projectDescription, stage: $0.stage.rawValue, notes: $0.notes, roomName: $0.locationName, targetDate: $0.targetDate, budget: $0.budget) },
            projectItems: items.map { .init(projectName: $0.project?.title ?? "", title: $0.title, category: $0.category, comparisonGroup: $0.comparisonGroupName, manufacturer: $0.manufacturer, model: $0.model, sku: $0.sku, finishColor: $0.finishColor, dimensions: $0.dimensions, store: $0.store, website: $0.website, notes: $0.notes, status: $0.status.rawValue, unitCost: $0.unitCost, quantity: $0.quantity, actualPurchaseCost: $0.actualPurchaseCost, purchaseDate: $0.purchaseDate, installedDate: $0.installedDate, isIdeaOnly: $0.isIdeaOnly) },
            measurements: measurements.map { .init(projectName: $0.project?.title ?? "", name: $0.name, unit: $0.unit, notes: $0.notes, value: $0.value) },
            attachments: attachments.map { attachment in
                let owner = ownerDescription(for: attachment)
                return .init(name: attachment.name, caption: attachment.caption, category: attachment.category, fileName: attachment.fileName, typeIdentifier: attachment.typeIdentifier, ownerType: owner.type, ownerName: owner.name, createdAt: attachment.createdAt, fileData: attachment.fileData)
            }
        )
    }

    static func encodedArchive(context: ModelContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(makeArchive(context: context))
    }

    private static func ownerDescription(for attachment: HomeAttachment) -> (type: String, name: String) {
        if let value = attachment.room { return ("Room / Area", value.name) }
        if let value = attachment.task { return ("Task", value.title) }
        if let value = attachment.vendor { return ("Vendor", value.businessName) }
        if let value = attachment.system { return ("Home System", value.name) }
        if let value = attachment.appliance { return ("Appliance", value.name) }
        if let value = attachment.paint { return ("Paint / Finish", "\(value.locationName) - \(value.surface)") }
        if let value = attachment.project { return ("Project", value.title) }
        if let value = attachment.projectItem { return ("Project Item", value.title) }
        if let value = attachment.maintenanceRecord { return ("Maintenance Record", value.title) }
        if let value = attachment.detector { return ("Detector", value.location) }
        if let value = attachment.consumable { return ("Consumable", value.name) }
        if let value = attachment.fixture { return ("Fixture", value.name) }
        return ("Unlinked", "")
    }
}

struct HomeArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
