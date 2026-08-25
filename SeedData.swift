import Foundation
import SwiftData

enum SeedData {
    static func insertIfNeeded(context: ModelContext) {
        let homeCount = (try? context.fetchCount(FetchDescriptor<Home>())) ?? 0
        guard homeCount == 0 else { return }

        let home = Home(name: "My Home", address: "", yearBuilt: 1998, squareFeet: 2450)
        context.insert(home)

        let kitchen = Room(name: "Kitchen")
        let familyRoom = Room(name: "Family Room")
        let mudRoom = Room(name: "Mud Room")
        let basement = Room(name: "Basement")
        context.insert(kitchen)
        context.insert(familyRoom)
        context.insert(mudRoom)
        context.insert(basement)

        let hvacVendor = Vendor(
            businessName: "ABC Heating & Cooling",
            contactName: "Jane Smith",
            category: "HVAC",
            phone: "860-555-1212",
            email: "service@example.com",
            website: "https://example.com",
            isFavorite: true
        )
        context.insert(hvacVendor)

        let furnace = HomeSystem(
            name: "Carrier Furnace",
            type: "Furnace",
            manufacturer: "Carrier",
            model: "Infinity",
            installationDate: Calendar.current.date(from: DateComponents(year: 2019, month: 10, day: 1)),
            expectedServiceLifeYears: 18,
            location: "Basement utility room",
            vendor: hvacVendor
        )
        context.insert(furnace)

        let waterHeater = HomeSystem(
            name: "Bradford White Water Heater",
            type: "Water Heater",
            manufacturer: "Bradford White",
            installationDate: Calendar.current.date(from: DateComponents(year: 2018, month: 5, day: 1)),
            expectedServiceLifeYears: 12,
            location: "Basement"
        )
        context.insert(waterHeater)

        let refrigerator = Appliance(
            name: "Kitchen Refrigerator",
            category: "Refrigerator",
            manufacturer: "Samsung",
            purchaseDate: Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 14)),
            purchasePrice: 2499,
            purchasedFrom: "Best Buy",
            room: kitchen
        )
        context.insert(refrigerator)

        let hallDetector = Detector(
            location: "Upstairs Hall",
            type: "Combination",
            manufacturer: "First Alert",
            manufactureDate: Calendar.current.date(from: DateComponents(year: 2021, month: 9, day: 1)),
            installationDate: Calendar.current.date(from: DateComponents(year: 2021, month: 10, day: 1)),
            batteryType: "AA",
            isHardwired: true
        )
        context.insert(hallDetector)

        let furnaceFilter = Consumable(
            name: "Furnace Filter",
            type: "HVAC Filter",
            size: "20 × 25 × 1",
            manufacturer: "Filtrete",
            modelPartNumber: "1900",
            replacementIntervalMonths: 3,
            lastReplaced: Calendar.current.date(byAdding: .month, value: -2, to: .now),
            notes: "Stored on basement shelf near furnace."
        )
        context.insert(furnaceFilter)

        let paint = PaintFinish(
            roomName: "Family Room",
            surface: "Walls",
            brand: "Benjamin Moore",
            colorName: "Revere Pewter",
            colorCode: "HC-172",
            sheen: "Eggshell",
            store: "Ring's End"
        )
        context.insert(paint)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let monthlyTest = MaintenanceTask(
            title: "Test smoke & CO alarms",
            taskDescription: "Test every smoke and carbon monoxide detector in the home.",
            category: .safety,
            dueDate: today,
            leadTimeDays: 0,
            recurrence: .monthly,
            recurrenceAnchor: .scheduledDate,
            priority: 3,
            instructions: "Use each detector's test button and confirm the audible alarm operates."
        )
        context.insert(monthlyTest)

        let batteries = MaintenanceTask(
            title: "Replace detector batteries",
            taskDescription: "Replace batteries in smoke and CO detectors that do not use sealed 10-year batteries.",
            category: .safety,
            dueDate: calendar.date(byAdding: .month, value: 2, to: today) ?? today,
            leadTimeDays: 14,
            recurrence: .sixMonths,
            recurrenceAnchor: .scheduledDate,
            priority: 2
        )
        context.insert(batteries)

        let detectorUnits = MaintenanceTask(
            title: "Replace smoke / CO detector units",
            taskDescription: "Replace detector units that have reached ten years of service or the manufacturer's replacement date.",
            category: .safety,
            dueDate: calendar.date(byAdding: .year, value: 10, to: today) ?? today,
            leadTimeDays: 60,
            recurrence: .tenYears,
            recurrenceAnchor: .scheduledDate,
            priority: 3
        )
        context.insert(detectorUnits)

        let extinguisher = MaintenanceTask(
            title: "Inspect fire extinguishers",
            category: .safety,
            dueDate: calendar.date(byAdding: .month, value: 1, to: today) ?? today,
            leadTimeDays: 7,
            recurrence: .monthly,
            recurrenceAnchor: .scheduledDate,
            priority: 2
        )
        context.insert(extinguisher)

        let furnaceService = MaintenanceTask(
            title: "Schedule annual furnace service",
            taskDescription: "Schedule annual heating-system maintenance before the heating season.",
            category: .hvac,
            dueDate: calendar.date(byAdding: .day, value: 53, to: today) ?? today,
            leadTimeDays: 60,
            recurrence: .annually,
            recurrenceAnchor: .scheduledDate,
            priority: 2,
            instructions: "Ask technician to clean and inspect the furnace and replace the filter if needed.",
            system: furnace,
            vendor: hvacVendor
        )
        context.insert(furnaceService)

        let waterFilter = MaintenanceTask(
            title: "Replace refrigerator water filter",
            category: .appliances,
            dueDate: calendar.date(byAdding: .day, value: -12, to: today) ?? today,
            leadTimeDays: 14,
            recurrence: .sixMonths,
            recurrenceAnchor: .completionDate,
            priority: 2,
            appliance: refrigerator
        )
        context.insert(waterFilter)

        let project = Project(
            title: "Update Mud Room",
            projectDescription: "Refresh the mud room with new paint, tile, hooks, lighting, and better storage.",
            stage: .planning,
            targetDate: calendar.date(byAdding: .month, value: 8, to: today),
            budget: 4000,
            roomName: "Mud Room"
        )
        context.insert(project)

        let items = [
            ProjectItem(project: project, title: "Dark green cabinets with brass hardware", category: "Inspiration", notes: "Warm, durable look with natural wood bench.", status: .favorite, isIdeaOnly: true),
            ProjectItem(project: project, title: "Slate-look porcelain tile", category: "Flooring / Tile", manufacturer: "Sample Tile Co.", finishColor: "Charcoal", store: "Home Depot", unitCost: 4.89, quantity: 90, notes: "Need approximately 82 sq. ft. plus overage."),
            ProjectItem(project: project, title: "Matte black wall hooks", category: "Hardware", manufacturer: "Liberty", finishColor: "Matte Black", store: "Home Depot", unitCost: 12.99, quantity: 8, status: .favorite),
            ProjectItem(project: project, title: "Schoolhouse pendant light", category: "Lighting", store: "Online", unitCost: 189, quantity: 1, status: .considering)
        ]
        items.forEach(context.insert)

        let measurements = [
            ProjectMeasurement(project: project, name: "Back wall", value: 104, unit: "inches"),
            ProjectMeasurement(project: project, name: "Bench area", value: 72, unit: "inches"),
            ProjectMeasurement(project: project, name: "Floor", value: 82, unit: "sq. ft.")
        ]
        measurements.forEach(context.insert)

        try? context.save()
    }
}
