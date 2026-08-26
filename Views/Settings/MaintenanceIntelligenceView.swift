import SwiftUI
import SwiftData

private enum RecommendationTarget {
    case none
    case room(Room)
    case system(HomeSystem)
    case appliance(Appliance)
    case fixture(Fixture)

    var room: Room? {
        switch self {
        case .none: return nil
        case .room(let room): return room
        case .system(let system): return system.room
        case .appliance(let appliance): return appliance.room
        case .fixture(let fixture): return fixture.room
        }
    }

    var label: String? {
        switch self {
        case .none: return nil
        case .room(let room): return room.name
        case .system(let system): return system.name
        case .appliance(let appliance): return appliance.name
        case .fixture(let fixture): return fixture.name
        }
    }
}

private struct SmartMaintenanceRecommendation: Identifiable {
    let id: String
    let title: String
    let detail: String
    let reason: String
    let category: TaskCategory
    let recurrence: RecurrenceRule
    let leadDays: Int
    let suggestedDue: Date
    let priority: Int
    let target: RecommendationTarget

    var system: HomeSystem? {
        if case .system(let value) = target { return value }
        return nil
    }
    var appliance: Appliance? {
        if case .appliance(let value) = target { return value }
        return nil
    }
    var fixture: Fixture? {
        if case .fixture(let value) = target { return value }
        return nil
    }
}

struct RecommendedMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [MaintenanceTask]
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @Query(sort: \Appliance.name) private var appliances: [Appliance]
    @Query(sort: \Fixture.name) private var fixtures: [Fixture]
    @Query private var detectors: [Detector]
    @Query private var consumables: [Consumable]
    @State private var showHomeSignals = false

    private var recommendations: [SmartMaintenanceRecommendation] {
        var result: [SmartMaintenanceRecommendation] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func due(days: Int) -> Date { cal.date(byAdding: .day, value: days, to: today) ?? today }

        // Baseline life-safety recommendations stay visible even before the inventory is complete.
        result.append(.init(
            id: "baseline-detector-test",
            title: "Test smoke & CO alarms",
            detail: "Test all smoke and carbon monoxide alarms and confirm they can be heard from sleeping areas.",
            reason: detectors.isEmpty ? "Recommended for every home." : "You have \(detectors.count) detector\(detectors.count == 1 ? "" : "s") recorded.",
            category: .safety, recurrence: .monthly, leadDays: 0, suggestedDue: due(days: 7), priority: 2, target: .none
        ))
        result.append(.init(
            id: "baseline-extinguisher",
            title: "Inspect fire extinguishers",
            detail: "Check pressure, condition, access, and service or expiration information.",
            reason: "Recommended for every home.",
            category: .safety, recurrence: .monthly, leadDays: 7, suggestedDue: due(days: 14), priority: 2, target: .none
        ))

        if detectors.contains(where: { !$0.batteryType.lowercased().contains("sealed") && !$0.batteryType.isEmpty }) {
            result.append(.init(
                id: "detector-batteries",
                title: "Replace detector batteries",
                detail: "Replace batteries in recorded detectors that do not use sealed long-life batteries.",
                reason: "At least one recorded detector uses a replaceable battery.",
                category: .safety, recurrence: .sixMonths, leadDays: 14, suggestedDue: due(days: 30), priority: 2, target: .none
            ))
        }

        for detector in detectors {
            if let replacement = detector.replacementDate {
                result.append(.init(
                    id: "detector-replace-\(detector.persistentModelID)",
                    title: "Replace \(detector.type) detector — \(detector.location)",
                    detail: "Replace this detector at the end of its recorded service-life window.",
                    reason: "Replacement date is recorded as \(replacement.formatted(date: .abbreviated, time: .omitted)).",
                    category: .safety, recurrence: .oneTime, leadDays: 60, suggestedDue: replacement, priority: 3, target: room(named: detector.location)
                ))
            }
        }

        for system in systems {
            let text = "\(system.type) \(system.name)".lowercased()
            if containsAny(text, ["furnace", "boiler", "heating", "heat pump", "hvac"]) {
                result.append(rec(
                    id: "heat-\(system.persistentModelID)", title: "Annual heating service — \(system.name)",
                    detail: "Inspect and service the heating equipment before the heating season.",
                    reason: "Detected from Home System: \(system.name).", category: .hvac, recurrence: .annually,
                    leadDays: 45, due: due(days: 45), priority: 2, target: .system(system)
                ))
            }
            if containsAny(text, ["air condition", "cooling", "a/c", " ac ", "heat pump"]) {
                result.append(rec(
                    id: "cool-\(system.persistentModelID)", title: "Annual cooling service — \(system.name)",
                    detail: "Inspect and service cooling equipment, coils, drains, and outdoor components.",
                    reason: "Detected from Home System: \(system.name).", category: .hvac, recurrence: .annually,
                    leadDays: 45, due: due(days: 45), priority: 2, target: .system(system)
                ))
            }
            if containsAny(text, ["furnace", "forced air", "air handler", "hvac", "heat pump"]) {
                result.append(rec(
                    id: "filter-\(system.persistentModelID)", title: "Check HVAC filter — \(system.name)",
                    detail: "Inspect the filter and replace or clean it when needed.",
                    reason: "This looks like an air-moving HVAC system.", category: .hvac, recurrence: .quarterly,
                    leadDays: 7, due: due(days: 30), priority: 1, target: .system(system)
                ))
            }
            if containsAny(text, ["water heater", "hot water", "boiler water"]) {
                result.append(rec(
                    id: "waterheater-\(system.persistentModelID)", title: "Inspect water heater — \(system.name)",
                    detail: "Check for leaks, corrosion, venting or combustion concerns, and follow manufacturer flushing/service guidance.",
                    reason: "Detected from Home System: \(system.name).", category: .plumbing, recurrence: .annually,
                    leadDays: 30, due: due(days: 60), priority: 2, target: .system(system)
                ))
            }
            if text.contains("sump") {
                result.append(rec(
                    id: "sump-\(system.persistentModelID)", title: "Test sump pump — \(system.name)",
                    detail: "Test pump operation, float/switch behavior, backup power if present, and the discharge path.",
                    reason: "Detected from Home System: \(system.name).", category: .plumbing, recurrence: .quarterly,
                    leadDays: 7, due: due(days: 14), priority: 2, target: .system(system)
                ))
            }
            if text.contains("well") {
                result.append(rec(
                    id: "well-\(system.persistentModelID)", title: "Inspect well system — \(system.name)",
                    detail: "Review pressure tank, visible plumbing, controls, and water-system condition.",
                    reason: "Detected from Home System: \(system.name).", category: .plumbing, recurrence: .annually,
                    leadDays: 30, due: due(days: 60), priority: 2, target: .system(system)
                ))
            }
            if text.contains("septic") {
                result.append(rec(
                    id: "septic-\(system.persistentModelID)", title: "Review septic maintenance — \(system.name)",
                    detail: "Review inspection/pumping history and schedule service based on household use and local guidance.",
                    reason: "Detected from Home System: \(system.name).", category: .plumbing, recurrence: .annually,
                    leadDays: 60, due: due(days: 90), priority: 2, target: .system(system)
                ))
            }
            if text.contains("generator") {
                result.append(rec(
                    id: "generator-\(system.persistentModelID)", title: "Exercise generator — \(system.name)",
                    detail: "Run the generator and check fuel, oil, battery, transfer equipment, and general operation.",
                    reason: "Detected from Home System: \(system.name).", category: .electrical, recurrence: .monthly,
                    leadDays: 0, due: due(days: 14), priority: 2, target: .system(system)
                ))
            }
            if containsAny(text, ["fireplace", "chimney", "wood stove"]) {
                result.append(rec(
                    id: "fireplace-\(system.persistentModelID)", title: "Inspect fireplace / chimney — \(system.name)",
                    detail: "Inspect the appliance and chimney and schedule cleaning/service as appropriate.",
                    reason: "Detected from Home System: \(system.name).", category: .safety, recurrence: .annually,
                    leadDays: 60, due: due(days: 60), priority: 2, target: .system(system)
                ))
            }
        }

        for appliance in appliances {
            let text = "\(appliance.category) \(appliance.name)".lowercased()
            if text.contains("dryer") {
                result.append(rec(
                    id: "dryer-\(appliance.persistentModelID)", title: "Clean dryer vent — \(appliance.name)",
                    detail: "Clean the dryer exhaust duct and exterior termination; inspect for crushed or restricted ducting.",
                    reason: "Detected from Device / Equipment: \(appliance.name).", category: .appliances, recurrence: .annually,
                    leadDays: 30, due: due(days: 45), priority: 2, target: .appliance(appliance)
                ))
            }
            if text.contains("dishwasher") {
                result.append(rec(
                    id: "dishwasher-\(appliance.persistentModelID)", title: "Clean dishwasher filter — \(appliance.name)",
                    detail: "Clean the filter/screen and inspect spray arms and door seals.",
                    reason: "Detected from Device / Equipment: \(appliance.name).", category: .appliances, recurrence: .quarterly,
                    leadDays: 7, due: due(days: 30), priority: 1, target: .appliance(appliance)
                ))
            }
            if containsAny(text, ["refrigerator", "fridge", "freezer"]) {
                result.append(rec(
                    id: "refrigerator-\(appliance.persistentModelID)", title: "Inspect refrigerator / freezer — \(appliance.name)",
                    detail: "Clean accessible coils/vents, inspect seals, and check water supply connections if present.",
                    reason: "Detected from Device / Equipment: \(appliance.name).", category: .appliances, recurrence: .annually,
                    leadDays: 14, due: due(days: 60), priority: 1, target: .appliance(appliance)
                ))
            }
            if containsAny(text, ["washer", "washing machine"]) {
                result.append(rec(
                    id: "washer-\(appliance.persistentModelID)", title: "Inspect washer hoses — \(appliance.name)",
                    detail: "Inspect water hoses, valves, drain hose, and visible connections for wear or leaks.",
                    reason: "Detected from Device / Equipment: \(appliance.name).", category: .appliances, recurrence: .annually,
                    leadDays: 14, due: due(days: 60), priority: 1, target: .appliance(appliance)
                ))
            }
            if containsAny(text, ["router", "wifi", "wi-fi", "network", "mesh", "home technology"]) {
                result.append(rec(
                    id: "network-\(appliance.persistentModelID)", title: "Review home network — \(appliance.name)",
                    detail: "Check firmware, backups/configuration, admin credentials, and whether the device still receives security updates.",
                    reason: "Detected from Home Technology: \(appliance.name).", category: .electrical, recurrence: .sixMonths,
                    leadDays: 7, due: due(days: 45), priority: 1, target: .appliance(appliance)
                ))
            }
            if containsAny(text, ["lawn mower", "mower", "snowblower", "snow blower", "outdoor equipment"]) {
                result.append(rec(
                    id: "outdoor-equipment-\(appliance.persistentModelID)", title: "Service outdoor equipment — \(appliance.name)",
                    detail: "Inspect, clean, lubricate, and service this equipment according to its seasonal use and manual.",
                    reason: "Detected from Outdoor Equipment: \(appliance.name).", category: .general, recurrence: .annually,
                    leadDays: 30, due: due(days: 60), priority: 1, target: .appliance(appliance)
                ))
            }
        }

        let plumbingFixtures = fixtures.filter {
            containsAny("\($0.category) \($0.name)".lowercased(), ["faucet", "toilet", "sink", "shower", "tub", "plumb"])
        }
        let plumbingRooms = Dictionary(grouping: plumbingFixtures.compactMap { $0.room }, by: { $0.persistentModelID }).values.compactMap { $0.first }
        for room in plumbingRooms {
            result.append(rec(
                id: "plumbing-room-\(room.persistentModelID)", title: "Inspect plumbing fixtures — \(room.name)",
                detail: "Check faucets, supply connections, drains, toilets, and visible seals for drips, looseness, or moisture.",
                reason: "Plumbing fixtures are recorded in \(room.name).", category: .plumbing, recurrence: .annually,
                leadDays: 14, due: due(days: 60), priority: 1, target: .room(room)
            ))
        }

        for room in rooms where room.areaType == .exterior {
            let text = room.name.lowercased()
            if text.contains("roof") {
                result.append(rec(id: "roof-\(room.persistentModelID)", title: "Inspect roof — \(room.name)", detail: "Inspect roofing, flashing, penetrations, drainage, and visible storm damage.", reason: "Exterior / Property area detected: \(room.name).", category: .exterior, recurrence: .annually, leadDays: 30, due: due(days: 45), priority: 2, target: .room(room)))
            }
            if containsAny(text, ["gutter", "drainage", "downspout"]) {
                result.append(rec(id: "gutter-\(room.persistentModelID)", title: "Clean and inspect drainage — \(room.name)", detail: "Clear debris and verify gutters/downspouts/drainage move water away from the structure.", reason: "Exterior drainage area detected: \(room.name).", category: .exterior, recurrence: .sixMonths, leadDays: 14, due: due(days: 30), priority: 2, target: .room(room)))
            }
            if containsAny(text, ["deck", "patio", "steps", "porch"]) {
                result.append(rec(id: "deck-\(room.persistentModelID)", title: "Inspect deck / steps — \(room.name)", detail: "Check walking surfaces, fasteners, supports, stairs, and railings for movement, rot, or damage.", reason: "Exterior structure detected: \(room.name).", category: .exterior, recurrence: .annually, leadDays: 14, due: due(days: 60), priority: 2, target: .room(room)))
            }
        }

        for consumable in consumables {
            if let next = consumable.nextReplacement {
                result.append(.init(
                    id: "consumable-\(consumable.persistentModelID)", title: "Replace \(consumable.name)",
                    detail: "Replace the recorded consumable and update its replacement date in My Home.",
                    reason: "Next replacement is recorded as \(next.formatted(date: .abbreviated, time: .omitted)).",
                    category: .general, recurrence: recurrence(forMonths: consumable.replacementIntervalMonths), leadDays: 7,
                    suggestedDue: next, priority: 1, target: .none
                ))
            }
        }

        return result.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.suggestedDue < $1.suggestedDue
        }
    }

    private var missingRecommendations: [SmartMaintenanceRecommendation] {
        recommendations.filter { recommendation in
            !tasks.contains { task in
                !task.isCompleted && task.title.caseInsensitiveCompare(recommendation.title) == .orderedSame
            }
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Personalized to this home", systemImage: "sparkles")
                        .font(.headline)
                    Text("These suggestions are generated from the systems, devices, fixtures, safety equipment, consumables, and exterior areas you have recorded.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                NavigationLink { MyHomeView() } label: {
                    Label("Review My Home Inventory", systemImage: "house")
                }
            }

            Section("Recommended for This Home") {
                if recommendations.isEmpty {
                    Text("Add systems, devices, fixtures, and exterior/property areas in My Home to receive personalized recommendations.")
                        .foregroundStyle(.secondary)
                }
                ForEach(recommendations) { recommendation in
                    recommendationRow(recommendation)
                }
            }

            if !missingRecommendations.isEmpty {
                Section {
                    Button("Add All Missing Recommendations") {
                        for recommendation in missingRecommendations { add(recommendation) }
                    }
                } footer: {
                    Text("This uses the suggested dates shown above. Open an individual recommendation instead if you want to review or change its schedule first.")
                }
            }

            Section {
                DisclosureGroup(isExpanded: $showHomeSignals) {
                    VStack(alignment: .leading, spacing: 0) {
                        signalLink(
                            title: "Home Systems",
                            count: systems.count,
                            icon: "gearshape.2",
                            explanation: "Used to identify service, filter, inspection, and replacement needs."
                        ) { SystemsListView() }
                        Divider().padding(.leading, 36)
                        signalLink(
                            title: "Devices & Equipment",
                            count: appliances.count,
                            icon: "washer",
                            explanation: "Used to suggest care for appliances, electronics, tools, and equipment."
                        ) { AppliancesListView() }
                        Divider().padding(.leading, 36)
                        signalLink(
                            title: "Fixtures",
                            count: fixtures.count,
                            icon: "wrench.and.screwdriver",
                            explanation: fixtures.isEmpty
                                ? "None recorded. Add faucets, toilets, lighting, and other fixtures for room-specific maintenance and warranty tracking."
                                : "Used for room-specific maintenance, warranty tracking, and plumbing/fixture inspections."
                        ) { FixturesListView() }
                        Divider().padding(.leading, 36)
                        signalLink(
                            title: "Exterior / Property Areas",
                            count: rooms.filter { $0.areaType == .exterior }.count,
                            icon: "leaf",
                            explanation: "Used to identify seasonal inspections for roofs, drainage, decks, patios, and other exterior spaces."
                        ) { RoomsListView() }
                        Divider().padding(.leading, 36)
                        signalLink(
                            title: "Safety Detectors",
                            count: detectors.count,
                            icon: "sensor",
                            explanation: "Used to track testing, batteries, and replacement dates."
                        ) { DetectorsListView() }
                        Divider().padding(.leading, 36)
                        signalLink(
                            title: "Consumables",
                            count: consumables.count,
                            icon: "shippingbox",
                            explanation: "Used for filters, cartridges, batteries, and other replaceable items with recurring dates."
                        ) { ConsumablesListView() }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Why am I seeing these?", systemImage: "info.circle")
                            .font(.headline)
                        Text("See what Home Maintainer found in your inventory and how each type of record affects these recommendations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Recommended Maintenance")
    }

    @ViewBuilder
    private func recommendationRow(_ recommendation: SmartMaintenanceRecommendation) -> some View {
        let existing = tasks.first { !$0.isCompleted && $0.title.caseInsensitiveCompare(recommendation.title) == .orderedSame }
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(recommendation.title).font(.headline)
                Spacer()
                if let existing {
                    NavigationLink { TaskDetailView(task: existing) } label: {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            Text(recommendation.detail).font(.caption).foregroundStyle(.secondary)
            Label(recommendation.reason, systemImage: "link")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(recommendation.recurrence.rawValue)
                Text("Suggested: \(recommendation.suggestedDue.formatted(date: .abbreviated, time: .omitted))")
                if let label = recommendation.target.label { Text(label) }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if existing == nil {
                HStack {
                    NavigationLink {
                        TaskFormView(
                            initialRoom: recommendation.target.room,
                            initialSystem: recommendation.system,
                            initialAppliance: recommendation.appliance,
                            initialFixture: recommendation.fixture,
                            initialTitle: recommendation.title,
                            initialDescription: recommendation.detail,
                            initialCategory: recommendation.category,
                            initialDueDate: recommendation.suggestedDue,
                            initialLeadTimeDays: recommendation.leadDays,
                            initialRecurrence: recommendation.recurrence,
                            initialPriority: recommendation.priority
                        )
                    } label: {
                        Label("Review & Add", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Quick Add") { add(recommendation) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func signalLink<Destination: View>(
        title: String,
        count: Int,
        icon: String,
        explanation: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(count) recorded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    private func add(_ recommendation: SmartMaintenanceRecommendation) {
        guard !tasks.contains(where: { !$0.isCompleted && $0.title.caseInsensitiveCompare(recommendation.title) == .orderedSame }) else { return }
        let task = MaintenanceTask(
            title: recommendation.title,
            taskDescription: recommendation.detail,
            category: recommendation.category,
            dueDate: recommendation.suggestedDue,
            leadTimeDays: recommendation.leadDays,
            recurrence: recommendation.recurrence,
            recurrenceAnchor: .scheduledDate,
            priority: recommendation.priority,
            room: recommendation.target.room,
            system: recommendation.system,
            appliance: recommendation.appliance,
            fixture: recommendation.fixture
        )
        modelContext.insert(task)
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
    }

    private func rec(id: String, title: String, detail: String, reason: String, category: TaskCategory, recurrence: RecurrenceRule, leadDays: Int, due: Date, priority: Int, target: RecommendationTarget) -> SmartMaintenanceRecommendation {
        .init(id: id, title: title, detail: detail, reason: reason, category: category, recurrence: recurrence, leadDays: leadDays, suggestedDue: due, priority: priority, target: target)
    }

    private func room(named value: String) -> RecommendationTarget {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let room = rooms.first(where: { $0.name.caseInsensitiveCompare(normalized) == .orderedSame }) else { return .none }
        return .room(room)
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private func recurrence(forMonths months: Int?) -> RecurrenceRule {
        guard let months else { return .oneTime }
        switch months {
        case 1: return .monthly
        case 3: return .quarterly
        case 6: return .sixMonths
        case 12: return .annually
        default: return .oneTime
        }
    }
}
