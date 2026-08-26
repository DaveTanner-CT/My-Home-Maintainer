import SwiftUI
import SwiftData

struct HomeSetupView: View {
    @Query private var homes: [Home]
    @Query private var rooms: [Room]
    @Query private var systems: [HomeSystem]
    @Query private var appliances: [Appliance]
    @Query private var fixtures: [Fixture]
    @Query private var paints: [PaintFinish]
    @Query private var vendors: [Vendor]
    @Query private var detectors: [Detector]
    @Query private var tasks: [MaintenanceTask]

    private var profileComplete: Bool {
        guard let home = homes.first else { return false }
        return !home.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !home.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var setupSteps: [SetupStep] {
        [
            SetupStep(title: "Home profile", subtitle: "Name and address identify this home and make exports easier to recognize.", icon: "house", complete: profileComplete, destination: .profile),
            SetupStep(title: "Rooms & areas", subtitle: "Create the places that projects, fixtures, equipment, paint, and tasks can connect to.", icon: "door.left.hand.open", complete: !rooms.isEmpty, destination: .rooms),
            SetupStep(title: "Home systems", subtitle: "Record major built-in systems such as HVAC, water, electrical, plumbing, and generators.", icon: "wrench.and.screwdriver", complete: !systems.isEmpty, destination: .systems),
            SetupStep(title: "Devices & equipment", subtitle: "Record appliances, electronics, tools, and outdoor equipment you want to maintain or track.", icon: "refrigerator", complete: !appliances.isEmpty, destination: .appliances),
            SetupStep(title: "Fixtures", subtitle: "Record installed items such as faucets, lights, fans, and hardware when their details matter.", icon: "lightbulb", complete: !fixtures.isEmpty, destination: .fixtures),
            SetupStep(title: "Safety", subtitle: "Record smoke and CO detectors so replacement dates can be monitored.", icon: "sensor.tag.radiowaves.forward", complete: !detectors.isEmpty, destination: .detectors)
        ]
    }

    private var completedStepCount: Int { setupSteps.filter(\.complete).count }
    private var progress: Double { setupSteps.isEmpty ? 0 : Double(completedStepCount) / Double(setupSteps.count) }

    private var unassignedSystems: Int {
        systems.filter { $0.room == nil && $0.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    private var unassignedAppliances: Int { appliances.filter { $0.room == nil }.count }
    private var unassignedFixtures: Int { fixtures.filter { $0.room == nil }.count }
    private var unassignedPaint: Int {
        paints.filter { $0.room == nil && $0.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
    private var unlinkedTasks: Int {
        tasks.filter {
            !$0.isCompleted && $0.room == nil && $0.system == nil && $0.appliance == nil && $0.fixture == nil && $0.project == nil
        }.count
    }

    private var systemsMissingIdentity: Int {
        systems.filter { $0.manufacturer.isEmpty || $0.model.isEmpty || $0.installationDate == nil }.count
    }
    private var appliancesMissingIdentity: Int {
        appliances.filter { $0.manufacturer.isEmpty || $0.model.isEmpty || $0.purchaseDate == nil }.count
    }
    private var fixturesMissingIdentity: Int {
        fixtures.filter { $0.manufacturer.isEmpty || $0.model.isEmpty || ($0.installationDate == nil && $0.purchaseDate == nil) }.count
    }
    private var detectorsMissingDates: Int {
        detectors.filter { $0.manufactureDate == nil && $0.installationDate == nil }.count
    }

    private var relationshipIssueCount: Int {
        unassignedSystems + unassignedAppliances + unassignedFixtures + unassignedPaint + unlinkedTasks
    }
    private var detailIssueCount: Int {
        systemsMissingIdentity + appliancesMissingIdentity + fixturesMissingIdentity + detectorsMissingDates
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Home setup")
                            .font(.title3.bold())
                        Spacer()
                        Text("\(completedStepCount) of \(setupSteps.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                    Text(progress == 1 ? "The core home structure is in place. Use the checks below to tighten the quality of your records." : "These are foundation steps, not a requirement to catalog every object in your house. Add only the records that will actually help you maintain, plan, or document the home.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Foundation") {
                ForEach(setupSteps) { step in
                    NavigationLink {
                        destinationView(for: step.destination)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: step.complete ? "checkmark.circle.fill" : step.icon)
                                .foregroundStyle(step.complete ? Color.green : Color.accentColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title).font(.headline)
                                Text(step.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }

            Section("Connections") {
                if relationshipIssueCount == 0 {
                    qualityRow(icon: "link.circle.fill", title: "Connected records look good", subtitle: "Current assets and open tasks have the location or relationship information needed for connected navigation.", tint: .green)
                } else {
                    if unassignedSystems > 0 {
                        NavigationLink { SystemsListView() } label: {
                            issueRow(count: unassignedSystems, title: "Home systems without a location", subtitle: "Assign a Room / Area or enter a location.")
                        }
                    }
                    if unassignedAppliances > 0 {
                        NavigationLink { AppliancesListView() } label: {
                            issueRow(count: unassignedAppliances, title: "Devices & equipment without a Room / Area", subtitle: "Connecting them improves room dashboards, maintenance, and history.")
                        }
                    }
                    if unassignedFixtures > 0 {
                        NavigationLink { FixturesListView() } label: {
                            issueRow(count: unassignedFixtures, title: "Fixtures without a Room / Area", subtitle: "Assigning a room makes project, warranty, and history navigation much stronger.")
                        }
                    }
                    if unassignedPaint > 0 {
                        NavigationLink { PaintListView() } label: {
                            issueRow(count: unassignedPaint, title: "Paint records without a location", subtitle: "Connect each finish to a Room / Area when possible.")
                        }
                    }
                    if unlinkedTasks > 0 {
                        NavigationLink { TasksHubView(initialSection: .all) } label: {
                            issueRow(count: unlinkedTasks, title: "Open tasks with no connected context", subtitle: "A task can stand alone, but linking it to a room, asset, or project makes the home record more useful.")
                        }
                    }
                }
            }

            Section("Useful Details") {
                if detailIssueCount == 0 {
                    qualityRow(icon: "checkmark.seal.fill", title: "Key asset details look good", subtitle: "Recorded systems, devices, fixtures, and detectors include the dates and identity information used by planning tools.", tint: .green)
                } else {
                    Text("These are suggestions, not errors. Add details when they are available and useful.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if systemsMissingIdentity > 0 {
                        NavigationLink { SystemsListView() } label: {
                            issueRow(count: systemsMissingIdentity, title: "Systems missing model or installation details", subtitle: "These fields improve warranty and replacement planning.")
                        }
                    }
                    if appliancesMissingIdentity > 0 {
                        NavigationLink { AppliancesListView() } label: {
                            issueRow(count: appliancesMissingIdentity, title: "Devices & equipment missing model or purchase details", subtitle: "Useful for warranty, replacement, and documentation.")
                        }
                    }
                    if fixturesMissingIdentity > 0 {
                        NavigationLink { FixturesListView() } label: {
                            issueRow(count: fixturesMissingIdentity, title: "Fixtures missing model or date details", subtitle: "Especially useful for faucets, lighting, fans, and replacement parts.")
                        }
                    }
                    if detectorsMissingDates > 0 {
                        NavigationLink { DetectorsListView() } label: {
                            issueRow(count: detectorsMissingDates, title: "Detectors missing manufacture / installation dates", subtitle: "A date is needed to estimate replacement timing.")
                        }
                    }
                }
            }

            Section("Optional Records") {
                NavigationLink { PaintListView() } label: {
                    optionalRow(title: "Paint & Finishes", count: paints.count, subtitle: "Save colors and product details you may need again.", icon: "paintbrush")
                }
                NavigationLink { VendorsListView() } label: {
                    optionalRow(title: "Vendors", count: vendors.count, subtitle: "Keep trusted contractors and service providers connected to the home record.", icon: "person.2")
                }
                NavigationLink { HomeCareView() } label: {
                    optionalRow(title: "Home Care", count: nil, subtitle: "Review recommendations, warranties, safety, and replacement planning once your inventory is in place.", icon: "heart.text.clipboard")
                }
            }
        }
        .navigationTitle("Home Setup")
    }

    @ViewBuilder
    private func destinationView(for destination: SetupDestination) -> some View {
        switch destination {
        case .profile: HomeProfileView()
        case .rooms: RoomsListView()
        case .systems: SystemsListView()
        case .appliances: AppliancesListView()
        case .fixtures: FixturesListView()
        case .detectors: DetectorsListView()
        }
    }

    @ViewBuilder
    private func issueRow(count: Int, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(count)")
                .font(.subheadline.bold())
                .frame(minWidth: 28)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func qualityRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func optionalRow(title: String, count: Int?, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.accentColor).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title).font(.headline)
                    if let count {
                        Text("\(count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let complete: Bool
    let destination: SetupDestination
}

private enum SetupDestination {
    case profile
    case rooms
    case systems
    case appliances
    case fixtures
    case detectors
}
