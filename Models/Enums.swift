import Foundation

enum TaskCategory: String, CaseIterable, Identifiable {
    case safety = "Safety"
    case hvac = "HVAC"
    case plumbing = "Plumbing"
    case electrical = "Electrical"
    case exterior = "Exterior"
    case appliances = "Appliances"
    case general = "General"
    case project = "Project"

    var id: String { rawValue }
}

enum RecurrenceRule: String, CaseIterable, Identifiable {
    case oneTime = "One Time"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case sixMonths = "Every 6 Months"
    case annually = "Annually"
    case tenYears = "Every 10 Years"

    var id: String { rawValue }
}

enum RecurrenceAnchor: String, CaseIterable, Identifiable {
    case scheduledDate = "Scheduled Date"
    case completionDate = "Completion Date"

    var id: String { rawValue }
}

enum TaskDisplayStatus: String, CaseIterable {
    case overdue = "Overdue"
    case current = "Current"
    case upcoming = "Upcoming"
    case completed = "Completed"
}

enum ProjectStage: String, CaseIterable, Identifiable {
    case idea = "Idea"
    case planning = "Planning"
    case shopping = "Shopping"
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
    case onHold = "On Hold"

    var id: String { rawValue }
}

enum ProjectItemStatus: String, CaseIterable, Identifiable {
    case considering = "Considering"
    case favorite = "Favorite"
    case purchased = "Purchased"
    case installed = "Installed / Saved to Home"
    case rejected = "Rejected"

    var id: String { rawValue }
}

// Broad location type used for both interior rooms and exterior/property areas.
enum HomeAreaType: String, CaseIterable, Identifiable {
    case interior = "Interior"
    case exterior = "Exterior / Property"

    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .interior: return "door.left.hand.open"
        case .exterior: return "leaf"
        }
    }
}

enum HomeEventType: String, CaseIterable, Identifiable {
    case maintenance = "Maintenance"
    case repair = "Repair"
    case installation = "Installation"
    case purchase = "Purchase"
    case replacement = "Replacement"
    case inspection = "Inspection"
    case project = "Project"
    case other = "Other"

    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .maintenance: return "wrench.and.screwdriver"
        case .repair: return "hammer"
        case .installation: return "square.and.arrow.down"
        case .purchase: return "cart"
        case .replacement: return "arrow.triangle.2.circlepath"
        case .inspection: return "magnifyingglass"
        case .project: return "checkmark.seal"
        case .other: return "clock.arrow.circlepath"
        }
    }
}
