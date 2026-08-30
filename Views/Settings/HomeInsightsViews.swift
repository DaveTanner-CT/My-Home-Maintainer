import SwiftUI
import SwiftData

struct HomeInsightsView: View {
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]
    @Query private var detectors: [Detector]
    @Query private var consumables: [Consumable]
    @Query(sort: \MaintenanceRecord.date, order: .reverse) private var records: [MaintenanceRecord]
    @Query private var projects: [Project]
    @Query private var attachments: [HomeAttachment]

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var soon: Date { Calendar.current.date(byAdding: .day, value: 90, to: today) ?? today }
    private var expiringSystems: [HomeSystem] { systems.filter { guard let d = $0.warrantyExpiration else { return false }; return d >= today && d <= soon } }
    private var expiringAppliances: [Appliance] { appliances.filter { guard let d = $0.warrantyExpiration else { return false }; return d >= today && d <= soon } }
    private var expiringFixtures: [Fixture] { fixtures.filter { guard let d = $0.warrantyExpiration else { return false }; return d >= today && d <= soon } }
    private var replacementDetectors: [Detector] { detectors.filter { guard let d = $0.replacementDate else { return false }; return d <= soon } }
    private var replacementConsumables: [Consumable] { consumables.filter { guard let d = $0.nextReplacement else { return false }; return d <= soon } }
    private var activeProjects: [Project] { projects.filter { $0.stage != .completed } }
    private var thisYearRecords: [MaintenanceRecord] { records.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .year) } }
    private var thisYearSpend: Double { thisYearRecords.compactMap(\.cost).reduce(0, +) }

    var body: some View {
        List {
            Section("Home Health") {
                NavigationLink { WarrantyCenterView() } label: {
                    insightRow("Warranties expiring in 90 days", count: expiringSystems.count + expiringAppliances.count + expiringFixtures.count, icon: "shield.lefthalf.filled")
                }
                NavigationLink { DetectorsListView() } label: {
                    insightRow("Detector replacements due soon", count: replacementDetectors.count, icon: "sensor.tag.radiowaves.forward")
                }
                NavigationLink { ConsumablesListView() } label: {
                    insightRow("Consumables due soon", count: replacementConsumables.count, icon: "arrow.triangle.2.circlepath")
                }
                NavigationLink { ProjectsView() } label: {
                    insightRow("Active projects", count: activeProjects.count, icon: "hammer")
                }
                NavigationLink { StoredAttachmentLibraryView(attachments: attachments) } label: {
                    insightRow("Stored photos & documents", count: attachments.count, icon: "paperclip")
                }
            }

            Section("Maintenance This Year") {
                NavigationLink { HomeHistoryView() } label: {
                    LabeledContent("Completed records", value: thisYearRecords.count.formatted())
                }
                NavigationLink { HomeHistoryView() } label: {
                    LabeledContent("Recorded spending", value: thisYearSpend.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                }
                if let latest = records.first {
                    NavigationLink { MaintenanceRecordDetailView(record: latest) } label: {
                        LabeledContent("Most recent", value: latest.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }

            if !expiringSystems.isEmpty || !expiringAppliances.isEmpty || !expiringFixtures.isEmpty {
                Section("Warranty Watch") {
                    ForEach(expiringSystems) { system in
                        NavigationLink { SystemDetailView(system: system) } label: {
                            warningRow(name: system.name, date: system.warrantyExpiration, subtitle: "Home System")
                        }
                    }
                    ForEach(expiringAppliances) { appliance in
                        NavigationLink { ApplianceDetailView(appliance: appliance) } label: {
                            warningRow(name: appliance.name, date: appliance.warrantyExpiration, subtitle: "Device / Equipment")
                        }
                    }
                    ForEach(expiringFixtures) { fixture in
                        NavigationLink { FixtureDetailView(fixture: fixture) } label: {
                            warningRow(name: fixture.name, date: fixture.warrantyExpiration, subtitle: "Fixture")
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
                        NavigationLink { ConsumableDetailView(item: item) } label: {
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


private struct StoredAttachmentLibraryView: View {
    let attachments: [HomeAttachment]

    var body: some View {
        List {
            if attachments.isEmpty {
                ContentUnavailableView("No stored files", systemImage: "paperclip")
            } else {
                ForEach(attachments.sorted { $0.createdAt > $1.createdAt }) { attachment in
                    NavigationLink { AttachmentDetailView(attachment: attachment) } label: {
                        AttachmentRow(attachment: attachment)
                    }
                }
            }
        }
        .navigationTitle("Photos & Documents")
    }
}

struct WarrantyCenterView: View {
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]

    private var entries: [WarrantyEntry] {
        let systemEntries = systems.compactMap { item -> WarrantyEntry? in
            guard let date = item.warrantyExpiration else { return nil }
            return .init(name: item.name, kind: "Home System", date: date, destination: AnyView(SystemDetailView(system: item)))
        }
        let applianceEntries = appliances.compactMap { item -> WarrantyEntry? in
            guard let date = item.warrantyExpiration else { return nil }
            return .init(name: item.name, kind: "Device / Equipment", date: date, destination: AnyView(ApplianceDetailView(appliance: item)))
        }
        let fixtureEntries = fixtures.compactMap { item -> WarrantyEntry? in
            guard let date = item.warrantyExpiration else { return nil }
            return .init(name: item.name, kind: "Fixture", date: date, destination: AnyView(FixtureDetailView(fixture: item)))
        }
        return (systemEntries + applianceEntries + fixtureEntries).sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("No warranties recorded", systemImage: "shield", description: Text("Add warranty expiration dates to fixtures, Home Systems, and devices/equipment to track them here."))
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
    @State private var shareItem: ExportShareItem?
    @State private var exportError: String?

    var body: some View {
        List {
            Section("Home Archive") {
                Text("Create a structured JSON backup of your home records, projects, Home History, and stored attachments. Attachment file data is included in the archive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    createExport()
                } label: {
                    Label("Share / Save Home Backup", systemImage: "square.and.arrow.up")
                }
            }

            Section("Choose where it goes") {
                Text("Home Maintainer now opens the standard iPhone Share sheet first. From there you can choose Save to Files, Google Drive, Mail, AirDrop, Messages, or another compatible app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("For Google Drive, the most reliable route is to choose the Google Drive app directly in the Share sheet. Choosing Save to Files → Google Drive uses Apple's Files provider; if Drive reports that folder contents are unavailable, use the Google Drive share option instead.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About this export") {
                Text("This JSON backup is a readable safety/export copy. The supported restore/import path is Home Transfer, which preserves relationships with stable transfer IDs and validates the package before importing it into a fresh app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup / Export")
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(items: [item.url]) {
                ExportShareFile.remove(item.url)
                shareItem = nil
            }
        }
        .alert("Export Error", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: { Text(exportError ?? "Unable to create the archive.") }
    }

    private func createExport() {
        do {
            let data = try HomeExportService.encodedArchive(context: modelContext)
            let stamp = Date.now.formatted(.iso8601.year().month().day())
            let url = try ExportShareFile.write(data: data, filename: "HomeMaintainer-Backup-\(stamp).json")
            shareItem = ExportShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}

