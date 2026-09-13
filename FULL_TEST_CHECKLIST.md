# My Home Keeper v0.46 Test Checklist

## Build/signing
- [ ] iCloud capability enabled for `org.scriptingforschools.HomeMaintainer`
- [ ] CloudKit enabled
- [ ] Container `iCloud.org.scriptingforschools.HomeMaintainer` assigned
- [ ] App Store provisioning profile regenerated after capability change
- [ ] Codemagic fetches the updated provisioning profile
- [ ] TestFlight build shows 0.46 (460)

## Existing data safety
- [ ] Upgrade the populated iPhone without deleting the app
- [ ] Existing rooms and home records remain present
- [ ] Existing photos/documents remain present
- [ ] Existing household record remains present

## iCloud foundation
- [ ] Settings → iCloud Sync shows iCloud Account = Available
- [ ] Upload This Home to iCloud succeeds on the populated iPhone
- [ ] CloudKit household shows the expected household/home name
- [ ] Check iCloud for My Household succeeds on another device using the same iCloud account
- [ ] Last Uploaded date is sensible

## Cross-device import
- [ ] Download into an actually empty home-data store succeeds
- [ ] Replace Local Home from iCloud requires destructive confirmation
- [ ] Replace operation restores rooms/systems/tasks/vendors/projects/history
- [ ] Attachments represented in the Home Transfer archive restore correctly

## Account/household
- [ ] Sign in with Apple still works
- [ ] Sign out does not erase home data
- [ ] Household creation still adopts the existing home instead of duplicating it
- [ ] Household screen describes the CloudKit pivot

## Regression
- [ ] Home tab works
- [ ] Tasks tab works
- [ ] My Home works
- [ ] Projects works
- [ ] iPad remains full screen and adaptive
- [ ] camera/photo flows still work
- [ ] Contacts integration still works

## Expected limitation
v0.46 is private iCloud storage/same-account transfer. Family members with a different Apple ID are not shared yet. v0.47 will add `CKShare` household sharing.
