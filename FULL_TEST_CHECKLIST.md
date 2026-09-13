# v0.48 CKShare Family Sharing Test Checklist

- [ ] Build reports version 0.48 (480).
- [ ] Existing owner's local SwiftData home opens normally.
- [ ] Owner iCloud status says Available.
- [ ] Owner uploads household to iCloud successfully.
- [ ] Owner Household Sharing -> Share Household opens Apple's native sharing UI.
- [ ] Owner sends invitation to a different Apple/iCloud account.
- [ ] Recipient installs v0.48 and is signed into their own iCloud account.
- [ ] Recipient taps the invitation and My Home Keeper opens.
- [ ] iCloud Sync shows that a CloudKit invitation was accepted (or no acceptance error).
- [ ] Recipient taps Check for Shared Household and sees the owner's household/home name.
- [ ] Recipient downloads to an empty device successfully.
- [ ] Rooms, systems, tasks, vendors, projects and representative attachments appear.
- [ ] Recipient makes one harmless test edit.
- [ ] Recipient taps Upload My Changes to Shared Household.
- [ ] Owner checks/reloads the iCloud household and sees the recipient's test edit.
- [ ] Private same-Apple-ID iPhone/iPad flow still works.
- [ ] No Supabase setup/status UI remains in active screens.
