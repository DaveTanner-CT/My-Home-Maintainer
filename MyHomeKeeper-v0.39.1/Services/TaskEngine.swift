import Foundation

enum TaskEngine {
    static func status(for task: MaintenanceTask, now: Date = .now, calendar: Calendar = .current) -> TaskDisplayStatus {
        if task.isCompleted { return .completed }

        let dueDay = calendar.startOfDay(for: task.dueDate)
        let today = calendar.startOfDay(for: now)

        if dueDay < today { return .overdue }

        let currentStart = calendar.date(byAdding: .day, value: -task.leadTimeDays, to: dueDay) ?? dueDay
        if today >= currentStart { return .current }

        return .upcoming
    }

    static func nextDueDate(for task: MaintenanceTask, completionDate: Date, calendar: Calendar = .current) -> Date? {
        guard task.recurrence != .oneTime else { return nil }
        let base = task.recurrenceAnchor == .completionDate ? completionDate : task.dueDate

        switch task.recurrence {
        case .oneTime:
            return nil
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: base)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: base)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: base)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: 6, to: base)
        case .annually:
            return calendar.date(byAdding: .year, value: 1, to: base)
        case .tenYears:
            return calendar.date(byAdding: .year, value: 10, to: base)
        }
    }

    static func displayDate(for task: MaintenanceTask) -> String {
        task.dueDate.formatted(date: .abbreviated, time: .omitted)
    }
}
