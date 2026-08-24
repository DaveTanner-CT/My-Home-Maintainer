# Home Maintainer v0.3

This release builds on v0.2.4 and focuses on photos/documents plus deeper project planning and shopping.

## New in v0.3

### Photos & documents
Photos and documents can now be attached to:
- Rooms
- Tasks
- Vendors
- Home Systems
- Appliances & Equipment
- Paint & Finishes
- Smoke/CO Detectors
- Filters & Consumables
- Maintenance Records
- Projects
- Project Items

Attachments can be categorized as Photo, Manual, Warranty, Receipt, Invoice, Estimate, Proposal, Document, or Other. They can be opened, renamed, captioned, re-categorized, and deleted. Photos display inline; documents use Quick Look.

### Project planning improvements
- Project cover photos
- Project-level photos/documents
- Product-level photos/documents
- Purchase date and actual cost tracking
- Shopping Mode filters: Need to Buy, All, Considering, Favorite, Purchased
- Shopping Mode grouping by Store or Category
- Swipe actions to mark Favorite, Purchased, or Rejected
- Project spending summary in Shopping Mode
- Compare Options screen with horizontally scrollable product comparison cards
- Quick status actions from project item details

### Search
Global search now includes attachment names, captions, categories, and filenames.

## Build
The existing Codemagic Ad Hoc workflow and bundle ID are preserved:

`org.scriptingforschools.HomeMaintainer`

Replace the matching files in the GitHub repository with this release, commit, refresh Codemagic, and run **Home Maintainer Ad Hoc iPhone Build**.

## Suggested test pass
1. Add a photo and PDF/manual to a Home System.
2. Add a receipt to a Maintenance Record.
3. Add a paint-can photo to a Paint record.
4. Add a cover photo to a Project.
5. Add multiple project products, prices, stores, and photos.
6. Open Shopping Mode and test filters/grouping/swipe actions.
7. Open Compare Options and compare several products.
8. Search globally for an attachment name or caption.
9. Close and reopen the app and confirm attachments and purchase data persist.

## Note on development data
This remains a development build. The SwiftData schema has expanded to support attachments and purchase dates. Keep test data replaceable until backup/export and explicit migration handling are added in a later release.
