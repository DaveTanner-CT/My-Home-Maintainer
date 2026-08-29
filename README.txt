Petite Design Studio - current development export
Generated: 2026-08-29

Included:
- Core Apps Script data model/setup
- Clients, projects, rooms
- Design workspace
- iPhone/iPad photo upload
- Design notes
- Apple Pencil / touch sketch canvas
- Project Overview photo & sketch thumbnails
- Large visual viewer
- Design record metadata editing
- Corrected visual-card click behavior (View/Edit vs Open Original)
- Design Hub and project breadcrumbs

Setup:
1. Create/open the Apps Script project.
2. Add each .gs and .html file using the same filename (without duplicate extensions).
3. Put the central spreadsheet ID and project root Drive folder ID in Setup.gs.
4. Run PDS_runInitialSetup() once.
5. Deploy as a Web app restricted to appropriate staff while testing.

Important:
- Markup Photo is still shown as a coming feature in this export; non-destructive photo markup/revisions are the next planned build step.
- Do not make project Drive files public just to render previews.
