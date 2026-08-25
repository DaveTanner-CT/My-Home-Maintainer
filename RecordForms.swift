import SwiftUI

struct WarrantyStatusView: View {
    let expiration: Date?

    var body: some View {
        if let expiration {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: expiration)).day ?? 0
            HStack {
                Image(systemName: days < 0 ? "exclamationmark.triangle.fill" : (days <= 90 ? "clock.badge.exclamationmark" : "checkmark.shield.fill"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(days < 0 ? "Warranty expired" : (days <= 90 ? "Warranty ending soon" : "Warranty active"))
                        .font(.subheadline.weight(.semibold))
                    Text(expiration.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .foregroundStyle(days < 0 ? .red : (days <= 90 ? .orange : .green))
        }
    }
}

struct ServiceLifeStatusView: View {
    let installed: Date?
    let expectedYears: Int?

    var body: some View {
        if let installed, let expectedYears, expectedYears > 0 {
            let ageMonths = max(0, Calendar.current.dateComponents([.month], from: installed, to: .now).month ?? 0)
            let ageYears = Double(ageMonths) / 12.0
            let ratio = ageYears / Double(expectedYears)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Estimated service life")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.1f / %d yr", ageYears, expectedYears))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(ratio, 1.0))
                if ratio >= 1 {
                    Label("At or beyond the estimated service-life range", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if ratio >= 0.8 {
                    Label("Approaching the estimated service-life range", systemImage: "clock.badge.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
