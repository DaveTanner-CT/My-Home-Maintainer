import Foundation

enum CloudKitSyncCheckpointStore {
    enum Scope: String {
        case privateHousehold = "private"
        case sharedHousehold = "shared"
    }

    private static let prefix = "HomeKeeperCloudKitCheckpoint"

    static func lastAppliedDate(
        householdID: String,
        scope: Scope
    ) -> Date? {
        UserDefaults.standard.object(
            forKey: key(householdID: householdID, scope: scope)
        ) as? Date
    }

    static func markApplied(
        _ date: Date,
        householdID: String,
        scope: Scope
    ) {
        UserDefaults.standard.set(
            date,
            forKey: key(householdID: householdID, scope: scope)
        )
    }

    static func isRemoteNewer(
        remoteDate: Date,
        householdID: String,
        scope: Scope
    ) -> Bool {
        guard let localDate = lastAppliedDate(
            householdID: householdID,
            scope: scope
        ) else {
            return true
        }

        // CloudKit timestamps can differ by a fraction of a second from the
        // local completion time. A small tolerance avoids false "newer" flags.
        return remoteDate.timeIntervalSince(localDate) > 1.0
    }

    private static func key(
        householdID: String,
        scope: Scope
    ) -> String {
        "\(prefix).\(scope.rawValue).\(householdID)"
    }
}
