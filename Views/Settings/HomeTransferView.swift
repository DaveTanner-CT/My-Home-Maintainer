import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeTransferView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var homes: [Home]
    @Query private var rooms: [Room]
    @Query private var vendors: [Vendor]
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]
    @Query private var paints: [PaintFinish]
    @Query private var projects: [Project]
    @Query private var projectItems: [ProjectItem]
    @Query private var measurements: [ProjectMeasurement]
    @Query private var tasks: [MaintenanceTask]
    @Query private var history: [MaintenanceRecord]
    @Query private var detectors: [Detector]
    @Query private var consumables: [Consumable]
    @Query private var attachments: [HomeAttachment]

    @State private var shareItem: ExportShareItem?
    @State private var showImporter = false
    @State private var pendingArchive: HomeTransferArchive?
    @State private var preview: TransferPreview?
    @State private var message: String?
    @State private var importSucceeded = false
    @State private var exportSucceeded = false
    @State private var showImportConfirmation = false

    private var isEmpty: Bool {
        homes.isEmpty && rooms.isEmpty && vendors.isEmpty && systems.isEmpty && appliances.isEmpty && fixtures.isEmpty && paints.isEmpty && projects.isEmpty && projectItems.isEmpty && measurements.isEmpty && tasks.isEmpty && history.isEmpty && detectors.isEmpty && consumables.isEmpty && attachments.isEmpty
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Move the home's digital record with the house", systemImage: "house.and.flag")
                        .font(.headline)
                    Text("Create a Home Maintainer transfer package for a future owner. The package preserves stable links between rooms, projects, fixtures, appliances/electronics/equipment, systems, tasks, warranties, history, vendors, and stored documents.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Current Home") {
                if let home = homes.first {
                    LabeledContent("Home", value: home.name)
                    if !home.address.isEmpty { LabeledContent("Address", value: home.address) }
                }
                LabeledContent("Rooms & Areas", value: "\(rooms.count)")
                LabeledContent("Installed Assets", value: "\(systems.count + appliances.count + fixtures.count)")
                LabeledContent("Projects", value: "\(projects.count)")
                LabeledContent("Home History", value: "\(history.count)")
                LabeledContent("Files", value: "\(attachments.count)")
            }

            Section("Seller / Current Owner") {
                Button { createTransfer() } label: {
                    Label("Create & Share New Owner Transfer", systemImage: "square.and.arrow.up")
                }
                Text("Home Maintainer opens the standard iPhone Share sheet so you can choose Google Drive, Save to Files, Mail, AirDrop, Messages, or another compatible app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("For Google Drive, choose the Google Drive app directly in the Share sheet when possible. Save to Files → Google Drive relies on Apple's Files provider and may show a folder-contents error if that provider is unavailable or not responding.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Before sharing, review notes, vendor contacts, receipts, invoices, photos, and project records for information you do not want to pass to the buyer. The transfer package contains the home's current records and attachments.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Buyer / New Owner") {
                Button { showImporter = true } label: {
                    Label("Import Home Transfer", systemImage: "square.and.arrow.down")
                }
                if !isEmpty {
                    Label("Import is locked because this app already contains home data.", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("This safeguard prevents two homes from being accidentally merged. A transfer is intended for a fresh installation of Home Maintainer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let p = preview {
                Section("Transfer Preview") {
                    LabeledContent("Home", value: p.homeName)
                    if !p.address.isEmpty { LabeledContent("Address", value: p.address) }
                    LabeledContent("Created", value: p.exportedAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Package", value: p.packageType)
                    Label("Integrity check passed", systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                    let warnings = pendingArchive.map { HomeTransferService.validationWarnings(for: $0) } ?? []
                    if !warnings.isEmpty {
                        ForEach(warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Rooms & Areas", value: "\(p.rooms)")
                    LabeledContent("Home Assets", value: "\(p.assets)")
                    LabeledContent("Projects", value: "\(p.projects)")
                    LabeledContent("Tasks", value: "\(p.tasks)")
                    LabeledContent("History Events", value: "\(p.history)")
                    LabeledContent("Files", value: "\(p.attachments)")
                    Button("Import This Home") { showImportConfirmation = true }
                        .disabled(!isEmpty || pendingArchive == nil)
                }
            }

            Section("How the handoff works") {
                Text("1. The current owner creates a transfer package and shares the JSON file securely.\n2. The new owner installs Home Maintainer on their iPhone.\n3. On a fresh app, they open Settings → Home Transfer → Import Home Transfer.\n4. Home Maintainer previews the package before importing.\n5. The home's connected record becomes theirs to maintain going forward.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Home Transfer")
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(items: [item.url]) {
                ExportShareFile.remove(item.url)
                shareItem = nil
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    let archive = try HomeTransferService.decode(Data(contentsOf: url))
                    pendingArchive = archive
                    preview = HomeTransferService.preview(archive)
                } catch { message = error.localizedDescription }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .confirmationDialog("Import this home?", isPresented: $showImportConfirmation, titleVisibility: .visible) {
            Button("Import Home", role: .destructive) { importPending() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will create the complete transferred home record in this fresh installation. The import cannot be merged with another home later.")
        }
        .alert(importSucceeded ? "Home Imported" : (exportSucceeded ? "Transfer Saved" : "Home Transfer"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil; exportSucceeded = false } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var transferFilename: String {
        let base = homes.first?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = (base?.isEmpty == false ? base! : "Home").replacingOccurrences(of: "/", with: "-")
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        return "HomeMaintainer-Transfer-\(clean)-\(stamp).json"
    }

    private func createTransfer() {
        do {
            let data = try HomeTransferService.encodedArchive(context: modelContext)
            let url = try ExportShareFile.write(data: data, filename: transferFilename)
            shareItem = ExportShareItem(url: url)
        } catch {
            exportSucceeded = false
            message = error.localizedDescription
        }
    }

    private func importPending() {
        guard let pendingArchive else { return }
        do {
            try HomeTransferService.importIntoEmptyStore(pendingArchive, context: modelContext)
            self.pendingArchive = nil
            self.preview = nil
            importSucceeded = true
            message = "The home transfer was imported successfully. Rooms, assets, projects, tasks, history, warranties, vendors, and files were reconnected using stable transfer IDs."
        } catch {
            importSucceeded = false
            message = error.localizedDescription
        }
    }
}
