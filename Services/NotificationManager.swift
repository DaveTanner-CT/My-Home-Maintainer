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
        guard !task.isCompleted else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "task-\(task.persistentModelID)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = task.leadTimeDays > 0 ? "This home task is ready for your attention." : "This home task is due today."
        content.sound = .default

        let reminderDate = Calendar.current.date(byAdding: .day, value: -task.leadTimeDays, to: task.dueDate) ?? task.dueDate
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            print("Unable to schedule notification: \(error)")
        }
    }
}
