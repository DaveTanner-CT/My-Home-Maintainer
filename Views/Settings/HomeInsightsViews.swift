import SwiftUI
import SwiftData

struct HomeInsightsView: View {
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var detectors: [Detector]
    @Query private var consumables: [Consumable]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var records: [MaintenanceRecord]
    @Query private var projects: [Project]
    @Query private var attachments: [HomeAttachment]

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var soon: Date { Calendar.current.date(byAdding: .day, value: 90, to: today) ?? today }
    private var expiringSystems: [HomeSystem] { systems.filter { guard let d = $0.warrantyExpiration else { return false }; return d >= today && d <= soon } }
    private var expiringAppliances: [Appliance] { appliances.filter { guard let d = $0.warrantyExpiration else { return false }; return d >= today && d <= soon } }
    private var replacementDetectors: [Detector] { detectors.filter { guard let d = $0.replacementDate else { return false }; return d <= soon } }
    private var replacementConsumables: [Consumable] { consumables.filter { guard let d = $0.nextReplacement else { return false }; return d <= soon } }
    private var activeProjects: [Project] { projects.filter { $0.stage != .completed } }
    private var thisYearRecords: [MaintenanceRecord] { records.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .year) } }
    private var thisYearSpend: Double { thisYearRecords.compactMap(\.cost).reduce(0, +) }

    var body: some View {
        List {
            Section("Home Health") {
                insightRow("Warranties expiring in 90 days", count: expiringSystems.count + expiringAppliances.count, icon: "shield.lefthalf.filled")
                insightRow("Detector replacements due soon", count: replacementDetectors.count, icon: "sensor.tag.radiowaves.forward")
                insightRow("Consumables due soon", count: replacementConsumables.count, icon: "arrow.triangle.2.circlepath")
                insightRow("Active projects", count: activeProjects.count, icon: "hammer")
                insightRow("Stored photos & documents", count: attachments.count, icon: "paperclip")
            }

            Section("Maintenance This Year") {
                LabeledContent("Completed records", value: thisYearRecords.count.formatted())
                LabeledContent("Recorded spending", value: thisYearSpend.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                if let latest = records.first {
                    LabeledContent("Most recent", value: latest.date.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if !expiringSystems.isEmpty || !expiringAppliances.isEmpty {
                Section("Warranty Watch") {
                    ForEach(expiringSystems) { system in
                        NavigationLink { HomeSystemDetailView(system: system) } label: {
                            warningRow(name: system.name, date: system.warrantyExpiration, subtitle: "Home System")
                        }
                    }
                    ForEach(expiringAppliances) { appliance in
                        NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                            warningRow(name: appliance.name, date: appliance.warrantyExpiration, subtitle: "Appliance")
                        }
                    }
                }
            }

            if !replacementDetectors.isEmpty || !replacementConsumables.isEmpty {
                Section("Replacement Watch") {
                    ForEach(replacementDetectors) { detector in
                        NavigationLink { DetectorDetailView(detector: detector) } label: {
                            warningRow(name: "\(detector.type) detector", date: detector.replacementDate, subtitle: detector.location)
                        }
                    }
                    ForEach(replacementConsumables) { item in
                        NavigationLink { ConsumableDetailView(consumable: item) } label: {
                            warningRow(name: item.name, date: item.nextReplacement, subtitle: "Consumable")
                        }
                    }
                }
            }

            if !records.isEmpty {
                Section("Recent Maintenance") {
                    ForEach(records.prefix(8)) { record in
                        NavigationLink { MaintenanceRecordDetailView(record: record) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.title).font(.headline)
                                HStack {
                                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                    if let cost = record.cost { Text("• \(cost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Home Insights")
    }

    private func insightRow(_ title: String, count: Int, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(count.formatted()).font(.headline).foregroundStyle(count == 0 ? .secondary : .primary)
        }
    }

    private func warningRow(name: String, date: Date?, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.headline)
            HStack {
                Text(subtitle)
                if let date { Text("• \(date.formatted(date: .abbreviated, time: .omitted))") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct WarrantyCenterView: View {
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]

    private var entries: [WarrantyEntry] {
        let systemEntries = systems.compactMap { item -> WarrantyEntry? in
            guard let date = item.warrantyExpiration else { return nil }
            return .init(name: item.name, kind: "Home System", date: date, destination: AnyView(HomeSystemDetailView(system: item)))
        }
        let applianceEntries = appliances.compactMap { item -> WarrantyEntry? in
            guard let date = item.warrantyExpiration else { return nil }
            return .init(name: item.name, kind: "Appliance", date: date, destination: AnyView(ApplianceDetailView(appliance: item)))
        }
        return (systemEntries + applianceEntries).sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No warranties recorded", systemImage: "shield", description: Text("Add warranty expiration dates to Home Systems and Appliances to track them here."))
            } else {
                ForEach(entries) { entry in
                    NavigationLink { entry.destination } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name).font(.headline)
                                Text(entry.kind).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.subheadline)
                                Text(statusText(for: entry.date)).font(.caption).foregroundStyle(statusColor(for: entry.date))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Warranty Center")
    }

    private func statusText(for date: Date) -> String {
        let today = Calendar.current.startOfDay(for: .now)
        if date < today { return "Expired" }
        let days = Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
        if days <= 30 { return "\(days) days" }
        if days <= 90 { return "Soon" }
        return "Active"
    }

    private func statusColor(for date: Date) -> Color {
        let today = Calendar.current.startOfDay(for: .now)
        if date < today { return .red }
        let days = Calendar.current.dateComponents([.day], from: today, to: date).day ?? 0
        if days <= 30 { return .orange }
        return .secondary
    }
}

private struct WarrantyEntry: Identifiable {
    let id = UUID()
    let name: String
    let kind: String
    let date: Date
    let destination: AnyView
}

struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var exportDocument: HomeArchiveDocument?
    @State private var showExporter = false
    @State private var exportError: String?

    var body: some View {
        List {
            Section("Home Archive") {
                Text("Export a structured JSON archive of your home records, projects, maintenance history, and stored attachments. Attachment file data is included in the archive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    createExport()
                } label: {
                    Label("Export Home Archive", systemImage: "square.and.arrow.up")
                }
            }
            Section("About this export") {
                Text("This release creates an archive you can save outside the app. Automatic restore/import is not enabled yet; that will be added after the archive format has been tested on real data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Export Data")
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "HomeMaintainer-Archive-\(Date.now.formatted(.iso8601.year().month().day()))") { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("Export Error", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: { Text(exportError ?? "Unable to export the archive.") }
    }

    private func createExport() {
        do {
            exportDocument = HomeArchiveDocument(data: try HomeExportService.encodedArchive(context: modelContext))
            showExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}
