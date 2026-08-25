import SwiftUI
import SwiftData

struct HomeHistoryView: View {
    @Query private var records: [MaintenanceRecord]
    @State private var filter = "All"

    private let filters = ["All", "Maintenance", "Repair", "Installation", "Purchase", "Replacement", "Inspection", "Project", "Other"]

    private var visibleRecords: [MaintenanceRecord] {
        records
            .filter { filter == "All" || $0.eventType.rawValue == filter }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $filter) {
                    ForEach(filters, id: \.self) { Text($0).tag($0) }
                }
                Text("A permanent timeline of maintenance, repairs, installations, purchases, replacements, inspections, and completed projects.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if visibleRecords.isEmpty {
                ContentUnavailableView("No history yet", systemImage: "clock.arrow.circlepath", description: Text("Complete tasks, install project items, or add a history record to start the timeline."))
            } else {
                ForEach(groupedYears, id: \.self) { year in
                    Section(String(year)) {
                        ForEach(visibleRecords.filter { Calendar.current.component(.year, from: $0.date) == year }) { record in
                            NavigationLink { MaintenanceRecordDetailView(record: record) } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: record.eventType.iconName)
                                        .frame(width: 24)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.title).font(.headline)
                                        Text([record.eventType.rawValue, record.relatedItemName, record.room?.name ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let cost = record.cost { Text(cost.formatted(AppFormatting.currency)).font(.caption.weight(.semibold)) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home History")
    }

    private var groupedYears: [Int] {
        Array(Set(visibleRecords.map { Calendar.current.component(.year, from: $0.date) })).sorted(by: >)
    }
}
