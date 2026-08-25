import SwiftUI
import SwiftData

struct HomeProfileView: View {
    @Query private var homes: [Home]

    var body: some View {
        if let home = homes.first {
            List {
                Section("Home") {
                    LabeledContent("Name", value: home.name)
                    if !home.address.isEmpty { LabeledContent("Address", value: home.address) }
                    if let year = home.yearBuilt { LabeledContent("Year built", value: String(year)) }
                    if let date = home.purchaseDate { LabeledContent("Purchased", value: date.formatted(date: .abbreviated, time: .omitted)) }
                    if let squareFeet = home.squareFeet { LabeledContent("Square feet", value: squareFeet.formatted()) }
                }
                if !home.notes.isEmpty { Section("Notes") { Text(home.notes) } }
            }
            .navigationTitle("Home Profile")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink("Edit") { HomeProfileFormView(home: home) } } }
        } else {
            ContentUnavailableView("No home profile", systemImage: "house", description: Text("A home profile will be created when the app is initialized."))
        }
    }
}

struct HomeProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let home: Home
    @State private var name: String
    @State private var address: String
    @State private var yearBuilt: String
    @State private var squareFeet: String
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var notes: String

    init(home: Home) {
        self.home = home
        _name = State(initialValue: home.name)
        _address = State(initialValue: home.address)
        _yearBuilt = State(initialValue: home.yearBuilt.map { String($0) } ?? "")
        _squareFeet = State(initialValue: home.squareFeet.map { String($0) } ?? "")
        _hasPurchaseDate = State(initialValue: home.purchaseDate != nil)
        _purchaseDate = State(initialValue: home.purchaseDate ?? .now)
        _notes = State(initialValue: home.notes)
    }

    var body: some View {
        Form {
            Section("Home") {
                TextField("Home name", text: $name)
                TextField("Address", text: $address)
                TextField("Year built", text: $yearBuilt).keyboardType(.numberPad)
                TextField("Square feet", text: $squareFeet).keyboardType(.numberPad)
            }
            Section("Purchase") {
                Toggle("Record purchase date", isOn: $hasPurchaseDate)
                if hasPurchaseDate { DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date) }
            }
            Section("Notes") { TextField("Notes", text: $notes, axis: .vertical) }
        }
        .navigationTitle("Edit Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }

    private func save() {
        home.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        home.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        home.yearBuilt = Int(yearBuilt)
        home.squareFeet = Int(squareFeet)
        home.purchaseDate = hasPurchaseDate ? purchaseDate : nil
        home.notes = notes
        try? modelContext.save()
        dismiss()
    }
}

struct AppSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [MaintenanceTask]
    @AppStorage("notificationLeadEnabled") private var leadEnabled = true
    @AppStorage("notificationDueEnabled") private var dueEnabled = true
    @AppStorage("notificationOverdueEnabled") private var overdueEnabled = true
    @AppStorage("notificationHour") private var notificationHour = 9
    @State private var didReschedule = false

    var body: some View {
        List {
            Section("Home") {
                NavigationLink { HomeProfileView() } label: { Label("Home Profile", systemImage: "house") }
                NavigationLink { HomeInsightsView() } label: { Label("Home Insights", systemImage: "chart.bar.xaxis") }
                NavigationLink { HomeHistoryView() } label: { Label("Home History", systemImage: "clock.arrow.circlepath") }
                NavigationLink { WarrantyCenterView() } label: { Label("Warranty Center", systemImage: "shield") }
                NavigationLink { RecommendedMaintenanceView() } label: { Label("Recommended Maintenance", systemImage: "checklist.checked") }
                NavigationLink { SeasonalMaintenanceView() } label: { Label("Seasonal Planning", systemImage: "calendar.badge.clock") }
                NavigationLink { ReplacementForecastView() } label: { Label("Replacement Forecast", systemImage: "chart.line.uptrend.xyaxis") }
            }
            Section("Data & Transfer") {
                NavigationLink { HomeTransferView() } label: { Label("Home Transfer", systemImage: "house.and.flag") }
                NavigationLink { DataExportView() } label: { Label("Backup / Export Data", systemImage: "externaldrive.badge.plus") }
            }
            Section("Notifications") {
                Toggle("Lead-time reminders", isOn: $leadEnabled)
                Toggle("Due-date reminders", isOn: $dueEnabled)
                Toggle("Overdue reminders", isOn: $overdueEnabled)
                Picker("Reminder time", selection: $notificationHour) {
                    ForEach(6...21, id: \.self) { hour in
                        Text(Calendar.current.date(from: DateComponents(hour: hour))?.formatted(date: .omitted, time: .shortened) ?? "\(hour):00").tag(hour)
                    }
                }
                Button("Apply Notification Settings") {
                    Task {
                        for task in tasks { await NotificationManager.shared.schedule(for: task) }
                        await MainActor.run { didReschedule = true }
                    }
                }
            }
            Section("About") {
                LabeledContent("App", value: "Home Maintainer")
                LabeledContent("Build", value: "0.13.1")
                Text("Home Maintainer keeps maintenance, home records, vendors, documents, and projects connected in one place.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .alert("Notifications Updated", isPresented: $didReschedule) { Button("OK", role: .cancel) {} } message: { Text("Pending task reminders were refreshed using your current settings.") }
    }
}

private struct MaintenancePreset: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: TaskCategory
    let recurrence: RecurrenceRule
    let leadDays: Int
    let firstDueMonths: Int
    let tags: Set<String>
}

struct RecommendedMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [MaintenanceTask]
    @State private var furnace = true
    @State private var airConditioning = true
    @State private var well = false
    @State private var septic = false
    @State private var sumpPump = false
    @State private var generator = false
    @State private var fireplace = false

    private let presets: [MaintenancePreset] = [
        .init(title: "Test smoke & CO alarms", description: "Test all smoke and carbon monoxide alarms.", category: .safety, recurrence: .monthly, leadDays: 0, firstDueMonths: 1, tags: ["basic"]),
        .init(title: "Replace detector batteries", description: "Replace batteries in detectors that do not use sealed batteries.", category: .safety, recurrence: .sixMonths, leadDays: 14, firstDueMonths: 6, tags: ["basic"]),
        .init(title: "Inspect fire extinguishers", description: "Check pressure, condition, access, and expiration/service information.", category: .safety, recurrence: .monthly, leadDays: 7, firstDueMonths: 1, tags: ["basic"]),
        .init(title: "Replace HVAC filter", description: "Replace or clean the HVAC air filter.", category: .hvac, recurrence: .quarterly, leadDays: 7, firstDueMonths: 3, tags: ["furnace", "ac"]),
        .init(title: "Schedule annual heating service", description: "Schedule professional heating-system inspection and service.", category: .hvac, recurrence: .annually, leadDays: 60, firstDueMonths: 12, tags: ["furnace"]),
        .init(title: "Schedule annual AC service", description: "Schedule professional cooling-system inspection and service.", category: .hvac, recurrence: .annually, leadDays: 45, firstDueMonths: 12, tags: ["ac"]),
        .init(title: "Test sump pump", description: "Test pump operation and inspect discharge path.", category: .plumbing, recurrence: .quarterly, leadDays: 7, firstDueMonths: 3, tags: ["sump"]),
        .init(title: "Inspect well system", description: "Review pressure tank, visible plumbing, and water-system condition.", category: .plumbing, recurrence: .annually, leadDays: 30, firstDueMonths: 12, tags: ["well"]),
        .init(title: "Schedule septic inspection", description: "Review septic maintenance needs and pumping history.", category: .plumbing, recurrence: .annually, leadDays: 60, firstDueMonths: 12, tags: ["septic"]),
        .init(title: "Exercise generator", description: "Run generator and check fuel, oil, battery, and general operation.", category: .electrical, recurrence: .monthly, leadDays: 0, firstDueMonths: 1, tags: ["generator"]),
        .init(title: "Inspect fireplace / chimney", description: "Inspect fireplace and schedule cleaning/service as appropriate.", category: .safety, recurrence: .annually, leadDays: 60, firstDueMonths: 12, tags: ["fireplace"]),
        .init(title: "Clean dryer vent", description: "Clean dryer exhaust duct and exterior vent.", category: .appliances, recurrence: .annually, leadDays: 30, firstDueMonths: 12, tags: ["basic"]),
        .init(title: "Clean gutters", description: "Clear gutters and verify downspout drainage.", category: .exterior, recurrence: .sixMonths, leadDays: 14, firstDueMonths: 6, tags: ["basic"]),
        .init(title: "Inspect roof and exterior", description: "Look for damaged roofing, flashing, siding, caulk, and drainage issues.", category: .exterior, recurrence: .annually, leadDays: 30, firstDueMonths: 12, tags: ["basic"])
    ]

    private var enabledTags: Set<String> {
        var tags: Set<String> = ["basic"]
        if furnace { tags.insert("furnace") }
        if airConditioning { tags.insert("ac") }
        if well { tags.insert("well") }
        if septic { tags.insert("septic") }
        if sumpPump { tags.insert("sump") }
        if generator { tags.insert("generator") }
        if fireplace { tags.insert("fireplace") }
        return tags
    }

    private var recommended: [MaintenancePreset] { presets.filter { !$0.tags.isDisjoint(with: enabledTags) } }

    var body: some View {
        List {
            Section("Your Home") {
                Toggle("Heating system", isOn: $furnace)
                Toggle("Air conditioning", isOn: $airConditioning)
                Toggle("Well", isOn: $well)
                Toggle("Septic", isOn: $septic)
                Toggle("Sump pump", isOn: $sumpPump)
                Toggle("Generator", isOn: $generator)
                Toggle("Fireplace / chimney", isOn: $fireplace)
            }
            Section("Suggested Tasks") {
                ForEach(recommended) { preset in
                    let alreadyAdded = tasks.contains { $0.title.caseInsensitiveCompare(preset.title) == .orderedSame }
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.title).font(.headline)
                            Text(preset.description).font(.caption).foregroundStyle(.secondary)
                            Text(preset.recurrence.rawValue).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if alreadyAdded {
                            Label("Added", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                        } else {
                            Button("Add") { add(preset) }.buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            Section {
                Button("Add All Missing Recommendations") {
                    for preset in recommended where !tasks.contains(where: { $0.title.caseInsensitiveCompare(preset.title) == .orderedSame }) { add(preset) }
                }
            }
        }
        .navigationTitle("Recommended Maintenance")
    }

    private func add(_ preset: MaintenancePreset) {
        guard !tasks.contains(where: { $0.title.caseInsensitiveCompare(preset.title) == .orderedSame }) else { return }
        let due = Calendar.current.date(byAdding: .month, value: preset.firstDueMonths, to: Calendar.current.startOfDay(for: .now)) ?? .now
        let task = MaintenanceTask(title: preset.title, taskDescription: preset.description, category: preset.category, dueDate: due, leadTimeDays: preset.leadDays, recurrence: preset.recurrence, recurrenceAnchor: .scheduledDate, priority: preset.category == .safety ? 3 : 2)
        modelContext.insert(task)
        try? modelContext.save()
        Task { await NotificationManager.shared.schedule(for: task) }
    }
}
