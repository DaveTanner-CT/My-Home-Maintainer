import SwiftUI
import SwiftData
import UIKit

struct ProjectComparisonView: View {
    let project: Project
    @Query private var allItems: [ProjectItem]
    @State private var selectedCategory = "All"

    private var projectItems: [ProjectItem] {
        allItems.filter {
            $0.project?.persistentModelID == project.persistentModelID &&
            !$0.isIdeaOnly &&
            $0.status != .rejected
        }
    }

    private var categories: [String] {
        Array(Set(projectItems.map(\.category))).sorted()
    }

    private var displayedItems: [ProjectItem] {
        projectItems.filter { selectedCategory == "All" || $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag("All")
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .padding()

            if displayedItems.isEmpty {
                ContentUnavailableView("Nothing to compare", systemImage: "rectangle.split.3x1", description: Text("Add two or more product options to the project."))
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(displayedItems) { item in
                            NavigationLink {
                                ProjectItemDetailView(project: project, item: item)
                            } label: {
                                comparisonCard(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Compare Options")
    }

    @ViewBuilder
    private func comparisonCard(_ item: ProjectItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 230, height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 230, height: 150)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
            }

            HStack {
                Text(item.title).font(.headline)
                Spacer()
                if item.status == .favorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            }
            Text(item.category).font(.caption).foregroundStyle(.secondary)

            if !item.finishColor.isEmpty { LabeledContent("Color", value: item.finishColor) }
            if !item.dimensions.isEmpty { LabeledContent("Size", value: item.dimensions) }
            if !item.store.isEmpty { LabeledContent("Store", value: item.store) }
            if let price = item.unitCost { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
            if !item.notes.isEmpty {
                Text(item.notes).font(.caption).foregroundStyle(.secondary).lineLimit(4)
            }
        }
        .padding(14)
        .frame(width: 260, alignment: .topLeading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }
}
