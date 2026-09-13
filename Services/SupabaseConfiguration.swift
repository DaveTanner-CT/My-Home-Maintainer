import Foundation

enum SupabaseConfiguration {
    private static let projectURLKey = "https://euhnbmtmcaclibomychc.supabase.co"
    private static let publishableKeyKey = "sb_publishable_7e_hy5Qsovmn-qjX5HbOCw_N2QEbnoP"

    static var projectURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: projectURLKey) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("YOUR_SUPABASE"),
              let url = URL(string: trimmed) else { return nil }
        return url
    }

    static var publishableKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: publishableKeyKey) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("YOUR_SUPABASE") else { return nil }
        return trimmed
    }

    static var isConfigured: Bool {
        projectURL != nil && publishableKey != nil
    }

    static var configurationSummary: String {
        isConfigured ? "Configured" : "Setup Required"
    }
}
