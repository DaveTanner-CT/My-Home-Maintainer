# My Home Keeper v0.49 Test Checklist

## Build / launch
- [ ] TestFlight build 0.49 (490) installs over the existing app without deleting local data.
- [ ] Existing rooms, systems, projects, tasks, vendors, photos and household data remain present.
- [ ] App launches normally on iPhone and iPad.

## Owner iCloud flow
- [ ] iCloud Sync opens and shows iCloud Account = Available.
- [ ] Cloud status checks automatically when the screen opens.
- [ ] Upload This Home to iCloud succeeds.
- [ ] Last synced timestamp appears after upload.
- [ ] A newer cloud snapshot from another device is highlighted rather than automatically applied.
- [ ] Update This Device from iCloud requires confirmation.

## Family CKShare flow
- [ ] Existing CKShare invitation opens correctly for the invited family member.
- [ ] Check for Shared Household finds the shared household.
- [ ] Download/replace shared household succeeds.
- [ ] Invited member can upload changes to the shared household.
- [ ] Owner sees a newer private iCloud version after the invited member uploads changes.
- [ ] Owner can explicitly update the device from that newer cloud copy.

## Safety
- [ ] No local home is overwritten automatically.
- [ ] Shared upload action is not shown as an owner-only private upload action.
- [ ] Pull-to-refresh updates cloud timestamps/status.
