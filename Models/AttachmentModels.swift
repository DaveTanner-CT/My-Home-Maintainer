import Foundation
import SwiftData

@Model
final class HomeAttachment {
    var name: String
    var caption: String
    var category: String
    var fileName: String
    var typeIdentifier: String
    var createdAt: Date
    var fileData: Data

    var room: Room?
    var task: MaintenanceTask?
    var vendor: Vendor?
    var system: HomeSystem?
    var appliance: Appliance?
    var paint: PaintFinish?
    var project: Project?
    var projectItem: ProjectItem?
    var maintenanceRecord: MaintenanceRecord?
    var detector: Detector?
    var consumable: Consumable?
    var fixture: Fixture?

    init(
        name: String,
        caption: String = "",
        category: String = "Document",
        fileName: String,
        typeIdentifier: String,
        createdAt: Date = .now,
        fileData: Data
    ) {
        self.name = name
        self.caption = caption
        self.category = category
        self.fileName = fileName
        self.typeIdentifier = typeIdentifier
        self.createdAt = createdAt
        self.fileData = fileData
    }

    var isImage: Bool {
        typeIdentifier.hasPrefix("image/") || ["jpg", "jpeg", "png", "heic", "gif", "webp"].contains((fileName as NSString).pathExtension.lowercased())
    }
}

enum AttachmentOwnerReference {
    case room(Room)
    case task(MaintenanceTask)
    case vendor(Vendor)
    case system(HomeSystem)
    case appliance(Appliance)
    case paint(PaintFinish)
    case project(Project)
    case projectItem(ProjectItem)
    case maintenanceRecord(MaintenanceRecord)
    case detector(Detector)
    case consumable(Consumable)
    case fixture(Fixture)

    func matches(_ attachment: HomeAttachment) -> Bool {
        switch self {
        case .room(let owner):
            return attachment.room?.persistentModelID == owner.persistentModelID
        case .task(let owner):
            return attachment.task?.persistentModelID == owner.persistentModelID
        case .vendor(let owner):
            return attachment.vendor?.persistentModelID == owner.persistentModelID
        case .system(let owner):
            return attachment.system?.persistentModelID == owner.persistentModelID
        case .appliance(let owner):
            return attachment.appliance?.persistentModelID == owner.persistentModelID
        case .paint(let owner):
            return attachment.paint?.persistentModelID == owner.persistentModelID
        case .project(let owner):
            return attachment.project?.persistentModelID == owner.persistentModelID
        case .projectItem(let owner):
            return attachment.projectItem?.persistentModelID == owner.persistentModelID
        case .maintenanceRecord(let owner):
            return attachment.maintenanceRecord?.persistentModelID == owner.persistentModelID
        case .detector(let owner):
            return attachment.detector?.persistentModelID == owner.persistentModelID
        case .consumable(let owner):
            return attachment.consumable?.persistentModelID == owner.persistentModelID
        case .fixture(let owner):
            return attachment.fixture?.persistentModelID == owner.persistentModelID
        }
    }

    func assign(to attachment: HomeAttachment) {
        attachment.room = nil
        attachment.task = nil
        attachment.vendor = nil
        attachment.system = nil
        attachment.appliance = nil
        attachment.paint = nil
        attachment.project = nil
        attachment.projectItem = nil
        attachment.maintenanceRecord = nil
        attachment.detector = nil
        attachment.consumable = nil
        attachment.fixture = nil

        switch self {
        case .room(let owner): attachment.room = owner
        case .task(let owner): attachment.task = owner
        case .vendor(let owner): attachment.vendor = owner
        case .system(let owner): attachment.system = owner
        case .appliance(let owner): attachment.appliance = owner
        case .paint(let owner): attachment.paint = owner
        case .project(let owner): attachment.project = owner
        case .projectItem(let owner): attachment.projectItem = owner
        case .maintenanceRecord(let owner): attachment.maintenanceRecord = owner
        case .detector(let owner): attachment.detector = owner
        case .consumable(let owner): attachment.consumable = owner
        case .fixture(let owner): attachment.fixture = owner
        }
    }
}
