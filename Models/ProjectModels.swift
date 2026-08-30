import Foundation
import SwiftData

@Model
final class Project {
    var title: String
    var projectDescription: String
    var stageRaw: String
    var targetDate: Date?
    var budget: Double?
    var notes: String
    // roomName is retained for compatibility with projects created before linked areas.
    var roomName: String
    var room: Room?
    var additionalRooms: [Room] = []
    var coverPhotoData: Data?

    init(title: String, projectDescription: String = "", stage: ProjectStage = .idea, targetDate: Date? = nil, budget: Double? = nil, notes: String = "", roomName: String = "", room: Room? = nil, coverPhotoData: Data? = nil) {
        self.title = title
        self.projectDescription = projectDescription
        self.stageRaw = stage.rawValue
        self.targetDate = targetDate
        self.budget = budget
        self.notes = notes
        self.roomName = room?.name ?? roomName
        self.room = room
        self.coverPhotoData = coverPhotoData
    }

    var locationName: String {
        room?.name ?? roomName
    }

    var stage: ProjectStage {
        get { ProjectStage(rawValue: stageRaw) ?? .idea }
        set { stageRaw = newValue.rawValue }
    }
}

@Model
final class ProjectItem {
    var project: Project?
    var title: String
    var category: String
    // Optional label that groups multiple product options for one buying decision (for example, "Kitchen Faucet").
    var comparisonGroup: String?
    var manufacturer: String
    var model: String
    var sku: String
    var finishColor: String
    var dimensions: String
    var store: String
    var website: String
    var unitCost: Double?
    var quantity: Double
    var actualPurchaseCost: Double?
    var purchaseDate: Date?
    var installedDate: Date?
    var notes: String
    var statusRaw: String
    var photoData: Data?
    var isIdeaOnly: Bool

    init(project: Project? = nil, title: String, category: String = "Inspiration", comparisonGroup: String? = nil, manufacturer: String = "", model: String = "", sku: String = "", finishColor: String = "", dimensions: String = "", store: String = "", website: String = "", unitCost: Double? = nil, quantity: Double = 1, actualPurchaseCost: Double? = nil, purchaseDate: Date? = nil, installedDate: Date? = nil, notes: String = "", status: ProjectItemStatus = .considering, photoData: Data? = nil, isIdeaOnly: Bool = false) {
        self.project = project
        self.title = title
        self.category = category
        self.comparisonGroup = comparisonGroup
        self.manufacturer = manufacturer
        self.model = model
        self.sku = sku
        self.finishColor = finishColor
        self.dimensions = dimensions
        self.store = store
        self.website = website
        self.unitCost = unitCost
        self.quantity = quantity
        self.actualPurchaseCost = actualPurchaseCost
        self.purchaseDate = purchaseDate
        self.installedDate = installedDate
        self.notes = notes
        self.statusRaw = status.rawValue
        self.photoData = photoData
        self.isIdeaOnly = isIdeaOnly
    }

    var status: ProjectItemStatus {
        get { ProjectItemStatus(rawValue: statusRaw) ?? .considering }
        set { statusRaw = newValue.rawValue }
    }

    var estimatedTotal: Double {
        (unitCost ?? 0) * quantity
    }

    var comparisonGroupName: String {
        let trimmed = (comparisonGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (category.isEmpty ? "Other" : category) : trimmed
    }
}

@Model
final class ProjectMeasurement {
    var project: Project?
    var name: String
    var value: Double
    var unit: String
    var notes: String

    init(project: Project? = nil, name: String, value: Double, unit: String, notes: String = "") {
        self.project = project
        self.name = name
        self.value = value
        self.unit = unit
        self.notes = notes
    }
}


extension Project {
    func isLinked(to target: Room) -> Bool { room?.persistentModelID == target.persistentModelID || additionalRooms.contains { $0.persistentModelID == target.persistentModelID } }
    func link(to target: Room) { guard !isLinked(to: target) else { return }; if room == nil { room = target; roomName = target.name } else { additionalRooms.append(target) } }
    func setPrimaryRoom(_ target: Room?) { let old = room; if room?.persistentModelID == target?.persistentModelID { return }; if let target { additionalRooms.removeAll { $0.persistentModelID == target.persistentModelID } }; room = target; if let target { roomName = target.name }; if let old, target != nil, !additionalRooms.contains(where: { $0.persistentModelID == old.persistentModelID }) { additionalRooms.append(old) } }
    func unlink(from target: Room) { if room?.persistentModelID == target.persistentModelID { if let replacement = additionalRooms.first { room = replacement; roomName = replacement.name; additionalRooms.removeFirst() } else { room = nil; if roomName.caseInsensitiveCompare(target.name) == .orderedSame { roomName = "" } } } else { additionalRooms.removeAll { $0.persistentModelID == target.persistentModelID } } }
    var linkedRooms: [Room] {
        var result = [Room]()
        for value in [room].compactMap({ $0 }) + additionalRooms where !result.contains(where: { $0.persistentModelID == value.persistentModelID }) { result.append(value) }
        return result
    }
}
