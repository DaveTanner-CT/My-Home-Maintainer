# My Home Keeper v0.49.1

## Photo Library fix
The shared photo-source control now presents Photo Library through a dedicated PHPicker controller, fixing library presentation failures from unsaved forms such as Add Fixture. The change applies to all forms and attachment flows that use the shared photo picker.

# My Home Keeper v0.49

This release continues the CloudKit family-sharing work with safer day-to-day sync visibility.

## What changed

- iCloud Sync now checks CloudKit automatically when the screen opens.
- Pull to refresh or use **Refresh Cloud Status** at any time.
- The app remembers the last cloud version applied on the current device.
- When another device/family member has uploaded a newer snapshot, the screen shows a clear **newer cloud copy available** warning.
- Owner devices continue to upload to the private CloudKit household record.
- Invited family members continue to read/write the CKShare record in `sharedCloudDatabase`.
- Whole-home downloads/replacements still require confirmation; v0.49 intentionally does not silently overwrite local edits.

## CloudKit setup

The `HouseholdSnapshot` and `cloudkit.share` schemas should already be deployed to Production from the v0.48.1 bootstrap process. No additional Apple Developer setup is required for v0.49.

## Build

- Marketing version: 0.49
- Build: 490
- Bundle ID: `org.scriptingforschools.HomeMaintainer`
