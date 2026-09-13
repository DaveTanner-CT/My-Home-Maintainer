import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Project.title) private var projects: [Project]
    @State private var showNewProject = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                wideProjects
            } else {
                compactProjects
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewProject = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Project")
            }
        }
        .sheet(isPresented: $showNewProject) { NavigationStack { ProjectFormView() } }
    }

    private var compactProjects: some View {
        List {
            projectSections { stageProjects in
                ForEach(stageProjects) { project in
                    NavigationLink { ProjectDetailView(project: project) } label: {
                        ProjectCardRow(project: project)
                    }
                }
            }
        }
    }

    private var wideProjects: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "hammer",
                        description: Text("Add a project to track planning, purchases, tasks, and completion history.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                ForEach(ProjectStage.allCases) { stage in
                    let stageProjects = projects.filter { $0.stage == stage }
                    if !stageProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(stage.rawValue.uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.8)

                            LazyVGrid(columns: AdaptiveLayout.cardColumns(minimum: 300), spacing: 14) {
                                ForEach(stageProjects) { project in
                                    NavigationLink { ProjectDetailView(project: project) } label: {
                                        ProjectCardRow(project: project)
                                            .padding(14)
                                            .background(.background)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .adaptivePageWidth()
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func projectSections<Content: View>(@ViewBuilder content: ([Project]) -> Content) -> some View {
        ForEach(ProjectStage.allCases) { stage in
            let stageProjects = projects.filter { $0.stage == stage }
            if !stageProjects.isEmpty {
                Section(stage.rawValue) {
                    content(stageProjects)
                }
            }
        }
    }
}

private struct ProjectCardRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary)
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: "hammer").foregroundStyle(.secondary))
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title).font(.headline)
                Text([project.stageRaw, project.locationName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let budget = project.budget {
                    Text("Budget \(budget.formatted(AppFormatting.currency))").font(.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
