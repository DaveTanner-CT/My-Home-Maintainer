import Foundation
import UserNotifications

actor NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification authorization failed: \(error)")
        }
    }

    func schedule(for task: MaintenanceTask) async {
        let center = UNUserNotificationCenter.current()
        let base = "task-\(task.persistentModelID)"
        let identifiers = ["\(base)-lead", "\(base)-due", "\(base)-overdue"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard !task.isCompleted else { return }

        let defaults = UserDefaults.standard
        let leadEnabled = defaults.object(forKey: "notificationLeadEnabled") as? Bool ?? true
        let dueEnabled = defaults.object(forKey: "notificationDueEnabled") as? Bool ?? true
        let overdueEnabled = defaults.object(forKey: "notificationOverdueEnabled") as? Bool ?? true
        let hourValue = defaults.object(forKey: "notificationHour") as? Int ?? 9
        let hour = min(max(hourValue, 0), 23)

        if leadEnabled, task.leadTimeDays > 0,
           let leadDate = Calendar.current.date(byAdding: .day, value: -task.leadTimeDays, to: task.dueDate) {
            await add(identifier: "\(base)-lead", title: task.title, body: "This home task is ready for your attention. Due \(task.dueDate.formatted(date: .abbreviated, time: .omitted)).", date: leadDate, hour: hour)
        }

        if dueEnabled {
            await add(identifier: "\(base)-due", title: task.title, body: "This home maintenance task is due today.", date: task.dueDate, hour: hour)
        }

        if overdueEnabled, let overdueDate = Calendar.current.date(byAdding: .day, value: 1, to: task.dueDate) {
            await add(identifier: "\(base)-overdue", title: "Overdue: \(task.title)", body: "This maintenance task is overdue. Open Home Maintainer to review or complete it.", date: overdueDate, hour: hour)
        }
    }

    private func add(identifier: String, title: String, body: String, date: Date, hour: Int) async {
        let fireDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        guard fireDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            print("Unable to schedule notification: \(error)")
        }
    }
}
