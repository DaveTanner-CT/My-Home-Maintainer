import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Query(sort: \Project.title) private var projects: [Project]
    @State private var showNewProject = false

    var body: some View {
        List {
            ForEach(ProjectStage.allCases) { stage in
                let stageProjects = projects.filter { $0.stage == stage }
                if !stageProjects.isEmpty {
                    Section(stage.rawValue) {
                        ForEach(stageProjects) { project in
                            NavigationLink { ProjectDetailView(project: project) } label: {
                                ProjectCardRow(project: project)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewProject = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showNewProject) { NavigationStack { ProjectFormView() } }
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
                Text([project.stageRaw, project.locationName].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                if let budget = project.budget { Text("Budget \(budget.formatted(AppFormatting.currency))").font(.caption) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
