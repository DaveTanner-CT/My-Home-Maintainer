import SwiftUI

struct HomeCareView: View {
    var body: some View {
        List {
            Section {
                NavigationLink { RecommendedMaintenanceView() } label: {
                    careRow(
                        title: "Recommended Maintenance",
                        subtitle: "Suggestions based on the systems, devices, fixtures, and areas recorded in your home.",
                        icon: "checklist.checked"
                    )
                }
                NavigationLink { SeasonalMaintenanceView() } label: {
                    careRow(
                        title: "Seasonal Planning",
                        subtitle: "See what is coming up this season and add useful recurring tasks.",
                        icon: "calendar.badge.clock"
                    )
                }
            } header: {
                Text("Maintenance")
            }

            Section {
                NavigationLink { WarrantyCenterView() } label: {
                    careRow(
                        title: "Warranty Center",
                        subtitle: "Review warranties across systems, fixtures, and devices without hunting through each record.",
                        icon: "shield"
                    )
                }
                NavigationLink { HomeOutlookView() } label: {
                    careRow(
                        title: "Home Outlook",
                        subtitle: "Look ahead at likely replacement windows and turn future needs into projects.",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            } header: {
                Text("Plan Ahead")
            }

            Section {
                NavigationLink { DetectorsListView() } label: {
                    careRow(
                        title: "Smoke & CO Detectors",
                        subtitle: "Track testing, batteries, and replacement dates.",
                        icon: "sensor.tag.radiowaves.forward"
                    )
                }
                NavigationLink { ConsumablesListView() } label: {
                    careRow(
                        title: "Filters & Consumables",
                        subtitle: "Keep replacement items and dates connected to the home.",
                        icon: "shippingbox"
                    )
                }
            } header: {
                Text("Safety & Supplies")
            }
        }
        .navigationTitle("Home Care")
    }

    @ViewBuilder
    private func careRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
