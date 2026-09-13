# My Home Keeper v0.46.1

## CloudKit Foundation

v0.46.1 pivots My Home Keeper away from a developer-managed Supabase database and into Apple CloudKit.

### What stays the same
- SwiftUI interface and adaptive iPhone/iPad layouts
- SwiftData local/offline storage
- existing rooms, systems, devices, fixtures, furniture, paint, detectors, consumables, vendors, tasks, projects, history, and attachments
- Sign in with Apple account/profile support
- household model

### What changes
- Supabase is no longer used by this source tree.
- Cloud household backup data is stored in the signed-in iCloud user's **private CloudKit database**.
- A custom private record zone named `MyHomeKeeperHousehold` is used.
- The app uploads the Home Transfer archive as a `CKAsset`.
- Another iPhone/iPad using the same iCloud account can discover the latest private household backup and import it.
- The app can explicitly replace local home data with the latest iCloud copy after confirmation.

### Privacy direction
The application backend no longer holds household records in a developer-owned database. The private CloudKit database belongs to the user's iCloud account. Family sharing will be added with `CKShare`, allowing the owner to share selected CloudKit records/zone with invited participants.

### v0.47 next
- Create a `CKShare` for the household record zone
- Native Apple share sheet/invitation
- Family member accepts using their own Apple ID/iCloud account
- Read/write versus read-only participation
- shared database discovery

## Apple Developer setup required
Before Codemagic can sign v0.46.1:
1. Open Apple Developer → Certificates, Identifiers & Profiles → Identifiers.
2. Open `org.scriptingforschools.HomeMaintainer`.
3. Enable **iCloud**.
4. Enable **CloudKit** under the iCloud capability.
5. Create or select the CloudKit container `iCloud.org.scriptingforschools.HomeMaintainer`.
6. Save the App ID.
7. Regenerate the App Store provisioning profile for My Home Keeper.
8. Fetch/update that provisioning profile in Codemagic.

Version: **0.46**  
Build: **460**


## v0.46.1 build cleanup

This maintenance release hardens the CloudKit pivot for repositories that still contain legacy Supabase source files. `project.yml` explicitly excludes the obsolete Supabase sync files from the XcodeGen target, so stale files left in GitHub cannot be compiled accidentally.

Excluded legacy files:
- `Services/CloudSyncService.swift`
- `Services/CloudHouseholdService.swift`
- `Services/SupabaseConfiguration.swift`
- `Views/Settings/CloudSyncView.swift`

CloudKit remains the only active cloud-sync implementation.
