import SwiftUI
import SwiftData

struct HomeHistoryView: View {
    @Query private var records: [MaintenanceRecord]

    @State private var searchText = ""
    @State private var typeFilter = "All"
    @State private var roomFilter = "All"
    @State private var projectFilter = "All"
    @State private var vendorFilter = "All"
    @State private var yearFilter = "All"
    @State private var showAdd = false

    private let typeFilters = ["All", "Maintenance", "Repair", "Installation", "Purchase", "Replacement", "Inspection", "Project", "Other"]

    private var roomFilters: [String] {
        ["All"] + Array(Set(records.compactMap { $0.room?.name }.filter { !$0.isEmpty })).sorted()
    }

    private var projectFilters: [String] {
        ["All"] + Array(Set(records.compactMap { $0.project?.title }.filter { !$0.isEmpty })).sorted()
    }

    private var vendorFilters: [String] {
        ["All"] + Array(Set(records.map { $0.vendor?.businessName ?? $0.vendorName }.filter { !$0.isEmpty })).sorted()
    }

    private var yearFilters: [String] {
        let years = Set(records.map { String(Calendar.current.component(.year, from: $0.date)) })
        return ["All"] + years.sorted(by: >)
    }

    private var visibleRecords: [MaintenanceRecord] {
        records
            .filter { record in
                typeFilter == "All" || record.eventType.rawValue == typeFilter
            }
            .filter { record in
                roomFilter == "All" || record.room?.name == roomFilter
            }
            .filter { record in
                projectFilter == "All" || record.project?.title == projectFilter
            }
            .filter { record in
                let vendorName = record.vendor?.businessName ?? record.vendorName
                return vendorFilter == "All" || vendorName == vendorFilter
            }
            .filter { record in
                yearFilter == "All" || String(Calendar.current.component(.year, from: record.date)) == yearFilter
            }
            .filter { record in
                let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !term.isEmpty else { return true }
                let fields = [
                    record.title,
                    record.notes,
                    record.relatedItemName,
                    record.taskTitle,
                    record.room?.name ?? "",
                    record.project?.title ?? "",
                    record.fixture?.name ?? "",
                    record.appliance?.name ?? "",
                    record.system?.name ?? "",
                    record.vendor?.businessName ?? record.vendorName,
                    record.eventType.rawValue
                ]
                return fields.contains { $0.localizedCaseInsensitiveContains(term) }
            }
            .sorted { $0.date > $1.date }
    }

    private var totalRecordedCost: Double {
        visibleRecords.compactMap(\.cost).reduce(0, +)
    }

    private var activeFilterCount: Int {
        [typeFilter, roomFilter, projectFilter, vendorFilter, yearFilter].filter { $0 != "All" }.count
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The story of your home")
                        .font(.headline)
                    Text("Follow work from a room, project, fixture, device, system, vendor, or date. Connected records stay clickable so you can move through the home's history from whichever direction makes sense.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                HStack {
                    Label("\(visibleRecords.count) events", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    if totalRecordedCost > 0 {
                        Text(totalRecordedCost.formatted(AppFormatting.currency))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if activeFilterCount > 0 {
                Section("Active Filters") {
                    if typeFilter != "All" { filterRow("Type", typeFilter) }
                    if roomFilter != "All" { filterRow("Room / Area", roomFilter) }
                    if projectFilter != "All" { filterRow("Project", projectFilter) }
                    if vendorFilter != "All" { filterRow("Vendor", vendorFilter) }
                    if yearFilter != "All" { filterRow("Year", yearFilter) }
                    Button("Clear All Filters") { clearFilters() }
                }
            }

            if visibleRecords.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty && activeFilterCount == 0 ? "No history yet" : "No matching history",
                    systemImage: "clock.arrow.circlepath",
                    description: Text(searchText.isEmpty && activeFilterCount == 0 ? "Complete tasks, install project items, or add a history record to start the timeline." : "Try clearing a filter or searching for something else.")
                )
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
                                        let context = [
                                            record.eventType.rawValue,
                                            record.fixture?.name ?? record.appliance?.name ?? record.system?.name ?? record.relatedItemName,
                                            record.room?.name ?? "",
                                            record.project?.title ?? ""
                                        ].filter { !$0.isEmpty }
                                        if !context.isEmpty {
                                            Text(context.joined(separator: " · "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let cost = record.cost {
                                        Text(cost.formatted(AppFormatting.currency))
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home History")
        .searchable(text: $searchText, prompt: "Faucet, bathroom, project, vendor…")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Event Type", selection: $typeFilter) {
                        ForEach(typeFilters, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Room / Area", selection: $roomFilter) {
                        ForEach(roomFilters, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Project", selection: $projectFilter) {
                        ForEach(projectFilters, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Vendor", selection: $vendorFilter) {
                        ForEach(vendorFilters, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Year", selection: $yearFilter) {
                        ForEach(yearFilters, id: \.self) { Text($0).tag($0) }
                    }
                    if activeFilterCount > 0 {
                        Divider()
                        Button("Clear All Filters") { clearFilters() }
                    }
                } label: {
                    Image(systemName: activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack { MaintenanceRecordFormView() }
        }
    }

    @ViewBuilder
    private func filterRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
    }

    private func clearFilters() {
        typeFilter = "All"
        roomFilter = "All"
        projectFilter = "All"
        vendorFilter = "All"
        yearFilter = "All"
    }

    private var groupedYears: [Int] {
        Array(Set(visibleRecords.map { Calendar.current.component(.year, from: $0.date) })).sorted(by: >)
    }
}
