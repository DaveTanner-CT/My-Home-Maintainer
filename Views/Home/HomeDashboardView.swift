import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Query private var homes: [Home]
    @Query(sort: \MaintenanceTask.dueDate) private var tasks: [MaintenanceTask]
    @State private var showSearch = false
    @State private var showAddTask = false
    @State private var completionTask: MaintenanceTask?

    private var activeTasks: [MaintenanceTask] { tasks.filter { !$0.isCompleted } }
    private var overdue: [MaintenanceTask] { activeTasks.filter { TaskEngine.status(for: $0) == .overdue } }
    private var current: [MaintenanceTask] { activeTasks.filter { TaskEngine.status(for: $0) == .current } }
    private var upcoming: [MaintenanceTask] { activeTasks.filter { TaskEngine.status(for: $0) == .upcoming } }
    private var attention: [MaintenanceTask] { overdue + current }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(homes.first?.name ?? "My Home")
                        .font(.largeTitle.bold())
                    Text("What needs your attention?")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showSearch = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search your home...")
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.quaternary.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    SummaryCard(title: "Overdue", count: overdue.count, tint: .red)
                    SummaryCard(title: "Current", count: current.count, tint: .orange)
                    SummaryCard(title: "Upcoming", count: upcoming.count, tint: .blue)
                }

                sectionTitle("Needs Attention")

                if attention.isEmpty {
                    EmptyCard(icon: "checkmark.circle", title: "You're caught up", subtitle: "No overdue or current maintenance tasks.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(attention.prefix(8)) { task in
                            NavigationLink {
                                TaskDetailView(task: task)
                            } label: {
                                TaskRowView(task: task) { completionTask = task }
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                }

                HStack {
                    sectionTitle("Coming Soon")
                    Spacer()
                    NavigationLink("View All Tasks") { TasksHubView(initialSection: .all) }
                        .font(.caption.weight(.semibold))
                }
                VStack(spacing: 0) {
                    ForEach(upcoming.prefix(4)) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            TaskRowView(task: task) { completionTask = task }
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal, 14)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

                sectionTitle("Quick Access")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    QuickLink(title: "Home Systems", icon: "wrench.and.screwdriver", destination: AnyView(SystemsListView()))
                    QuickLink(title: "Rooms", icon: "door.left.hand.open", destination: AnyView(RoomsListView()))
                    QuickLink(title: "Devices & Equipment", icon: "refrigerator", destination: AnyView(AppliancesListView()))
                    QuickLink(title: "Paint & Finishes", icon: "paintbrush", destination: AnyView(PaintListView()))
                    QuickLink(title: "Projects", icon: "hammer", destination: AnyView(ProjectsView()))
                    QuickLink(title: "Vendors", icon: "person.crop.circle.badge.checkmark", destination: AnyView(VendorsListView()))
                    QuickLink(title: "Home Insights", icon: "chart.bar.xaxis", destination: AnyView(HomeInsightsView()))
                    QuickLink(title: "Warranty Center", icon: "shield", destination: AnyView(WarrantyCenterView()))
                    QuickLink(title: "Seasonal Planning", icon: "calendar.badge.clock", destination: AnyView(SeasonalMaintenanceView()))
                    QuickLink(title: "Home Outlook", icon: "chart.line.uptrend.xyaxis", destination: AnyView(HomeOutlookView()))
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink { AppSettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
                Button { showAddTask = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Task")
            }
        }
        .sheet(isPresented: $showSearch) { NavigationStack { GlobalSearchView() } }
        .sheet(isPresented: $showAddTask) { NavigationStack { TaskFormView() } }
        .sheet(item: $completionTask) { task in
            NavigationStack { CompleteTaskView(task: task) }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }
}

private struct SummaryCard: View {
    let title: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct QuickLink: View {
    let title: String
    let icon: String
    let destination: AnyView

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 28)
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(14)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct EmptyCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
