import Foundation
import SwiftData

/// Removes the demo records that shipped in early Home Maintainer builds.
///
/// This migration is deliberately conservative: it only deletes records that still
/// match the original sample values. If a sample record has been edited, has a user
/// attachment, or is referenced by user-created content, it is preserved.
enum LegacySampleDataCleanup {
    private static let cleanupKey = "HomeMaintainer.didRemoveLegacySampleData.v023"

    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: cleanupKey) else { return }

        do {
            try removeLegacySampleData(context: context)
            try context.save()
            UserDefaults.standard.set(true, forKey: cleanupKey)
        } catch {
            // Do not mark the migration complete if saving fails. It can safely retry.
            print("Legacy sample-data cleanup failed: \(error)")
        }
    }

    private static func removeLegacySampleData(context: ModelContext) throws {
        var attachments = try context.fetch(FetchDescriptor<HomeAttachment>())
        var tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())
        var systems = try context.fetch(FetchDescriptor<HomeSystem>())
        var appliances = try context.fetch(FetchDescriptor<Appliance>())
        var fixtures = try context.fetch(FetchDescriptor<Fixture>())
        var paints = try context.fetch(FetchDescriptor<PaintFinish>())
        var projects = try context.fetch(FetchDescriptor<Project>())
        var projectItems = try context.fetch(FetchDescriptor<ProjectItem>())
        var measurements = try context.fetch(FetchDescriptor<ProjectMeasurement>())
        var records = try context.fetch(FetchDescriptor<MaintenanceRecord>())
        var vendors = try context.fetch(FetchDescriptor<Vendor>())
        var detectors = try context.fetch(FetchDescriptor<Detector>())
        var consumables = try context.fetch(FetchDescriptor<Consumable>())
        var rooms = try context.fetch(FetchDescriptor<Room>())
        let homes = try context.fetch(FetchDescriptor<Home>())

        func hasAttachment(_ ownerID: PersistentIdentifier, keyPath: KeyPath<HomeAttachment, PersistentIdentifier?>) -> Bool {
            attachments.contains { $0[keyPath: keyPath] == ownerID }
        }

        // MARK: Project sample children

        let sampleProjects = projects.filter {
            $0.title == "Update Mud Room" &&
            $0.projectDescription == "Refresh the mud room with new paint, tile, hooks, lighting, and better storage." &&
            $0.budget == 4000 &&
            $0.roomName == "Mud Room" &&
            $0.notes.isEmpty
        }

        for project in sampleProjects {
            let projectID = project.persistentModelID

            let sampleItemSignatures: [(String, String)] = [
                ("Dark green cabinets with brass hardware", "Inspiration"),
                ("Slate-look porcelain tile", "Flooring / Tile"),
                ("Matte black wall hooks", "Hardware"),
                ("Schoolhouse pendant light", "Lighting")
            ]
            for item in projectItems where item.project?.persistentModelID == projectID {
                let isOriginalSample = sampleItemSignatures.contains { $0.0 == item.title && $0.1 == item.category }
                if isOriginalSample && !hasAttachment(item.persistentModelID, keyPath: \HomeAttachment.projectItem?.persistentModelID) {
                    context.delete(item)
                }
            }

            let sampleMeasurements: [(String, Double, String)] = [
                ("Back wall", 104, "inches"),
                ("Bench area", 72, "inches"),
                ("Floor", 82, "sq. ft.")
            ]
            for measurement in measurements where measurement.project?.persistentModelID == projectID {
                if sampleMeasurements.contains(where: { $0.0 == measurement.name && $0.1 == measurement.value && $0.2 == measurement.unit }) && measurement.notes.isEmpty {
                    context.delete(measurement)
                }
            }
        }

        // Refresh child collections after deleting sample children.
        projectItems = try context.fetch(FetchDescriptor<ProjectItem>())
        measurements = try context.fetch(FetchDescriptor<ProjectMeasurement>())

        // MARK: Sample systems and appliance

        let sampleSystems = systems.filter { system in
            let furnace = system.name == "Carrier Furnace" && system.type == "Furnace" && system.manufacturer == "Carrier" && system.model == "Infinity" && system.location == "Basement utility room"
            let heater = system.name == "Bradford White Water Heater" && system.type == "Water Heater" && system.manufacturer == "Bradford White" && system.location == "Basement"
            return furnace || heater
        }

        let sampleAppliances = appliances.filter {
            $0.name == "Kitchen Refrigerator" &&
            $0.category == "Refrigerator" &&
            $0.manufacturer == "Samsung" &&
            $0.purchasePrice == 2499 &&
            $0.purchasedFrom == "Best Buy"
        }

        let sampleSystemIDs = Set(sampleSystems.map(\.persistentModelID))
        let sampleApplianceIDs = Set(sampleAppliances.map(\.persistentModelID))

        // MARK: Sample maintenance tasks

        for task in tasks {
            let isSample: Bool
            switch task.title {
            case "Test smoke & CO alarms":
                isSample = task.taskDescription == "Test every smoke and carbon monoxide detector in the home." && task.recurrence == .monthly && task.priority == 3
            case "Replace detector batteries":
                isSample = task.taskDescription == "Replace batteries in smoke and CO detectors that do not use sealed 10-year batteries." && task.recurrence == .sixMonths && task.priority == 2
            case "Replace smoke / CO detector units":
                isSample = task.taskDescription == "Replace detector units that have reached ten years of service or the manufacturer's replacement date." && task.recurrence == .tenYears && task.priority == 3
            case "Inspect fire extinguishers":
                isSample = task.taskDescription.isEmpty && task.recurrence == .monthly && task.leadTimeDays == 7 && task.priority == 2
            case "Schedule annual furnace service":
                isSample = task.system.map { sampleSystemIDs.contains($0.persistentModelID) } == true && task.recurrence == .annually && task.priority == 2
            case "Replace refrigerator water filter":
                isSample = task.appliance.map { sampleApplianceIDs.contains($0.persistentModelID) } == true && task.recurrence == .sixMonths && task.priority == 2
            default:
                isSample = false
            }

            if isSample && !hasAttachment(task.persistentModelID, keyPath: \HomeAttachment.task?.persistentModelID) {
                context.delete(task)
            }
        }

        tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())

        // MARK: Sample project itself

        for project in sampleProjects {
            let id = project.persistentModelID
            let hasUserItems = projectItems.contains { $0.project?.persistentModelID == id }
            let hasUserMeasurements = measurements.contains { $0.project?.persistentModelID == id }
            let hasUserTasks = tasks.contains { $0.project?.persistentModelID == id }
            let hasHistory = records.contains { $0.project?.persistentModelID == id }
            let hasProjectAttachment = hasAttachment(id, keyPath: \HomeAttachment.project?.persistentModelID)

            if !hasUserItems && !hasUserMeasurements && !hasUserTasks && !hasHistory && !hasProjectAttachment {
                context.delete(project)
            }
        }

        projects = try context.fetch(FetchDescriptor<Project>())

        // MARK: Sample systems / appliance (only when not used by user content)

        for system in sampleSystems {
            let id = system.persistentModelID
            let referencedByTask = tasks.contains { $0.system?.persistentModelID == id }
            let referencedByHistory = records.contains { $0.system?.persistentModelID == id }
            let hasSystemAttachment = hasAttachment(id, keyPath: \HomeAttachment.system?.persistentModelID)
            if !referencedByTask && !referencedByHistory && !hasSystemAttachment {
                context.delete(system)
            }
        }

        for appliance in sampleAppliances {
            let id = appliance.persistentModelID
            let referencedByTask = tasks.contains { $0.appliance?.persistentModelID == id }
            let referencedByHistory = records.contains { $0.appliance?.persistentModelID == id }
            let hasApplianceAttachment = hasAttachment(id, keyPath: \HomeAttachment.appliance?.persistentModelID)
            if !referencedByTask && !referencedByHistory && !hasApplianceAttachment {
                context.delete(appliance)
            }
        }

        systems = try context.fetch(FetchDescriptor<HomeSystem>())
        appliances = try context.fetch(FetchDescriptor<Appliance>())

        // MARK: Other standalone sample records

        for detector in detectors where
            detector.location == "Upstairs Hall" &&
            detector.type == "Combination" &&
            detector.manufacturer == "First Alert" &&
            detector.batteryType == "AA" &&
            detector.isHardwired &&
            detector.notes.isEmpty {
            if !hasAttachment(detector.persistentModelID, keyPath: \HomeAttachment.detector?.persistentModelID) {
                context.delete(detector)
            }
        }

        for consumable in consumables where
            consumable.name == "Furnace Filter" &&
            consumable.type == "HVAC Filter" &&
            consumable.size == "20 × 25 × 1" &&
            consumable.manufacturer == "Filtrete" &&
            consumable.modelPartNumber == "1900" &&
            consumable.replacementIntervalMonths == 3 &&
            consumable.notes == "Stored on basement shelf near furnace." {
            if !hasAttachment(consumable.persistentModelID, keyPath: \HomeAttachment.consumable?.persistentModelID) {
                context.delete(consumable)
            }
        }

        for paint in paints where
            paint.roomName == "Family Room" &&
            paint.surface == "Walls" &&
            paint.brand == "Benjamin Moore" &&
            paint.colorName == "Revere Pewter" &&
            paint.colorCode == "HC-172" &&
            paint.sheen == "Eggshell" &&
            paint.store == "Ring's End" &&
            paint.notes.isEmpty {
            if !hasAttachment(paint.persistentModelID, keyPath: \HomeAttachment.paint?.persistentModelID) {
                context.delete(paint)
            }
        }

        // The original demo vendor is removed only if it is no longer referenced.
        systems = try context.fetch(FetchDescriptor<HomeSystem>())
        tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())
        records = try context.fetch(FetchDescriptor<MaintenanceRecord>())
        for vendor in vendors where
            vendor.businessName == "ABC Heating & Cooling" &&
            vendor.contactName == "Jane Smith" &&
            vendor.category == "HVAC" &&
            vendor.phone == "860-555-1212" &&
            vendor.email == "service@example.com" &&
            vendor.website == "https://example.com" {
            let id = vendor.persistentModelID
            let inUse = systems.contains { $0.vendor?.persistentModelID == id } ||
                tasks.contains { $0.vendor?.persistentModelID == id } ||
                records.contains { $0.vendor?.persistentModelID == id } ||
                fixtures.contains { $0.vendor?.persistentModelID == id } ||
                hasAttachment(id, keyPath: \HomeAttachment.vendor?.persistentModelID)
            if !inUse { context.delete(vendor) }
        }

        // MARK: Sample room shells
        // Delete only pristine demo rooms that have no remaining user-linked content.

        systems = try context.fetch(FetchDescriptor<HomeSystem>())
        appliances = try context.fetch(FetchDescriptor<Appliance>())
        paints = try context.fetch(FetchDescriptor<PaintFinish>())
        projects = try context.fetch(FetchDescriptor<Project>())
        tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())
        records = try context.fetch(FetchDescriptor<MaintenanceRecord>())
        attachments = try context.fetch(FetchDescriptor<HomeAttachment>())

        let originalRoomNames: Set<String> = ["Kitchen", "Family Room", "Mud Room", "Basement"]
        for room in rooms where originalRoomNames.contains(room.name) {
            let id = room.persistentModelID
            let pristine = room.notes.isEmpty && !room.isFavorite && room.dimensionLength == nil && room.dimensionWidth == nil && room.ceilingHeight == nil
            let linked = systems.contains { $0.room?.persistentModelID == id } ||
                appliances.contains { $0.room?.persistentModelID == id } ||
                fixtures.contains { $0.room?.persistentModelID == id } ||
                paints.contains { $0.room?.persistentModelID == id } ||
                projects.contains { $0.room?.persistentModelID == id } ||
                tasks.contains { $0.room?.persistentModelID == id } ||
                records.contains { $0.room?.persistentModelID == id } ||
                attachments.contains { $0.room?.persistentModelID == id }
            if pristine && !linked { context.delete(room) }
        }

        // Clear the untouched demo home's fake year/square-footage values without
        // deleting the Home object itself, so user-entered records remain intact.
        if homes.count == 1, let home = homes.first,
           home.name == "My Home",
           home.address.isEmpty,
           home.yearBuilt == 1998,
           home.squareFeet == 2450,
           home.purchaseDate == nil,
           home.notes.isEmpty {
            home.yearBuilt = nil
            home.squareFeet = nil
        }
    }
}
