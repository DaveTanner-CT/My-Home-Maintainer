# HomeMaintainer v0.32 TC1 Full Test Checklist

Use this build as a feature-freeze test candidate. Test with real-looking throwaway records first.

## 1. Rooms / Areas
- Create, edit, rename, and delete a room.
- Enter dimensions in feet + inches, including total inches such as 38 -> 3 ft 2 in.
- Switch dimensions to meters and back.
- Add several room photos; verify 2/3-column thumbnails, zoom, captions, edit, and delete.
- From the room page create and link existing Projects, Paint/Finish, Systems, Devices/Equipment, Fixtures, Tasks, Detectors, and Consumables.
- Verify shared multi-room records remain linked to the other room when one room is removed/deleted.

## 2. Home Systems / Devices / Fixtures / Paint
- Create each record type and select multiple rooms where supported.
- Edit room selections and verify reverse links on each Room page.
- Link/create tasks and verify navigation both directions.
- Add Home History and attachments.
- For Paint/Finish, add/change a mixing-label photo.

## 3. Detectors / Consumables
- Verify Room / Area dropdowns.
- Create replacement reminders.
- For a consumable, use Mark Replaced Today; verify last/next dates and a Home History entry.

## 4. Tasks
- Create one-time and recurring tasks.
- Link rooms and home records.
- Complete tasks and verify Home History and next recurrence date.
- Delete a task and confirm it disappears without later notification.

## 5. Projects
- Create a project with multiple rooms, planning items, measurements, attachments, and linked tasks/home records.
- Complete/install a project item and verify resulting home records/history.
- Delete a throwaway project and confirm linked home records/tasks/history remain while project-only planning data is removed.

## 6. Home / My Home / Insights / Outlook
- Verify every count/warning that represents underlying records can be opened to those records.
- Verify Home Outlook missing-cost/date/service-life lists show the exact affected items.
- Verify My Home opens the consolidated Home Setup view.

## 7. Export / Transfer
- Export the home.
- Confirm room dimensions, multiple-room relationships, detector/consumable room locations, tasks, projects, and attachments are represented.
- If safe in the test environment, perform a transfer/import round trip and compare record counts and key relationships.

## 8. Navigation / destructive actions
- From each detail page test Edit, Back, linked-record navigation, unlink, and delete.
- Confirm destructive confirmations describe what will be retained vs deleted.

Record any issue with: screen, exact taps, expected result, actual result, and whether it is reproducible.

## Route Consistency (v0.33)
For each record type below, test Add from its main list and Add from a related Room (where available). Confirm the form offers the same fields and photo option, with the Room route only preselecting context.

- Fixture: main Fixtures list vs Room > Add Fixture
- Home System: main Systems list vs Room > Add Home System
- Device / Equipment: main Devices list vs Room > Add Device / Equipment
- Paint / Finish: main Paint list vs Room > Add Paint / Finish
- Task: main Tasks list vs Room/Project/System/Device/Fixture > Create New Task
- Detector: main Detectors list vs Room > Add Detector
- Consumable: main Consumables list vs Room > Add Filter / Consumable

Photo checks:
- Select a photo before saving a new Fixture, System, Device/Equipment, Detector, Consumable, Task, Vendor, and Home History Event.
- After save, open the record and confirm the photo appears under Photos & Documents.
- Edit an existing record, add another photo, save, and confirm both photos remain.
- Confirm Room photos, Paint mixing-label photos, Project cover photos, and Project Item photos retain their specialized existing workflows.

## Furniture + Ownership Transfer (v0.34)
- [ ] Home Setup shows Furniture immediately after Fixtures.
- [ ] Add Furniture from Home Setup and save a photo.
- [ ] Add Furniture from a Room page; confirm the room is preselected.
- [ ] Link one Furniture item to multiple Rooms / Areas.
- [ ] Confirm Furniture appears in room asset summaries and Global Search.
- [ ] Confirm a project purchase can be saved to My Home as Furniture.
- [ ] Open Settings > Home Transfer and start a new owner transfer.
- [ ] Confirm Furniture, Fixtures, and Devices & Equipment are shown item-by-item.
- [ ] Confirm all movable items are selected by default.
- [ ] Uncheck at least one item in each category and create a transfer.
- [ ] Confirm excluded items and their photos/documents are not present in the transfer file.
- [ ] Import the transfer into an empty test installation and confirm selected items import with room relationships intact.
