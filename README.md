# Home Maintainer v0.4

This build continues the connected-home foundation from v0.3.

## Added in v0.4

- Editable Home Profile with name, address, year built, purchase date, square footage, and notes.
- Settings screen reachable from the Home dashboard gear button.
- Recommended Maintenance library with home-system toggles and one-tap task creation.
- Duplicate-safe recommended task insertion.
- Notification preferences for lead-time, due-date, and overdue reminders.
- Configurable reminder time and a manual "Apply Notification Settings" action that reschedules active tasks.
- Home-system health/planning display showing warranty condition and estimated service-life progress.
- Appliance warranty status display.
- Existing v0.3 photos, documents, project shopping, compare, edit, search, and Ad Hoc build workflow preserved.

## Build

Use the existing Codemagic **Home Maintainer Ad Hoc iPhone Build** workflow.
Bundle identifier remains `org.scriptingforschools.HomeMaintainer`.

## v0.4.1 build-entry fix
The SwiftUI app entry point now lives in `App/HomeKeeperApp.swift`, and XcodeGen explicitly includes the `App` folder. Codemagic also verifies the `@main` entry point before generating the Xcode project. This addresses an archive linker failure where `_main` was missing.

## v0.5 additions

- Full-screen photo viewing with pinch-to-zoom, pan, and double-tap zoom for attachments, project cover photos, and project item photos.
- Projects now link to actual Room / Area records instead of relying only on typed room names. Legacy project room names are resolved when edited.
- Linked projects automatically appear on each Room / Area detail screen.
- Rooms & Areas are grouped into Interior and Exterior / Property sections.
- New rooms/areas can be designated Interior or Exterior / Property.
- Optional one-tap starter set of common exterior/property areas: roof, garage, siding, steps/entry, deck/patio, driveway, walkways, stone walls, lighting, gardens, greenhouse, shed/outbuildings, fencing/gates, and gutters/drainage.
- Exterior/property areas use the same connected-record behavior as interior rooms, so they can carry projects, tasks, paint/finishes, photos/documents, and related equipment records.
