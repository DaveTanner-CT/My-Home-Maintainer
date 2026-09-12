import SwiftUI

struct CompactSectionHeader: View {
    let title: String
    var count: Int? = nil
    var primarySystemImage: String = "plus.circle.fill"
    var primaryAccessibilityLabel: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondarySystemImage: String? = nil
    var secondaryAccessibilityLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            Spacer()
            if let primaryAction {
                Button(action: primaryAction) {
                    Image(systemName: primarySystemImage)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(primaryAccessibilityLabel ?? "Add")
            }
            if let secondaryAction, let secondarySystemImage {
                Button(action: secondaryAction) {
                    Image(systemName: secondarySystemImage)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(secondaryAccessibilityLabel ?? "More")
            }
        }
    }
}

struct CompactEmptyStateRow: View {
    let text: String
    var icon: String = "minus"

    init(_ text: String, icon: String = "minus") {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
