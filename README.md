# HomeKeeper v0.1

HomeKeeper is the first functional SwiftUI prototype of the home maintenance and project-planning app described in the supplied build specification.

## Current target

- iPhone
- iOS 17+
- SwiftUI
- SwiftData local persistence
- Local notifications
- PhotosPicker for project-item photos

`HomeKeeper` is a working title and can be renamed before release.

## What is implemented

### Home dashboard
- Overdue / Current / Upcoming counts
- Lead-time logic for Current tasks
- Needs Attention checklist
- Coming Soon list
- View All Tasks
- Quick access to Systems, Rooms, Appliances, Paint, Projects, and Vendors
- Global search

### Tasks
- Add and edit tasks
- Categories
- Due dates
- Lead time in days
- One-time, weekly, monthly, quarterly, six-month, annual, and ten-year recurrence
- Scheduled-date vs. completion-date recurrence
- Related room, system, appliance, and vendor
- Detail view with contact links
- Completion workflow
- Completion date, vendor, cost, and notes
- Maintenance-history records
- Automatic calculation of next due date for recurring tasks
- Local reminder scheduling

### Default sample maintenance
- Monthly smoke/CO detector testing
- Six-month detector battery replacement
- Ten-year detector replacement
- Fire-extinguisher inspection
- Annual furnace service with 60-day lead time
- Refrigerator-filter replacement

### Calendar
- Graphical calendar
- Tasks for selected date
- Status filter
- Category filter

### Global search
Searches:
- Tasks
- Home systems
- Appliances
- Rooms
- Paint and finishes
- Smoke/CO detectors
- Filters and consumables
- Vendors
- Projects
- Maintenance history

### My Home
- Rooms & Areas
- Home Systems
- Appliances & Equipment
- Paint & Finishes
- Smoke & CO Detectors
- Filters & Consumables
- Vendors
- Maintenance History
- Add forms for each major record type

### Safety devices
- Individual detector records
- Location
- Smoke / CO / Combination type
- Manufacturer and model
- Manufacture and installation dates
- Battery type
- Hardwired flag
- Automatic 10-year replacement-date calculation

### Consumables
- Filters, batteries, pads, etc.
- Size
- Manufacturer
- Part number
- Purchase link
- Replacement interval
- Last replaced
- Calculated next replacement

### Project planning
- Project stages
- Room/area
- Target date
- Budget
- Planned/purchased/remaining budget rollups
- Project categories
- Idea-only cards
- Product cards
- Manufacturer, model, SKU, finish/color, dimensions
- Store, website, unit cost, quantity, estimated total
- Considering / Favorite / Purchased / Rejected status
- Project-item photo selection
- Measurements
- Store-filterable shopping list

## Sample data
The first launch seeds realistic demo content so every major screen has something to display. Seed data is inserted only when no Home record exists.

## Open in Xcode

### Option A — XcodeGen
On a Mac with Xcode installed:

1. Install XcodeGen if needed:
   `brew install xcodegen`
2. Unzip this folder.
3. Open Terminal in the `HomeKeeperV1` folder.
4. Run:
   `xcodegen generate`
5. Open `HomeKeeper.xcodeproj`.
6. Select the `HomeKeeper` target.
7. Set your Apple Development Team under **Signing & Capabilities**.
8. Choose an iPhone simulator and Run.

### Option B — Regular Xcode project
If you do not want to use XcodeGen:

1. In Xcode, create a new **iOS App** named `HomeKeeper`.
2. Choose **SwiftUI** and **SwiftData**.
3. Set the deployment target to iOS 17 or later.
4. Delete the generated app/content Swift files.
5. Drag the entire `HomeKeeper` source folder from this package into the Xcode project and choose **Copy items if needed**.
6. Ensure all Swift files are members of the HomeKeeper target.
7. Add these privacy strings to the target Info settings if they are not inherited from the included Info.plist:
   - Photo Library Usage: `HomeKeeper lets you attach photos to home records and project ideas.`
   - Camera Usage: `HomeKeeper lets you photograph equipment labels, paint cans, receipts, and project ideas.`
8. Set your signing team and Run.

## Important first-version limitations

This is a functional first application slice, not an App Store submission build yet. The following pieces are intentionally still incomplete:

- iCloud / CloudKit syncing
- Multiple-home/shared-household support
- Full onboarding and recommended-task selection
- Full document/PDF/receipt attachment management
- Camera capture for every record type
- Photos on all system/appliance/paint records
- Project comparison screen
- Full project templates
- Create/edit screens for every possible field in the data model
- Delete/archive workflows
- Import/export/backup
- Advanced notifications and notification settings
- Warranty-expiration notifications
- Service-life analytics
- Spending reports
- Accessibility QA on real devices
- Unit/UI tests
- App icon, screenshots, privacy manifest, store metadata, and App Store signing/release configuration

## Recommended next development pass

1. Run this version on an iPhone simulator and a real iPhone.
2. Refine the Home dashboard and navigation based on actual use.
3. Add full record editing/deleting.
4. Build document/photo attachment management.
5. Add onboarding and the recommended-maintenance library.
6. Add project comparison/templates and richer shopping mode.
7. Add CloudKit syncing only after the local data model feels stable.
8. Add automated tests for recurrence, lead-time, and task-completion behavior before App Store release.

## Validation performed here

All Swift source files were passed through Swift's syntax parser successfully. This environment is Linux and does not include Apple's SwiftUI/SwiftData/UIKit SDKs, so a full iOS compile and simulator run must be performed in Xcode on macOS.
