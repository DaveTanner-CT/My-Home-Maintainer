import Foundation

enum SupabaseConfiguration {
    // These values are safe to ship in the iOS client. The Supabase publishable
    // key is intentionally public and access remains protected by Auth + RLS.
    private static let bundledProjectURL = "https://euhnbmtmcaclibomychc.supabase.co"
    private static let bundledPublishableKey = "sb_publishable_7e_hy5Qsovmn-qjX5HbOCw_N2QEbnoP"

    private static let projectURLKey = "SupabaseProjectURL"
    private static let publishableKeyKey = "SupabasePublishableKey"

    static var projectURL: URL? {
        let plistValue = (Bundle.main.object(forInfoDictionaryKey: projectURLKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let plistValue,
           !plistValue.isEmpty,
           !plistValue.contains("YOUR_SUPABASE"),
           let url = URL(string: plistValue) {
            return url
        }

        return URL(string: bundledProjectURL)
    }

    static var publishableKey: String? {
        let plistValue = (Bundle.main.object(forInfoDictionaryKey: publishableKeyKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let plistValue,
           !plistValue.isEmpty,
           !plistValue.contains("YOUR_SUPABASE") {
            return plistValue
        }

        return bundledPublishableKey
    }

    static var isConfigured: Bool {
        projectURL != nil && publishableKey != nil
    }

    static var configurationSummary: String {
        isConfigured ? "Configured" : "Setup Required"
    }
}
