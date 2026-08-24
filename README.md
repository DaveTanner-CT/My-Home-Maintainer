# Home Maintainer v0.2

This package is designed to replace/merge with the files at the root of the existing `My-Home-Maintainer` GitHub repository.

## Major additions

- View/Edit/Save/Delete flows for Tasks, Rooms, Systems, Appliances, Paint, Vendors, Detectors, Consumables, Maintenance Records, Projects, Project Items, and Project Measurements.
- Rich detail screens for the major home-record categories.
- Linked navigation between tasks and related rooms, systems, appliances, vendors, and projects.
- Editable project planning items and measurements.
- Maintenance-history detail/editing.
- Expanded task editing: priority, contact information, project relationship, recurrence settings.
- Search results now open the relevant records and include project shopping items.
- Paint records can be duplicated to another room.
- Ad Hoc Codemagic build configuration retained for `org.scriptingforschools.HomeMaintainer`.

## GitHub update

Upload/replace the corresponding folders/files in the root of the repository:

- `Models/`
- `Services/`
- `Utilities/`
- `Views/`
- `HomeKeeperApp.swift`
- `Info.plist`
- `project.yml`
- `codemagic.yaml`

Do not add an extra `HomeMaintainer-v0.2` folder level in GitHub.

## Build

Use the existing Codemagic workflow: **Home Maintainer Ad Hoc iPhone Build**.


## v0.2.3 navigation fix
Edit actions on detail screens now push dedicated edit forms in the existing NavigationStack instead of relying on nested modal sheets. My Home and Project list rows have full-width tap targets, and vendor contact actions are isolated to their individual contact rows.

## v0.2.4 Navigation update

- Replaced the Calendar bottom-navigation tab with a primary **Tasks** tab.
- Tasks now includes four views: **Attention**, **Upcoming**, **All**, and **Calendar**.
- Calendar remains available as an optional secondary view instead of occupying a primary tab.
- The All Tasks view includes task search plus status and category filtering.
- The Home dashboard's **View All Tasks** link now opens the Tasks area directly in All mode.
