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
            Section("Home Setup") {
                NavigationLink { HomeSetupView() } label: { Label("Home Setup", systemImage: "checklist.checked") }
                NavigationLink { HomeProfileView() } label: { Label("Home Profile", systemImage: "house") }
                Text("Use Home Setup to review the structure and quality of your home record. Maintenance planning, warranties, and history live under My Home.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                LabeledContent("Build", value: "0.20")
                Text("Home Maintainer keeps maintenance, home records, vendors, documents, and projects connected in one place.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .alert("Notifications Updated", isPresented: $didReschedule) { Button("OK", role: .cancel) {} } message: { Text("Pending task reminders were refreshed using your current settings.") }
    }
}
