import SwiftUI

struct StatusBadge: View {
    let status: TaskDisplayStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
    }

    private var background: Color {
        switch status {
        case .overdue: return .red.opacity(0.14)
        case .current: return .orange.opacity(0.14)
        case .upcoming: return .blue.opacity(0.12)
        case .completed: return .green.opacity(0.14)
        }
    }

    private var foreground: Color {
        switch status {
        case .overdue: return .red
        case .current: return .orange
        case .upcoming: return .blue
        case .completed: return .green
        }
    }
}
