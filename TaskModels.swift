import Foundation
import SwiftData

@Model
final class MaintenanceTask {
    var title: String
    var taskDescription: String
    var categoryRaw: String
    var dueDate: Date
    var leadTimeDays: Int
    var recurrenceRaw: String
    var recurrenceAnchorRaw: String
    var priority: Int
    var notes: String
    var instructions: String
    var contactName: String
    var phone: String
    var email: String
    var website: String
    var isCompleted: Bool
    var completedDate: Date?
    var room: Room?
    var additionalRooms: [Room] = []
    var system: HomeSystem?
    var appliance: Appliance?
    var fixture: Fixture?
    var project: Project?
    var vendor: Vendor?

    init(title: String, taskDescription: String = "", category: TaskCategory = .general, dueDate: Date, leadTimeDays: Int = 0, recurrence: RecurrenceRule = .oneTime, recurrenceAnchor: RecurrenceAnchor = .scheduledDate, priority: Int = 1, notes: String = "", instructions: String = "", contactName: String = "", phone: String = "", email: String = "", website: String = "", room: Room? = nil, system: HomeSystem? = nil, appliance: Appliance? = nil, fixture: Fixture? = nil, project: Project? = nil, vendor: Vendor? = nil) {
        self.title = title
        self.taskDescription = taskDescription
        self.categoryRaw = category.rawValue
        self.dueDate = dueDate
        self.leadTimeDays = leadTimeDays
        self.recurrenceRaw = recurrence.rawValue
        self.recurrenceAnchorRaw = recurrenceAnchor.rawValue
        self.priority = priority
        self.notes = notes
        self.instructions = instructions
        self.contactName = contactName
        self.phone = phone
        self.email = email
        self.website = website
        self.isCompleted = false
        self.completedDate = nil
        self.room = room
        self.system = system
        self.appliance = appliance
        self.fixture = fixture
        self.project = project
        self.vendor = vendor
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: RecurrenceRule {
        get { RecurrenceRule(rawValue: recurrenceRaw) ?? .oneTime }
        set { recurrenceRaw = newValue.rawValue }
    }

    var recurrenceAnchor: RecurrenceAnchor {
        get { RecurrenceAnchor(rawValue: recurrenceAnchorRaw) ?? .scheduledDate }
        set { recurrenceAnchorRaw = newValue.rawValue }
    }
}

@Model
final class MaintenanceRecord {
    var date: Date
    var title: String
    var cost: Double?
    var notes: String
    var vendorName: String
    var taskTitle: String
    var relatedItemName: String
    // Optional for records created before Home History gained typed events and direct links.
    var eventTypeRaw: String?
    var room: Room?
    var system: HomeSystem?
    var appliance: Appliance?
    var fixture: Fixture?
    var project: Project?
    var vendor: Vendor?

    init(date: Date = .now, title: String, cost: Double? = nil, notes: String = "", vendorName: String = "", taskTitle: String = "", relatedItemName: String = "", eventType: HomeEventType = .maintenance, room: Room? = nil, system: HomeSystem? = nil, appliance: Appliance? = nil, fixture: Fixture? = nil, project: Project? = nil, vendor: Vendor? = nil) {
        self.date = date
        self.title = title
        self.cost = cost
        self.notes = notes
        self.vendorName = vendorName
        self.taskTitle = taskTitle
        self.relatedItemName = relatedItemName
        self.eventTypeRaw = eventType.rawValue
        self.room = room
        self.system = system
        self.appliance = appliance
        self.fixture = fixture
        self.project = project
        self.vendor = vendor
    }

    var eventType: HomeEventType {
        get { HomeEventType(rawValue: eventTypeRaw ?? "") ?? .maintenance }
        set { eventTypeRaw = newValue.rawValue }
    }
}


extension MaintenanceTask {
    func isDirectlyLinked(to target: Room) -> Bool { room?.persistentModelID == target.persistentModelID || additionalRooms.contains { $0.persistentModelID == target.persistentModelID } }
    func isRelevant(to target: Room) -> Bool {
        isDirectlyLinked(to: target) || system?.isLinked(to: target) == true || appliance?.isLinked(to: target) == true || fixture?.isLinked(to: target) == true || project?.isLinked(to: target) == true
    }
    func link(to target: Room) { guard !isDirectlyLinked(to: target) else { return }; if room == nil { room = target } else { additionalRooms.append(target) } }
    func setPrimaryRoom(_ target: Room?) { let old = room; if room?.persistentModelID == target?.persistentModelID { return }; if let target { additionalRooms.removeAll { $0.persistentModelID == target.persistentModelID } }; room = target; if let old, target != nil, !additionalRooms.contains(where: { $0.persistentModelID == old.persistentModelID }) { additionalRooms.append(old) } }
    func unlink(from target: Room) { if room?.persistentModelID == target.persistentModelID { if let replacement = additionalRooms.first { room = replacement; additionalRooms.removeFirst() } else { room = nil } } else { additionalRooms.removeAll { $0.persistentModelID == target.persistentModelID } } }
    var linkedRooms: [Room] {
        var result = [Room]()
        for value in [room].compactMap({ $0 }) + additionalRooms where !result.contains(where: { $0.persistentModelID == value.persistentModelID }) { result.append(value) }
        return result
    }
}
