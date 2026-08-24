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
    var roomName: String
    var coverPhotoData: Data?

    init(title: String, projectDescription: String = "", stage: ProjectStage = .idea, targetDate: Date? = nil, budget: Double? = nil, notes: String = "", roomName: String = "", coverPhotoData: Data? = nil) {
        self.title = title
        self.projectDescription = projectDescription
        self.stageRaw = stage.rawValue
        self.targetDate = targetDate
        self.budget = budget
        self.notes = notes
        self.roomName = roomName
        self.coverPhotoData = coverPhotoData
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
    var notes: String
    var statusRaw: String
    var photoData: Data?
    var isIdeaOnly: Bool

    init(project: Project? = nil, title: String, category: String = "Inspiration", manufacturer: String = "", model: String = "", sku: String = "", finishColor: String = "", dimensions: String = "", store: String = "", website: String = "", unitCost: Double? = nil, quantity: Double = 1, actualPurchaseCost: Double? = nil, purchaseDate: Date? = nil, notes: String = "", status: ProjectItemStatus = .considering, photoData: Data? = nil, isIdeaOnly: Bool = false) {
        self.project = project
        self.title = title
        self.category = category
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
