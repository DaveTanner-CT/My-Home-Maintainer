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

## v0.25 — Multi-Room Linking & Relationship Flows
- Room pages can now link existing Projects, Paint & Finishes, Home Systems, Devices & Equipment, Fixtures, and Tasks in addition to creating new records.
- Shared records can belong to multiple rooms without duplication (for example, one mini-split serving two rooms).
- Related tasks inherit room context through linked systems/devices/fixtures/projects.
- Detail views, transfer archives, exports, room rename/delete behavior, and primary-room editing now preserve the expanded relationships.

## v0.26 — Paint Mixing Labels & Room-Based Safety/Consumable Locations

- Paint/Finish records can capture or choose a photo of the paint mixing label directly during Add/Edit.
- Smoke & CO Detectors now select their location from the existing Rooms / Areas list.
- Filters & Consumables now have the same Room / Area location selector.
- Detector and Consumable room assignments appear in list/detail views and are preserved in export/transfer data.

## v0.27 — Relationship & Navigation Audit

- Room pages now surface Smoke & CO Detectors and Filters & Consumables, with room context preselected when adding new records.
- Project pages now show linked tasks and support creating or linking an existing task.
- System, Device/Equipment, and Fixture pages now support safe existing-task linking.
- Existing-task linking never silently reassigns a task already linked to a different record of the same type.
- Vendor pages now expose related devices/equipment and fixtures, plus direct existing-task linking.
- Home page, Settings, transfer, and export metadata report version 0.27.


## v0.28 — Multi-Room Editing
- Home Systems can now select every room/area they serve directly in Add/Edit.
- Devices & Equipment, Fixtures, Paint/Finish, Projects, and Tasks use the same multi-room editor for consistent relationship management.
- Existing primary-room relationships are preserved for compatibility while additional rooms remain linked.
- Selecting or removing rooms from a form updates the same relationships used by Room pages and detail pages.
- Version metadata updated to 0.28.


## v0.28.1 — Build Fix
- Fixed the multi-room selector compile error caused by mixing `.tint` and `.secondary` shape styles in a ternary expression.
- Uses explicit `Color.accentColor` / `Color.secondary` values for compiler-safe styling.
- Cleaned two non-fatal sample-data cleanup warnings.
- Version metadata updated to 0.28.1.


## v0.29 — Home Setup Navigation Consolidation
- Replaced the main-tab `My Home` entry with `Home Setup`.
- The third main tab now opens `HomeSetupView` directly between Tasks and Projects.
- Preserved My Home-only functionality by adding Home History, Vendors, and the Add Home History Event action to Home Setup.
- Updated navigation copy that still directed users to My Home.
- Updated visible and export/transfer build metadata to 0.29.


## v0.29.1 — My Home Tab Label
- Renamed the main-tab label from `Home Setup` back to `My Home`.
- The tab still opens `HomeSetupView`; all v0.29 consolidation remains intact.
- Updated visible and export/transfer build metadata to 0.29.1.

## v0.30 — Connected History & Actionable Room Summaries
- Added prefilled Home History creation directly from Room, Home System, Device/Equipment, Fixture, and Project detail pages.
- Home History matching for systems and devices now prefers direct SwiftData relationships while preserving legacy name-based records.
- Project detail now surfaces its connected Home History records.
- Room detector, consumable, and warranty summary counts now open the exact records behind the count.
- Updated visible and export/transfer build metadata to 0.30.


## v0.33 — Pre-Flight Hardening Test Candidate

- Added one-tap consumable replacement recording with automatic next-date calculation and Home History logging.
- Added direct replacement reminders from detector and consumable detail pages.
- Added prefilled Home History actions for detectors and consumables.
- Updated visible and export/transfer build metadata to 0.31.


### v0.33 pre-flight hardening
- Cancels pending local notifications when a task is deleted.
- Makes project deletion deterministic: project planning items/measurements and project-only attachments are deleted, while linked tasks, home records, and history are preserved and unlinked.
- Explicitly clears room references from history and attachments when a room is deleted.
- Surfaces save errors when recording a consumable replacement.
- Build/export/transfer metadata updated to 0.33.
- Intended as a feature-freeze test candidate for full workflow testing.

## v0.34 — Furniture + Selective Ownership Transfer
- Added Furniture as a first-class Foundation record immediately after Fixtures.
- Added room linking, photos/documents, purchase/warranty/reference details, vendor/project connections, search, export, and project-completion support for Furniture.
- Owner Transfer now includes an item-by-item "Items Staying With Home" selector for Furniture, Fixtures, and Devices & Equipment.
- Unselected movable items and their owned attachments are omitted from the transfer package while shared home history/tasks remain available without broken direct links.
- Build/export/transfer metadata updated to 0.34.


## v0.35 — Compact Room Section Actions

- Simplified Room page category actions to compact header icons.
- Categories that support both workflows show a + button and link button beside the category title.
- Removed repeated full-width Create New / Link Existing rows from room sections.
- Detectors, Filters & Consumables, and Recent Home History show a compact + action because those sections do not currently support non-destructive multi-room linking.
- Existing top-right + menu remains available as an alternate shortcut.
- Build/export/transfer metadata updated to 0.35.


## v0.36 — UI Refinement + Consistent Room Editing

- Room detail is now read-only for room properties; the Edit button owns room name, type, favorite, notes, dimensions, and unit changes.
- Room dimensions display as a concise read-only summary and are edited together with Save/Cancel in Room Edit.
- Room photo adding moved into a compact section-header action.
- Empty Room states use lighter rows instead of visually heavy cards.
- Room category headers show small count badges and retain compact + / link actions.
- Project, System, Device/Equipment, Fixture, Furniture, and attachment/history/task sections use the same compact header pattern where applicable.
- Photos & Documents actions moved into compact section headers throughout the app.
- Task deletion moved to a More menu so destructive actions do not compete with primary actions.
- Dashboard/detail spacing tightened for faster scanning while preserving all workflows.
- Build/export/transfer metadata updated to 0.36.

## v0.37 — Vendor Contacts Integration

- Vendor Add/Edit includes **Import from Contacts** using the native iOS contact picker.
- Contact selection prefills business/contact name, phone, email, website, and address; users can edit before saving.
- Vendor detail includes **Add Vendor to Contacts**, opening the native iOS new-contact editor prefilled from the Vendor record.
- Contacts interactions are explicitly user initiated; Home Maintainer does not silently modify Contacts.
- Contacts privacy usage text is included in the project configuration.


## v0.37.3 — Contacts Integration Fix

- Fixed Contacts → Vendor import handoff so selected contact values populate the Vendor form reliably.
- Added a visible **Add to Contacts** action in each Vendor detail Contact section.
- Kept the native iOS contact editor for reviewing/saving exported vendor contacts.
