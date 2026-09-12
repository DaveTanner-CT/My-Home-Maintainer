import SwiftUI
import SwiftData

private enum OutlookHorizon: String, CaseIterable, Identifiable {
    case one = "1 Year"
    case three = "3 Years"
    case five = "5 Years"
    case all = "All"

    var id: String { rawValue }
    var years: Int? {
        switch self {
        case .one: return 1
        case .three: return 3
        case .five: return 5
        case .all: return nil
        }
    }
}

private struct HomeOutlookItem: Identifiable {
    let id: String
    let name: String
    let kind: String
    let room: Room?
    let projectedDate: Date
    let serviceLifeYears: Int
    let baselineCost: Double?
    let destination: AnyView

    var locationName: String { room?.name ?? "" }
}


private struct OutlookDataIssueItem: Identifiable {
    let id: String
    let name: String
    let kind: String
    let detail: String
    let destination: AnyView
}

private struct OutlookDataIssueListView: View {
    let title: String
    let guidance: String
    let items: [OutlookDataIssueItem]

    var body: some View {
        List {
            Section {
                Text(guidance)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Items to Update") {
                ForEach(items) { item in
                    NavigationLink { item.destination } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name).font(.headline)
                            Text(item.kind).font(.caption).foregroundStyle(.secondary)
                            if !item.detail.isEmpty {
                                Text(item.detail).font(.caption2).foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}

struct HomeOutlookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]
    @Query private var projects: [Project]

    @State private var horizon: OutlookHorizon = .five
    @State private var createdProject: Project?
    @State private var showExplanation = false

    private var allItems: [HomeOutlookItem] {
        var result: [HomeOutlookItem] = []

        for system in systems {
            guard let installed = system.installationDate,
                  let years = system.expectedServiceLifeYears,
                  years > 0 else { continue }
            let projected = Calendar.current.date(byAdding: .year, value: years, to: installed) ?? installed
            result.append(.init(
                id: "system-\(system.persistentModelID)",
                name: system.name,
                kind: "Home System",
                room: system.room,
                projectedDate: projected,
                serviceLifeYears: years,
                baselineCost: system.purchaseCost,
                destination: AnyView(SystemDetailView(system: system))
            ))
        }

        for appliance in appliances {
            guard let purchased = appliance.purchaseDate else { continue }
            let years = applianceLife("\(appliance.category) \(appliance.name)")
            let projected = Calendar.current.date(byAdding: .year, value: years, to: purchased) ?? purchased
            result.append(.init(
                id: "device-\(appliance.persistentModelID)",
                name: appliance.name,
                kind: appliance.category.isEmpty ? "Device / Equipment" : appliance.category,
                room: appliance.room,
                projectedDate: projected,
                serviceLifeYears: years,
                baselineCost: appliance.purchasePrice,
                destination: AnyView(ApplianceDetailView(appliance: appliance))
            ))
        }

        for fixture in fixtures {
            guard let installed = fixture.installationDate ?? fixture.purchaseDate else { continue }
            let years = fixtureLife(fixture.category)
            let projected = Calendar.current.date(byAdding: .year, value: years, to: installed) ?? installed
            result.append(.init(
                id: "fixture-\(fixture.persistentModelID)",
                name: fixture.name,
                kind: fixture.category.isEmpty ? "Fixture" : fixture.category,
                room: fixture.room,
                projectedDate: projected,
                serviceLifeYears: years,
                baselineCost: fixture.purchasePrice,
                destination: AnyView(FixtureDetailView(fixture: fixture))
            ))
        }

        return result.sorted { $0.projectedDate < $1.projectedDate }
    }

    private var visibleItems: [HomeOutlookItem] {
        guard let years = horizon.years,
              let cutoff = Calendar.current.date(byAdding: .year, value: years, to: .now) else { return allItems }
        return allItems.filter { $0.projectedDate <= cutoff }
    }

    private var knownBaselineTotal: Double {
        visibleItems.compactMap(\.baselineCost).reduce(0, +)
    }

    private var missingDateCount: Int {
        systems.filter { $0.installationDate == nil }.count
        + appliances.filter { $0.purchaseDate == nil }.count
        + fixtures.filter { $0.installationDate == nil && $0.purchaseDate == nil }.count
    }

    private var missingCostCount: Int {
        systems.filter { $0.purchaseCost == nil }.count
        + appliances.filter { $0.purchasePrice == nil }.count
        + fixtures.filter { $0.purchasePrice == nil }.count
    }

    private var systemsMissingLifeCount: Int {
        systems.filter { ($0.expectedServiceLifeYears ?? 0) <= 0 }.count
    }

    private var missingDateItems: [OutlookDataIssueItem] {
        systems.filter { $0.installationDate == nil }.map { system in
            .init(id: "date-system-\(system.persistentModelID)", name: system.name, kind: "Home System", detail: "Add installation date", destination: AnyView(SystemDetailView(system: system)))
        } + appliances.filter { $0.purchaseDate == nil }.map { item in
            .init(id: "date-device-\(item.persistentModelID)", name: item.name, kind: "Device / Equipment", detail: "Add purchase date", destination: AnyView(ApplianceDetailView(appliance: item)))
        } + fixtures.filter { $0.installationDate == nil && $0.purchaseDate == nil }.map { item in
            .init(id: "date-fixture-\(item.persistentModelID)", name: item.name, kind: "Fixture", detail: "Add installation or purchase date", destination: AnyView(FixtureDetailView(fixture: item)))
        }
    }

    private var missingCostItems: [OutlookDataIssueItem] {
        systems.filter { $0.purchaseCost == nil }.map { system in
            .init(id: "cost-system-\(system.persistentModelID)", name: system.name, kind: "Home System", detail: "Add recorded purchase / installation cost", destination: AnyView(SystemDetailView(system: system)))
        } + appliances.filter { $0.purchasePrice == nil }.map { item in
            .init(id: "cost-device-\(item.persistentModelID)", name: item.name, kind: "Device / Equipment", detail: "Add recorded purchase cost", destination: AnyView(ApplianceDetailView(appliance: item)))
        } + fixtures.filter { $0.purchasePrice == nil }.map { item in
            .init(id: "cost-fixture-\(item.persistentModelID)", name: item.name, kind: "Fixture", detail: "Add recorded purchase / installation cost", destination: AnyView(FixtureDetailView(fixture: item)))
        }
    }

    private var missingLifeItems: [OutlookDataIssueItem] {
        systems.filter { ($0.expectedServiceLifeYears ?? 0) <= 0 }.map { system in
            .init(id: "life-system-\(system.persistentModelID)", name: system.name, kind: "Home System", detail: "Add expected service life", destination: AnyView(SystemDetailView(system: system)))
        }
    }

    var body: some View {
        List {
            Section {
                Text("Look ahead at likely replacement windows using the home information you have already recorded. This is a planning tool, not a prediction that an item will fail on a specific date.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("How estimates work") { showExplanation = true }
            }

            Section("Planning Window") {
                Picker("Window", selection: $horizon) {
                    ForEach(OutlookHorizon.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    outlookMetric(title: "Items", value: "\(visibleItems.count)", icon: "shippingbox")
                    outlookMetric(title: "Known Costs", value: knownBaselineTotal.formatted(AppFormatting.currency), icon: "dollarsign.circle")
                }
            }

            Section("1 / 3 / 5 Year View") {
                horizonRow(title: "Next year", years: 1)
                horizonRow(title: "Next 3 years", years: 3)
                horizonRow(title: "Next 5 years", years: 5)
            }

            if visibleItems.isEmpty {
                Section("Replacement Outlook") {
                    ContentUnavailableView(
                        "No replacements in this window",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("Try a longer planning window, or add purchase/installation dates to your home records.")
                    )
                }
            } else {
                ForEach(groupedYears, id: \.self) { year in
                    Section(String(year)) {
                        ForEach(visibleItems.filter { Calendar.current.component(.year, from: $0.projectedDate) == year }) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                NavigationLink {
                                    item.destination
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(item.name).font(.headline)
                                            Spacer()
                                            Text(status(item.projectedDate))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(statusColor(item.projectedDate))
                                        }
                                        Text([item.kind, item.locationName].filter { !$0.isEmpty }.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Planning window: \(item.projectedDate.formatted(date: .abbreviated, time: .omitted)) · \(item.serviceLifeYears)-year assumption")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if let cost = item.baselineCost {
                                            Text("Recorded cost baseline: \(cost.formatted(AppFormatting.currency))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("No cost baseline recorded")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }

                                Button {
                                    createReplacementProject(for: item)
                                } label: {
                                    Label(existingProject(for: item) == nil ? "Plan Replacement" : "Replacement Project Exists", systemImage: existingProject(for: item) == nil ? "hammer" : "checkmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .disabled(existingProject(for: item) != nil)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            Section("Improve This Outlook") {
                if missingDateCount == 0 && missingCostCount == 0 && systemsMissingLifeCount == 0 {
                    Label("Your replacement-planning data is in good shape.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    if missingDateCount > 0 {
                        NavigationLink {
                            OutlookDataIssueListView(
                                title: "Missing Dates",
                                guidance: "These records cannot be placed reliably on the replacement timeline until a purchase or installation date is recorded.",
                                items: missingDateItems
                            )
                        } label: {
                            LabeledContent("Missing purchase / installation dates", value: "\(missingDateCount)")
                        }
                    }
                    if systemsMissingLifeCount > 0 {
                        NavigationLink {
                            OutlookDataIssueListView(
                                title: "Missing Service Life",
                                guidance: "Add an expected service-life estimate to these systems so Home Outlook can calculate a planning window.",
                                items: missingLifeItems
                            )
                        } label: {
                            LabeledContent("Systems missing service-life estimate", value: "\(systemsMissingLifeCount)")
                        }
                    }
                    if missingCostCount > 0 {
                        NavigationLink {
                            OutlookDataIssueListView(
                                title: "Missing Recorded Cost",
                                guidance: "These are the exact records behind the missing-cost count. Open any item to add its known historical cost.",
                                items: missingCostItems
                            )
                        } label: {
                            LabeledContent("Items missing recorded cost", value: "\(missingCostCount)")
                        }
                    }
                    Text("Tap any issue above to see the exact records that need attention. Recorded costs are shown only as a baseline; Home Maintainer does not inflate them into a future-price prediction.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Home Outlook")
        .sheet(item: $createdProject) { project in
            NavigationStack { ProjectDetailView(project: project) }
        }
        .sheet(isPresented: $showExplanation) {
            NavigationStack {
                List {
                    Section("Home Systems") {
                        Text("Uses the installation date and the service-life years saved on the system record.")
                    }
                    Section("Devices & Equipment") {
                        Text("Uses the recorded purchase date with a typical-life assumption based on the item category. Technology such as routers generally receives a shorter planning window than major appliances or tools.")
                    }
                    Section("Fixtures") {
                        Text("Uses installation date when available, otherwise purchase date, with a category-based typical-life assumption.")
                    }
                    Section("Costs") {
                        Text("Known-cost totals use the purchase/install cost you recorded. They are baselines only and are not adjusted for inflation or future labor prices.")
                    }
                }
                .navigationTitle("How Estimates Work")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { showExplanation = false } }
                }
            }
        }
    }

    @ViewBuilder
    private func outlookMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func horizonRow(title: String, years: Int) -> some View {
        let items = itemsWithin(years: years)
        let total = items.compactMap(\.baselineCost).reduce(0, +)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if total > 0 {
                Text(total.formatted(AppFormatting.currency)).font(.subheadline.weight(.semibold))
            } else {
                Text("No known costs").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var groupedYears: [Int] {
        Array(Set(visibleItems.map { Calendar.current.component(.year, from: $0.projectedDate) })).sorted()
    }

    private func itemsWithin(years: Int) -> [HomeOutlookItem] {
        guard let cutoff = Calendar.current.date(byAdding: .year, value: years, to: .now) else { return [] }
        return allItems.filter { $0.projectedDate <= cutoff }
    }

    private func existingProject(for item: HomeOutlookItem) -> Project? {
        let expectedTitle = "Replace \(item.name)"
        return projects.first {
            $0.stage != .completed
            && $0.title.caseInsensitiveCompare(expectedTitle) == .orderedSame
            && $0.room?.persistentModelID == item.room?.persistentModelID
        }
    }

    private func createReplacementProject(for item: HomeOutlookItem) {
        guard existingProject(for: item) == nil else { return }
        let target = max(item.projectedDate, Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now)
        let project = Project(
            title: "Replace \(item.name)",
            projectDescription: "Plan replacement for \(item.name). Home Maintainer estimated this planning window from the recorded purchase/installation date and a \(item.serviceLifeYears)-year service-life assumption.",
            stage: .planning,
            targetDate: target,
            budget: item.baselineCost,
            notes: item.baselineCost == nil ? "Add an estimated replacement budget as you research options." : "Budget starts with the recorded historical cost as a baseline; update it as current pricing becomes known.",
            roomName: item.locationName,
            room: item.room
        )
        modelContext.insert(project)
        try? modelContext.save()
        createdProject = project
    }

    private func status(_ date: Date) -> String {
        if date < .now { return "Past estimate" }
        let months = Calendar.current.dateComponents([.month], from: .now, to: date).month ?? 0
        if months <= 12 { return "Plan soon" }
        if months <= 36 { return "Coming up" }
        return "Future"
    }

    private func statusColor(_ date: Date) -> Color {
        if date < .now { return .red }
        let months = Calendar.current.dateComponents([.month], from: .now, to: date).month ?? 0
        return months <= 12 ? .orange : .secondary
    }

    private func applianceLife(_ value: String) -> Int {
        let value = value.lowercased()
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
