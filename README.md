# Home Maintainer v0.8

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


## v0.8 additions
- New Fixtures records for faucets, lighting, sinks, toilets, fans, hardware, thermostats, and other installed items.
- Fixtures link directly to Rooms / Areas and support photos/documents, vendor, purchase, warranty, finish/color, and replacement-part details.
- Home Systems now have direct Room / Area relationships with legacy location matching retained for older records.
- Room / Area detail pages can add and manage Fixtures and Home Systems directly.
- Fixtures are included in global search and JSON export.

## v0.9 additions
- Seasonal Maintenance planning by Spring, Summer, Fall, and Winter with one-tap task creation.
- Replacement Forecast for systems, appliances/equipment, and fixtures using recorded dates and service-life assumptions.
- Project completion handoff: purchased project items can be promoted into permanent Appliance, Fixture, Home System, Paint/Finish, or home-history records, carrying the linked Room/Area and project photo forward.
