# My Home Keeper v0.48 - CKShare Recipient + Shared Household Sync

Version 0.48 / build 480 extends the v0.47 owner-side CKShare work into an end-to-end family sharing flow.

## What changed
- Accepts incoming Apple CloudKit sharing invitations through the app delegate.
- Reads family households from `CKContainer.default().sharedCloudDatabase`.
- Adds **Check for Shared Household** to iCloud Sync.
- Supports downloading a shared household into an empty device.
- Supports an explicit local replacement from the latest shared household snapshot.
- For read/write shares, supports manually uploading the recipient's changes back to the shared CloudKit record.
- Keeps the owner's private iCloud backup/same-account device flow intact.
- SwiftData stays local-only (`cloudKitDatabase: .none`); CKRecord/CKAsset remain the cloud transport.

## First end-to-end family test
1. Owner uploads household to iCloud.
2. Owner opens Household Sharing and taps **Share Household**.
3. Owner sends Apple CKShare invitation to spouse.
4. Spouse installs the same TestFlight build and is signed into their own iCloud account.
5. Spouse taps the Apple invitation and opens My Home Keeper.
6. In My Home Keeper, spouse opens **iCloud Sync** and taps **Check for Shared Household**.
7. Spouse downloads the shared household.
8. Make one small test edit on spouse's device and use **Upload My Changes to Shared Household**.
9. Owner checks private iCloud household and replaces/downloads the latest copy to confirm the edit arrived.

## Data ownership
The root `HouseholdSnapshot` record remains in the owner's private CloudKit database. Apple exposes it to invited participants through their shared CloudKit database. The app developer does not store the household in a developer-owned Supabase database.
