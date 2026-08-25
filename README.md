# Home Maintainer v0.7

This update strengthens the Room / Area hub so related records can be created where they belong.

## Room / Area connections
- Add a Project directly from a Room / Area.
- Add Paint / Finish directly from a Room / Area.
- Add Appliance / Equipment directly from a Room / Area.
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
