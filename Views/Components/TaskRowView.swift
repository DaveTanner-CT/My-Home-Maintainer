import SwiftUI

struct TaskRowView: View {
    let task: MaintenanceTask
    let onComplete: () -> Void

    private var status: TaskDisplayStatus { TaskEngine.status(for: task) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : status == .overdue ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Completed" : "Complete task")

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                HStack(spacing: 6) {
                    StatusBadge(status: status)
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if task.leadTimeDays > 0 && status != .completed {
                    Text("Lead time: \(task.leadTimeDays) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    private var dateText: String {
        switch status {
        case .overdue:
            let days = Calendar.current.dateComponents([.day], from: task.dueDate, to: .now).day ?? 0
            return "\(max(days, 1)) days overdue"
        case .current:
            return "Due \(TaskEngine.displayDate(for: task))"
        case .upcoming:
            return "Due \(TaskEngine.displayDate(for: task))"
        case .completed:
            return task.completedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Completed"
        }
    }
}
