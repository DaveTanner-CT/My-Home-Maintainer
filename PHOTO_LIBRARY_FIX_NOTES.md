# v0.49.1 Photo Library Presentation Fix

## Problem
On unsaved record forms (reported first on Add Fixture), the shared photo source menu could open the camera, but choosing **Choose from Photo Library** sometimes failed to present the Photos library. After saving the record, the same photo-library action from the record detail screen worked.

## Root cause
All of these flows shared `PhotoSourceButton`. Camera capture was presented with a dedicated UIKit full-screen controller, while library selection relied on SwiftUI's `.photosPicker` modifier immediately after dismissing a confirmation dialog. That presentation chain is unreliable when the button is inside an unsaved `Form` that may itself be presented modally.

## Fix
`PhotoSourceButton` now uses a dedicated `PHPickerViewController` wrapper for Photo Library selection and presents it with `fullScreenCover`, mirroring the stable camera presentation path. Both camera and library wait briefly for the source confirmation dialog to fully dismiss before presenting another controller.

## Impacted areas audited
Because the fix is in the shared source picker, it covers all current call sites, including:
- Systems
- Devices / Appliances
- Paint / mixing-label photo
- Vendors
- Detectors
- Consumables
- Maintenance records / history
- Fixtures
- Furniture
- Tasks
- Projects
- Project items
- Existing attachment/photo sections

No model or persistence migration is involved.
