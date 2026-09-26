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


## v0.50 Security & Passwords/Codes

- [ ] Settings > Security opens without affecting existing household data.
- [ ] Set Up App Lock requires and confirms exactly four digits.
- [ ] Lock Now replaces the app UI with the app-code screen.
- [ ] Correct 4-digit code unlocks; incorrect code does not.
- [ ] Face ID / Touch ID unlock works when enabled and available.
- [ ] Backgrounding longer than the chosen delay locks the app; returning sooner does not.
- [ ] Forgot App Code uses device-owner authentication and unlocks the current session without deleting data.
- [ ] Change App Code works after device-owner authentication.
- [ ] Turning off App Lock requires device-owner authentication.
- [ ] Settings > Passwords & Codes can add Access, Wi-Fi & Network, Security, Equipment, and Other entries.
- [ ] A saved entry can optionally link to a room, system, device/equipment item, or detector.
- [ ] Secret value is masked by default.
- [ ] Reveal requires authentication and hides again after about 30 seconds.
- [ ] Copy requires authentication and clipboard content expires after about one minute.
- [ ] Edit and Delete require authentication.
- [ ] Passwords & Codes do not appear in Home Transfer/export files or household iCloud sync.
- [ ] Existing CloudKit sharing, detector battery reminders, photo flows, and Account features still work.
