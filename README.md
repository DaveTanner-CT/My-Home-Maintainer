# Home Maintainer v0.10

This update strengthens the Room / Area hub so related records can be created where they belong.

## Room / Area connections
- Add a Project directly from a Room / Area.
- Add Paint / Finish directly from a Room / Area.
- Add appliances, electronics, home technology, tools, and equipment directly from a Room / Area.
- Add a maintenance Task directly from a Room / Area.
- New records are automatically pre-linked to the Room / Area.
- Tap any linked record to open its detail page and edit it.

## Paint relationship upgrade
Paint & Finish records now have a real optional SwiftData relationship to Room / Area while retaining the legacy room-name field for compatibility. This means room renames can flow through linked paint records instead of breaking the connection. Legacy paint records are linked automatically when a matching Room / Area is opened.

## Existing v0.6.2 features retained
- Projects linked bidirectionally with Rooms / Areas.
- Home Insights and Warranty Center.
- JSON export.
- Full-screen zoomable photos.
- Exterior & Property areas.
- Recommended maintenance and notifications.


## v0.8 additions
- New Fixtures records for faucets, lighting, sinks, toilets, fans, hardware, thermostats, and other installed items.
- Fixtures link directly to Rooms / Areas and support photos/documents, vendor, purchase, warranty, finish/color, and replacement-part details.
- Home Systems now have direct Room / Area relationships with legacy location matching retained for older records.
- Room / Area detail pages can add and manage Fixtures and Home Systems directly.
- Fixtures are included in global search and JSON export.


## v0.10 additions
- Reworked Shopping into a visible four-step workflow: add options → compare → choose/purchase → install/save to My Home.
- Product options now have an optional buying-decision group (for example, Kitchen Faucet), so competing choices stay together in Shopping and Compare Options.
- Add options directly from Shopping or directly into an existing comparison group.
- Choose a purchase from Shopping or Compare Options, with the option to automatically close/reject the other contenders in that decision group.
- Installed/saved project items now receive a distinct Installed / Saved to Home status.
- Expanded Appliances & Equipment into Appliances, Electronics & Equipment, including Electronics, Home Technology, Outdoor Equipment, and Tools without adding another top-level button.

## v0.9 additions
- Seasonal Maintenance planning by Spring, Summer, Fall, and Winter with one-tap task creation.
- Replacement Forecast for systems, appliances/equipment, and fixtures using recorded dates and service-life assumptions.
- Project completion handoff: purchased project items can be promoted into permanent Appliance, Fixture, Home System, Paint/Finish, or home-history records, carrying the linked Room/Area and project photo forward.

## v0.11 connected workflow
- Room / Area pages now act as mini dashboards with project, task, asset, warranty, and recent-history context.
- Fixtures, devices/equipment, systems, and paint records can link back to a source/related project.
- Fixture tasks are first-class links; task completion writes typed, directly linked Home History records.
- Warranty reminders can be created directly from fixture, device/equipment, and system detail screens.
- Project lifecycle is explicit: Plan -> Shop & Compare -> Purchase -> Install & Save -> Complete.
- Installed project items become permanent home records that link back to the project and create installation history.
- Home History is a unified typed timeline for maintenance, repairs, installations, purchases, replacements, inspections, and projects.


## v0.12 — Home Transfer & safer data portability
- Added Home Transfer for seller-to-buyer handoff inside Home Maintainer.
- Transfer archives use stable archive IDs for relationships rather than names.
- New-owner import includes a preview before any data is written.
- Import is intentionally limited to a fresh/empty Home Maintainer data store to prevent accidental merging of two homes.
- Transfers include rooms/areas, systems, appliances/electronics/equipment, fixtures, paint, projects/items, tasks, home history, vendors, detectors, consumables, and stored attachments.
- Existing legacy JSON backup/export remains available separately.


## v0.13
- Home History is now searchable and filterable by event type, room/area, project, vendor, and year.
- Home History shows filtered event counts and recorded spending, with connected context visible in the timeline.
- Added direct Add History Event access from the Home History screen.
- Fixed manual Home History saves so notes and legacy related-item text are retained and the context is explicitly saved.
- Backup and Home Transfer screens now explain iOS Files destinations, including Google Drive and other enabled providers, and confirm successful saves.
- Home Transfer filenames now include the home name and export date.


## v0.13.1
- Replaced direct SwiftUI file-exporter flow with the standard iOS Share sheet for backup and owner-transfer exports.
- Export now clearly offers compatible destinations/apps such as Google Drive, Save to Files, Mail, AirDrop, and Messages.
- Google Drive guidance now recommends the Drive share extension first; Save to Files → Google Drive remains available when Apple's Files provider is working.
- Backup and transfer files are written as temporary JSON files and removed after the Share sheet completes.
