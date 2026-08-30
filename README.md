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

## v0.14 — Maintenance Intelligence
- Recommended Maintenance now derives suggestions from the home's actual systems, devices/equipment, fixtures, detectors, consumables, and exterior/property areas instead of manual feature toggles.
- Recommendations explain why they appear and retain direct links to the relevant system/device/fixture/room when converted to tasks.
- Added Review & Add (prefilled Task form) and Quick Add flows, plus Add All Missing Recommendations.
- TaskFormView now supports richer prefilled task creation (description, category, recurrence, priority) without changing existing callers.
- Safety baseline recommendations remain visible for every home; detector replacement and consumable dates can produce date-aware one-time recommendations.


## v0.15
- Added Home Outlook with 1-year, 3-year, 5-year, and all-horizon replacement planning.
- Shows known historical cost baselines without pretending they are future-price forecasts.
- Flags missing purchase/install dates, costs, and system service-life estimates.
- Lets a forecasted replacement become a linked planning project in one tap, carrying its Room/Area and known baseline budget.
- Replaced the dashboard/settings Replacement Forecast shortcut with Home Outlook while preserving the existing detailed forecast implementation.

## v0.17 — UX simplification pass
- Reduced dashboard shortcuts to three high-value entry points: Rooms & Areas, Home Care, and Home History.
- Reorganized My Home around how people think: places, equipment & finishes, care & planning, and records & people.
- Added Home Care as a focused hub for maintenance, seasonal planning, warranties, replacement outlook, detectors, and consumables.
- Removed duplicate feature links from Settings so Settings now focuses on profile/setup, data transfer, notifications, and app information.
- Consolidated Room/Area add actions into one + menu instead of six repeated buttons.
- Simplified project Shopping into a compact four-step progress flow while preserving decision-based comparison.
- Moved task filters into a toolbar menu to reduce visual clutter.
- Standardized user-facing terminology around Devices & Equipment, Installed in My Home, Home Care, and Home History.
- Standardized visible naming so electronics/appliances/tools are presented consistently as Devices & Equipment, while their detailed type/category remains available inside each record.



## v0.18.1 — Recommended Maintenance clarity

- Keeps all v0.18 workflow-hardening and transfer-integrity changes.
- Moves actual recommendations ahead of inventory diagnostics.
- Replaces the unexplained Home Signals count list with a collapsed “Why am I seeing these?” section.
- Explains how each inventory type affects recommendations and makes each row a shortcut to the relevant My Home records.
- Shortens the introductory copy so personalized maintenance appears sooner on screen.

## v0.18 — Workflow hardening
- Transfer import now checks every data category before deciding a store is empty.
- Transfer packages receive an integrity check before preview/import; broken relationship IDs are rejected before data is written.
- Import requires an explicit final confirmation.
- Task completion validates cost input and reports save failures instead of silently dismissing.
- Project completion asks for confirmation before closing.
- Backup copy is clearly distinguished from the supported stable-ID Home Transfer import path.


## v0.20 — Room dimensions + photo grid

- Preserves the full Room Detail page: projects, paint/finishes, systems, devices/equipment, fixtures, tasks, history, and inline add actions.
- Adds room dimensions directly to the Area section with Feet/Meters selection, Length, Width, Ceiling Height, and calculated floor area.
- Converts saved measurements when switching between Feet and Meters.
- Moves room photos to a compact thumbnail-only grid directly below Area (2 columns on compact layouts, 3 on regular layouts).
- Keeps photos tappable for the existing full-screen zoom viewer and keeps captions editable in photo details.
- Leaves documents in the Documents section at the bottom so room photos are not duplicated there.
- Includes dimension fields in Home Transfer and Home Export archives.

## v0.19 — Home History stories

- Preserves all v0.18.1 workflow-hardening and Recommended Maintenance clarity changes.
- Groups the Home History timeline by month and year for easier scanning.
- Adds Home Stories: connected timelines for rooms/areas, fixtures, devices/equipment, systems, projects, and vendors.
- Each story summarizes event count, recorded spending, and the years covered.
- Keeps all existing Home History search/filter/add/edit behavior and direct links to connected records.


## v0.21 Room Page Update
Room detail sections now include visible inline Add controls for Projects, Paint & Finishes, Home Systems, Devices & Equipment, Fixtures, and Tasks. The top-right + menu remains as an additional shortcut.


## v0.22 — Feet/Inches + Connected Flows

- Feet-based room dimensions now use separate feet and inches inputs; meters remains decimal.
- Home Outlook data-quality counts link to the exact records behind each issue.
- Home Setup warnings now open filtered affected-record lists.
- Home Insights and dashboard summary counts are actionable.
- Room At a Glance project/task counts open room-specific record lists.


## v0.23 — Remove Legacy Sample Data

- Removed automatic demo/sample-data seeding.
- Added a conservative one-time cleanup that removes only records still matching the original demo dataset.
- User-edited records, records with attachments, and sample-origin records now referenced by user-created content are preserved.
- Pristine sample room shells are removed only when nothing user-created is linked to them.
- The existing Home object is retained so upgrading does not wipe user data.

## v0.24 — Room Inches Normalization

- Feet-based room dimensions now safely accept total inches in the inches field.
- Entries such as 38 inches normalize to 3 ft 2 in when leaving the field.
- Entries such as 74 inches normalize to 6 ft 2 in.
- Raw typing is preserved while editing so SwiftUI does not reformat the field mid-entry.
