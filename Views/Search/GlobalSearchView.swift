import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tasks: [MaintenanceTask]
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var rooms: [Room]
    @Query private var vendors: [Vendor]
    @Query private var paints: [PaintFinish]
    @Query private var detectors: [Detector]
    @Query private var consumables: [Consumable]
    @Query private var projects: [Project]
    @Query private var projectItems: [ProjectItem]
    @Query private var records: [MaintenanceRecord]
    @Query private var attachments: [HomeAttachment]

    @State private var query = ""

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Search your home", systemImage: "magnifyingglass", description: Text("Find tasks, systems, appliances, rooms, paint colors, vendors, projects, and maintenance history."))
            } else {
                searchSections
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search your home")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
        }
    }

    @ViewBuilder
    private var searchSections: some View {
        let q = query.lowercased()

        let matchingTasks = tasks.filter { contains(q, [$0.title, $0.taskDescription, $0.notes, $0.categoryRaw, $0.vendor?.businessName ?? ""]) }
        if !matchingTasks.isEmpty {
            Section("Tasks") {
                ForEach(matchingTasks) { task in
                    NavigationLink { TaskDetailView(task: task) } label: {
                        SearchResultRow(icon: "checklist", title: task.title, subtitle: task.categoryRaw)
                    }
                }
            }
        }

        let matchingSystems = systems.filter { contains(q, [$0.name, $0.type, $0.manufacturer, $0.model, $0.serialNumber, $0.location, $0.notes]) }
        if !matchingSystems.isEmpty {
            Section("Systems") {
                ForEach(matchingSystems) { item in
                    NavigationLink { SystemDetailView(system: item) } label: {
                        SearchResultRow(icon: "wrench.and.screwdriver", title: item.name, subtitle: item.type)
                    }
                }
            }
        }

        let matchingAppliances = appliances.filter { contains(q, [$0.name, $0.category, $0.manufacturer, $0.model, $0.serialNumber, $0.purchasedFrom, $0.notes]) }
        if !matchingAppliances.isEmpty {
            Section("Appliances") {
                ForEach(matchingAppliances) { item in
                    NavigationLink { ApplianceDetailView(appliance: item) } label: {
                        SearchResultRow(icon: "refrigerator", title: item.name, subtitle: item.manufacturer)
                    }
                }
            }
        }

        let matchingRooms = rooms.filter { contains(q, [$0.name, $0.notes]) }
        if !matchingRooms.isEmpty {
            Section("Rooms") {
                ForEach(matchingRooms) { room in
                    NavigationLink { RoomDetailView(room: room) } label: {
                        SearchResultRow(icon: "door.left.hand.open", title: room.name, subtitle: "Room / Area")
                    }
                }
            }
        }

        let matchingPaints = paints.filter { contains(q, [$0.roomName, $0.surface, $0.brand, $0.colorName, $0.colorCode, $0.sheen, $0.store, $0.notes]) }
        if !matchingPaints.isEmpty {
            Section("Paint & Finishes") {
                ForEach(matchingPaints) { paint in
                    NavigationLink { PaintDetailView(paint: paint) } label: {
                        SearchResultRow(icon: "paintbrush", title: [paint.colorName, paint.colorCode].filter { !$0.isEmpty }.joined(separator: " "), subtitle: "\(paint.roomName) · \(paint.surface)")
                    }
                }
            }
        }


        let matchingDetectors = detectors.filter { contains(q, [$0.location, $0.type, $0.manufacturer, $0.model, $0.batteryType, $0.notes]) }
        if !matchingDetectors.isEmpty {
            Section("Smoke & CO Detectors") {
                ForEach(matchingDetectors) { detector in
                    NavigationLink { DetectorDetailView(detector: detector) } label: {
                        SearchResultRow(icon: "sensor.tag.radiowaves.forward", title: detector.location, subtitle: detector.type)
                    }
                }
            }
        }

        let matchingConsumables = consumables.filter { contains(q, [$0.name, $0.type, $0.size, $0.manufacturer, $0.modelPartNumber, $0.notes]) }
        if !matchingConsumables.isEmpty {
            Section("Filters & Consumables") {
                ForEach(matchingConsumables) { item in
                    NavigationLink { ConsumableDetailView(item: item) } label: {
                        SearchResultRow(icon: "shippingbox", title: item.name, subtitle: [item.size, item.modelPartNumber].filter { !$0.isEmpty }.joined(separator: " · "))
                    }
                }
            }
        }

        let matchingVendors = vendors.filter { contains(q, [$0.businessName, $0.contactName, $0.category, $0.phone, $0.email, $0.notes]) }
        if !matchingVendors.isEmpty {
            Section("Vendors") {
                ForEach(matchingVendors) { vendor in
                    NavigationLink { VendorDetailView(vendor: vendor) } label: { VendorRow(vendor: vendor) }
                }
            }
        }

        let matchingProjects = projects.filter { contains(q, [$0.title, $0.projectDescription, $0.stageRaw, $0.roomName, $0.notes]) }
        if !matchingProjects.isEmpty {
            Section("Projects") {
                ForEach(matchingProjects) { project in
                    NavigationLink { ProjectDetailView(project: project) } label: {
                        SearchResultRow(icon: "hammer", title: project.title, subtitle: project.stageRaw)
                    }
                }
            }
        }

        let matchingProjectItems = projectItems.filter { contains(q, [$0.title, $0.category, $0.manufacturer, $0.model, $0.sku, $0.finishColor, $0.store, $0.notes]) }
        if !matchingProjectItems.isEmpty {
            Section("Project Items") {
                ForEach(matchingProjectItems) { item in
                    if let project = item.project {
                        NavigationLink { ProjectItemDetailView(project: project, item: item) } label: {
                            SearchResultRow(icon: "cart", title: item.title, subtitle: [project.title, item.store].filter { !$0.isEmpty }.joined(separator: " · "))
                        }
                    }
                }
            }
        }


        let matchingAttachments = attachments.filter { contains(q, [$0.name, $0.caption, $0.category, $0.fileName]) }
        if !matchingAttachments.isEmpty {
            Section("Photos & Documents") {
                ForEach(matchingAttachments) { attachment in
                    NavigationLink { AttachmentDetailView(attachment: attachment) } label: {
                        SearchResultRow(icon: attachment.isImage ? "photo" : "doc", title: attachment.name, subtitle: attachment.caption.isEmpty ? attachment.fileName : attachment.caption)
                    }
                }
            }
        }

        let matchingRecords = records.filter { contains(q, [$0.title, $0.vendorName, $0.taskTitle, $0.relatedItemName, $0.notes]) }
        if !matchingRecords.isEmpty {
            Section("Maintenance History") {
                ForEach(matchingRecords) { record in
                    NavigationLink { MaintenanceRecordDetailView(record: record) } label: {
                        SearchResultRow(icon: "clock.arrow.circlepath", title: record.title, subtitle: record.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
        }
    }

    private func contains(_ query: String, _ fields: [String]) -> Bool {
        fields.joined(separator: " ").lowercased().contains(query)
    }
}

private struct SearchResultRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(title.isEmpty ? "Untitled" : title).font(.headline)
                if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}
