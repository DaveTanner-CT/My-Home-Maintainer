import SwiftUI
import SwiftData

private enum MaintenanceSeason: String, CaseIterable, Identifiable {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"
    var id: String { rawValue }
    var months: Set<Int> {
        switch self {
        case .spring: return [3,4,5]
        case .summer: return [6,7,8]
        case .fall: return [9,10,11]
        case .winter: return [12,1,2]
        }
    }
    var icon: String {
        switch self { case .spring: return "leaf"; case .summer: return "sun.max"; case .fall: return "wind"; case .winter: return "snowflake" }
    }
}

private struct SeasonalSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let category: TaskCategory
    let season: MaintenanceSeason
    let month: Int
    let leadDays: Int
}

struct SeasonalMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [MaintenanceTask]
    @State private var season: MaintenanceSeason = {
        let month = Calendar.current.component(.month, from: .now)
        return MaintenanceSeason.allCases.first(where: { $0.months.contains(month) }) ?? .spring
    }()

    private let suggestions: [SeasonalSuggestion] = [
        .init(title: "Inspect roof after winter", detail: "Check shingles, flashing, roof penetrations, and visible storm damage.", category: .exterior, season: .spring, month: 3, leadDays: 14),
        .init(title: "Clean gutters and downspouts", detail: "Clear debris and verify water drains away from the foundation.", category: .exterior, season: .spring, month: 4, leadDays: 7),
        .init(title: "Prepare cooling system", detail: "Replace filters, clear outdoor equipment, and schedule service if needed.", category: .hvac, season: .spring, month: 5, leadDays: 21),
        .init(title: "Inspect exterior paint and caulk", detail: "Look for peeling paint, failed caulk, and openings around windows and trim.", category: .exterior, season: .summer, month: 6, leadDays: 14),
        .init(title: "Check decks, steps, and railings", detail: "Inspect for loose boards, fasteners, rot, and unstable railings.", category: .exterior, season: .summer, month: 7, leadDays: 7),
        .init(title: "Review drainage and landscaping", detail: "Keep soil, plants, and drainage paths from directing water toward the house.", category: .exterior, season: .summer, month: 8, leadDays: 7),
        .init(title: "Prepare heating system", detail: "Replace filters and schedule annual heating service before cold weather.", category: .hvac, season: .fall, month: 9, leadDays: 30),
        .init(title: "Clean gutters before winter", detail: "Remove leaves and check downspouts after fall foliage.", category: .exterior, season: .fall, month: 10, leadDays: 14),
        .init(title: "Winterize exterior plumbing", detail: "Disconnect hoses and protect vulnerable exterior plumbing before freezing weather.", category: .plumbing, season: .fall, month: 11, leadDays: 14),
        .init(title: "Check detectors and fire safety", detail: "Test smoke/CO alarms and review extinguishers during heating season.", category: .safety, season: .winter, month: 12, leadDays: 7),
        .init(title: "Inspect for leaks and ice issues", detail: "Check attic, ceilings, plumbing, and exterior drainage after severe winter weather.", category: .general, season: .winter, month: 1, leadDays: 0),
        .init(title: "Plan spring exterior work", detail: "Review projects, paint, roofing, gardens, and repairs to schedule for warmer weather.", category: .project, season: .winter, month: 2, leadDays: 14)
    ]

    private var year: Int { Calendar.current.component(.year, from: .now) }
    private var seasonTasks: [MaintenanceTask] {
        tasks.filter { !$0.isCompleted && season.months.contains(Calendar.current.component(.month, from: $0.dueDate)) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        List {
            Section {
                Picker("Season", selection: $season) {
                    ForEach(MaintenanceSeason.allCases) { season in
                        Label(season.rawValue, systemImage: season.icon).tag(season)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Scheduled for \(season.rawValue)") {
                if seasonTasks.isEmpty { Text("No active tasks scheduled for this season.").foregroundStyle(.secondary) }
                ForEach(seasonTasks) { task in
                    NavigationLink { TaskDetailView(task: task) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title).font(.headline)
                            Text(task.dueDate.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Seasonal Suggestions") {
                ForEach(suggestions.filter { $0.season == season }) { suggestion in
                    let exists = tasks.contains { $0.title.caseInsensitiveCompare(suggestion.title) == .orderedSame && !$0.isCompleted }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(suggestion.title).font(.headline); Spacer(); if exists { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }
                        Text(suggestion.detail).font(.caption).foregroundStyle(.secondary)
                        if !exists { Button("Add to Tasks") { add(suggestion) }.buttonStyle(.bordered) }
                    }.padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Seasonal Planning")
    }

    private func add(_ suggestion: SeasonalSuggestion) {
        var components = DateComponents(year: year, month: suggestion.month, day: 15)
        var due = Calendar.current.date(from: components) ?? .now
        if due < Calendar.current.startOfDay(for: .now) {
            components.year = year + 1
            due = Calendar.current.date(from: components) ?? .now
        }
        let task = MaintenanceTask(title: suggestion.title, taskDescription: suggestion.detail, category: suggestion.category, dueDate: due, leadTimeDays: suggestion.leadDays, recurrence: .annually, recurrenceAnchor: .scheduledDate, priority: suggestion.category == .safety ? 3 : 2)
        modelContext.insert(task)
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
    }
}

private struct ForecastItem: Identifiable {
    let id: String
    let name: String
    let kind: String
    let location: String
    let installed: Date
    let years: Int
    let detailDestination: AnyView
    var projected: Date { Calendar.current.date(byAdding: .year, value: years, to: installed) ?? installed }
}

struct ReplacementForecastView: View {
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]

    private var items: [ForecastItem] {
        var result: [ForecastItem] = []
        for system in systems {
            if let date = system.installationDate, let years = system.expectedServiceLifeYears, years > 0 {
                result.append(.init(id: "s-\(system.persistentModelID)", name: system.name, kind: "Home System", location: system.locationName, installed: date, years: years, detailDestination: AnyView(SystemDetailView(system: system))))
            }
        }
        for appliance in appliances {
            if let date = appliance.purchaseDate {
                result.append(.init(id: "a-\(appliance.persistentModelID)", name: appliance.name, kind: "Appliance / Electronics / Equipment", location: appliance.room?.name ?? "", installed: date, years: applianceLife("\(appliance.category) \(appliance.name)"), detailDestination: AnyView(ApplianceDetailView(appliance: appliance))))
            }
        }
        for fixture in fixtures {
            if let date = fixture.installationDate ?? fixture.purchaseDate {
                result.append(.init(id: "f-\(fixture.persistentModelID)", name: fixture.name, kind: "Fixture", location: fixture.room?.name ?? "", installed: date, years: fixtureLife(fixture.category), detailDestination: AnyView(FixtureDetailView(fixture: fixture))))
            }
        }
        return result.sorted { $0.projected < $1.projected }
    }

    var body: some View {
        List {
            Section {
                Text("Forecasts are planning estimates based on installation/purchase dates and typical service-life assumptions. Condition and maintenance matter more than the date alone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if items.isEmpty {
                Section { Text("Add installation or purchase dates to systems, appliances, and fixtures to build a replacement forecast.").foregroundStyle(.secondary) }
            }
            ForEach(groupedYears, id: \.self) { year in
                Section(String(year)) {
                    ForEach(items.filter { Calendar.current.component(.year, from: $0.projected) == year }) { item in
                        NavigationLink { item.detailDestination } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(item.name).font(.headline); Spacer(); Text(status(item.projected)).font(.caption.weight(.semibold)).foregroundStyle(statusColor(item.projected)) }
                                Text([item.kind, item.location].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                                Text("Estimated window: \(item.projected.formatted(date: .abbreviated, time: .omitted)) · \(item.years)-year assumption").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }.navigationTitle("Replacement Forecast")
    }

    private var groupedYears: [Int] { Array(Set(items.map { Calendar.current.component(.year, from: $0.projected) })).sorted() }
    private func status(_ date: Date) -> String {
        let years = Calendar.current.dateComponents([.year], from: .now, to: date).year ?? 0
        if date < .now { return "Past estimate" }
        if years <= 1 { return "Plan soon" }
        if years <= 3 { return "Coming up" }
        return "Future"
    }
    private func statusColor(_ date: Date) -> Color {
        if date < .now { return .red }
        let years = Calendar.current.dateComponents([.year], from: .now, to: date).year ?? 0
        return years <= 1 ? .orange : .secondary
    }
    private func applianceLife(_ category: String) -> Int {
        let value = category.lowercased()
        if value.contains("refriger") { return 13 }
        if value.contains("dish") { return 10 }
        if value.contains("washer") || value.contains("dryer") { return 11 }
        if value.contains("range") || value.contains("oven") { return 15 }
        if value.contains("microwave") { return 9 }
        if value.contains("freezer") { return 12 }
        if value.contains("water heater") { return 10 }
        if value.contains("router") || value.contains("wifi") || value.contains("network") || value.contains("home technology") { return 5 }
        if value.contains("television") || value.contains(" tv") || value.contains("electronics") { return 7 }
        if value.contains("tool") || value.contains("outdoor equipment") { return 10 }
        return 12
    }
    private func fixtureLife(_ category: String) -> Int {
        let value = category.lowercased()
        if value.contains("faucet") || value.contains("plumb") { return 15 }
        if value.contains("toilet") { return 20 }
        if value.contains("fan") { return 15 }
        if value.contains("light") { return 20 }
        if value.contains("thermostat") { return 10 }
        return 15
    }
}
