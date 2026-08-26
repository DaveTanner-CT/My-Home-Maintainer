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

    private var monthGroups: [HistoryMonthGroup] {
        HistoryMonthGroup.make(from: visibleRecords)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The story of your home")
                        .font(.headline)
                    Text("See the timeline, or follow the history of a specific room, fixture, device, system, project, or vendor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                NavigationLink {
                    HistoryStoriesView()
                } label: {
                    Label("Browse Home Stories", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.body.weight(.semibold))
                }

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
                ForEach(monthGroups) { group in
                    Section(group.title) {
                        ForEach(group.records) { record in
                            NavigationLink { MaintenanceRecordDetailView(record: record) } label: {
                                HistoryTimelineRow(record: record)
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
}

private struct HistoryTimelineRow: View {
    let record: MaintenanceRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.eventType.iconName)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.headline)
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
        .padding(.vertical, 2)
    }
}

private struct HistoryMonthGroup: Identifiable {
    let year: Int
    let month: Int
    let records: [MaintenanceRecord]

    var id: String { "\(year)-\(month)" }

    var title: String {
        guard let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return "\(year)"
        }
        return date.formatted(.dateTime.month(.wide).year())
    }

    static func make(from records: [MaintenanceRecord]) -> [HistoryMonthGroup] {
        let grouped = Dictionary(grouping: records) { record in
            let components = Calendar.current.dateComponents([.year, .month], from: record.date)
            return MonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }
        return grouped
            .map { key, values in
                HistoryMonthGroup(year: key.year, month: key.month, records: values.sorted { $0.date > $1.date })
            }
            .sorted {
                if $0.year != $1.year { return $0.year > $1.year }
                return $0.month > $1.month
            }
    }

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }
}

struct HistoryStoriesView: View {
    @Query private var records: [MaintenanceRecord]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \Fixture.name) private var fixtures: [Fixture]
    @Query(sort: \Appliance.name) private var appliances: [Appliance]
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @Query(sort: \Project.title) private var projects: [Project]
    @Query(sort: \Vendor.businessName) private var vendors: [Vendor]

    var body: some View {
        List {
            Section {
                Text("A story gathers every connected history event for one part of your home. Use this when you're thinking, “What happened to this bathroom?” or “What have we done to this furnace?”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            storySection(
                title: "Rooms & Areas",
                icon: "door.left.hand.open",
                items: rooms.compactMap { room in
                    let matches = records.filter { $0.room?.persistentModelID == room.persistentModelID }
                    return matches.isEmpty ? nil : HistoryStoryItem(title: room.name, subtitle: "Room / Area", icon: room.areaType.iconName, records: matches)
                }
            )

            storySection(
                title: "Fixtures",
                icon: "wrench.and.screwdriver",
                items: fixtures.compactMap { fixture in
                    let matches = records.filter { $0.fixture?.persistentModelID == fixture.persistentModelID }
                    return matches.isEmpty ? nil : HistoryStoryItem(title: fixture.name, subtitle: fixture.room?.name ?? "Fixture", icon: "wrench.and.screwdriver", records: matches)
                }
            )

            storySection(
                title: "Devices & Equipment",
                icon: "washer",
                items: appliances.compactMap { appliance in
                    let matches = records.filter { $0.appliance?.persistentModelID == appliance.persistentModelID }
                    return matches.isEmpty ? nil : HistoryStoryItem(title: appliance.name, subtitle: appliance.room?.name ?? appliance.category, icon: "washer", records: matches)
                }
            )

            storySection(
                title: "Home Systems",
                icon: "gearshape.2",
                items: systems.compactMap { system in
                    let matches = records.filter { $0.system?.persistentModelID == system.persistentModelID }
                    return matches.isEmpty ? nil : HistoryStoryItem(title: system.name, subtitle: system.room?.name ?? system.type, icon: "gearshape.2", records: matches)
                }
            )

            storySection(
                title: "Projects",
                icon: "hammer",
                items: projects.compactMap { project in
                    let matches = records.filter { $0.project?.persistentModelID == project.persistentModelID }
                    return matches.isEmpty ? nil : HistoryStoryItem(title: project.title, subtitle: project.room?.name ?? "Project", icon: "hammer", records: matches)
                }
            )

            storySection(
                title: "Vendors",
                icon: "person.crop.rectangle.stack",
                items: vendors.compactMap { vendor in
                    let matches = records.filter { $0.vendor?.persistentModelID == vendor.persistentModelID }
                    return matches.isEmpty ? nil : HistoryStoryItem(title: vendor.businessName, subtitle: vendor.category.isEmpty ? "Vendor" : vendor.category, icon: "person.crop.rectangle.stack", records: matches)
                }
            )

            if connectedStoryCount == 0 {
                ContentUnavailableView(
                    "No connected stories yet",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("History events will appear here as they are connected to rooms, assets, projects, and vendors.")
                )
            }
        }
        .navigationTitle("Home Stories")
    }

    @ViewBuilder
    private func storySection(title: String, icon: String, items: [HistoryStoryItem]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    NavigationLink {
                        HistoryStoryDetailView(item: item)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .frame(width: 26)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(item.records.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label(title, systemImage: icon)
            }
        }
    }

    private var connectedStoryCount: Int {
        rooms.filter { room in records.contains { $0.room?.persistentModelID == room.persistentModelID } }.count
        + fixtures.filter { fixture in records.contains { $0.fixture?.persistentModelID == fixture.persistentModelID } }.count
        + appliances.filter { appliance in records.contains { $0.appliance?.persistentModelID == appliance.persistentModelID } }.count
        + systems.filter { system in records.contains { $0.system?.persistentModelID == system.persistentModelID } }.count
        + projects.filter { project in records.contains { $0.project?.persistentModelID == project.persistentModelID } }.count
        + vendors.filter { vendor in records.contains { $0.vendor?.persistentModelID == vendor.persistentModelID } }.count
    }
}

struct HistoryStoryItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let records: [MaintenanceRecord]
}

struct HistoryStoryDetailView: View {
    let item: HistoryStoryItem

    private var sortedRecords: [MaintenanceRecord] {
        item.records.sorted { $0.date > $1.date }
    }

    private var totalCost: Double {
        item.records.compactMap(\.cost).reduce(0, +)
    }

    private var groups: [HistoryMonthGroup] {
        HistoryMonthGroup.make(from: sortedRecords)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.title2)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("History events", value: "\(item.records.count)")
                if totalCost > 0 {
                    LabeledContent("Recorded spending", value: totalCost.formatted(AppFormatting.currency))
                }
                if let oldest = sortedRecords.last?.date, let newest = sortedRecords.first?.date {
                    LabeledContent("Story covers", value: dateRangeText(oldest: oldest, newest: newest))
                }
            }

            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.records) { record in
                        NavigationLink { MaintenanceRecordDetailView(record: record) } label: {
                            HistoryTimelineRow(record: record)
                        }
                    }
                }
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dateRangeText(oldest: Date, newest: Date) -> String {
        let oldYear = Calendar.current.component(.year, from: oldest)
        let newYear = Calendar.current.component(.year, from: newest)
        if oldYear == newYear { return String(newYear) }
        return "\(oldYear)–\(newYear)"
    }
}
