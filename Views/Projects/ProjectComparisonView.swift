import SwiftUI
import SwiftData
import UIKit

struct ProjectComparisonView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [ProjectItem]
    @State private var selectedGroup = "All Decisions"
    @State private var showAddOption = false
    @State private var addToGroup = ""
    @State private var addToCategory = "Inspiration"

    private var projectItems: [ProjectItem] {
        allItems.filter { $0.project?.persistentModelID == project.persistentModelID && !$0.isIdeaOnly && $0.status != .rejected }
    }
    private var decisionGroups: [String] { Array(Set(projectItems.map(\.comparisonGroupName))).sorted() }
    private var visibleGroups: [String] { selectedGroup == "All Decisions" ? decisionGroups : decisionGroups.filter { $0 == selectedGroup } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare one decision at a time").font(.headline)
                    Text("Give competing products the same ‘What are you choosing?’ name—for example Kitchen Faucet. Those options stay together from comparison through purchase.").font(.footnote).foregroundStyle(.secondary)
                    Picker("Decision", selection: $selectedGroup) {
                        Text("All Decisions").tag("All Decisions")
                        ForEach(decisionGroups, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }.padding(.horizontal)

                if visibleGroups.isEmpty {
                    ContentUnavailableView("Nothing to compare", systemImage: "rectangle.split.3x1", description: Text("Add shopping options and give related choices the same buying-decision name."))
                    Button { addToGroup = ""; addToCategory = "Inspiration"; showAddOption = true } label: { Label("Add First Option", systemImage: "plus") }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                } else {
                    ForEach(visibleGroups, id: \.self) { group in
                        let options = projectItems.filter { $0.comparisonGroupName == group }
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) { Text(group).font(.title3.bold()); Text("\(options.count) option\(options.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Button { addToGroup = group; addToCategory = categoryForGroup(group); showAddOption = true } label: { Label("Add Option", systemImage: "plus") }.buttonStyle(.bordered)
                            }.padding(.horizontal)

                            if options.count == 1 { Text("Add at least one more option for a side-by-side comparison.").font(.footnote).foregroundStyle(.secondary).padding(.horizontal) }

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(alignment: .top, spacing: 14) {
                                    ForEach(options) { item in
                                        VStack(spacing: 8) {
                                            NavigationLink { ProjectItemDetailView(project: project, item: item) } label: { comparisonCard(item) }.buttonStyle(.plain)
                                            if item.status == .considering || item.status == .favorite {
                                                HStack {
                                                    Button { item.status = .favorite; save() } label: { Label("Favorite", systemImage: item.status == .favorite ? "star.fill" : "star") }.buttonStyle(.bordered)
                                                    NavigationLink { ProjectPurchaseView(project: project, item: item) } label: { Label("Choose", systemImage: "cart.badge.plus") }.buttonStyle(.borderedProminent)
                                                }.font(.caption)
                                            } else if item.status == .purchased { Label("Purchased", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green) }
                                            else if item.status == .installed { Label("Installed / saved", systemImage: "house.circle.fill").font(.caption).foregroundStyle(.green) }
                                        }.frame(width: 260)
                                    }
                                }.padding(.horizontal)
                            }
                        }
                    }
                }
            }.padding(.vertical)
        }
        .navigationTitle("Compare Options")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { addToGroup = selectedGroup == "All Decisions" ? "" : selectedGroup; addToCategory = selectedGroup == "All Decisions" ? "Inspiration" : categoryForGroup(selectedGroup); showAddOption = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAddOption) { NavigationStack { ProjectItemFormView(project: project, initialComparisonGroup: addToGroup, initialCategory: addToCategory) } }
    }

    @ViewBuilder
    private func comparisonCard(_ item: ProjectItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 230, height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(.quaternary).frame(width: 230, height: 150).overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
            }
            HStack { Text(item.title).font(.headline); Spacer(); if item.status == .favorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }; if item.status == .purchased || item.status == .installed { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }
            Text(item.category).font(.caption).foregroundStyle(.secondary)
            if !item.manufacturer.isEmpty { LabeledContent("Brand", value: item.manufacturer) }
            if !item.model.isEmpty { LabeledContent("Model", value: item.model) }
            if !item.finishColor.isEmpty { LabeledContent("Color", value: item.finishColor) }
            if !item.dimensions.isEmpty { LabeledContent("Size", value: item.dimensions) }
            if !item.store.isEmpty { LabeledContent("Store", value: item.store) }
            if let price = item.unitCost { LabeledContent("Price", value: price.formatted(AppFormatting.currency)) }
            if !item.notes.isEmpty { Text(item.notes).font(.caption).foregroundStyle(.secondary).lineLimit(4) }
        }.padding(14).frame(width: 260, alignment: .topLeading).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary))
    }


    private func categoryForGroup(_ group: String) -> String {
        projectItems.first { $0.comparisonGroupName.caseInsensitiveCompare(group) == .orderedSame }?.category ?? "Inspiration"
    }
    private func save() { try? modelContext.save() }
}
