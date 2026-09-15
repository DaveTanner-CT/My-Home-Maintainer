# v0.49.2 Photo Presentation Fix

## Problem
In unsaved Add/Edit forms (for example Add Fixture), the photo source chooser could open but the selected Camera or Photo Library presentation would fail. v0.49.1 made this worse because Camera and Photo Library each had their own `fullScreenCover` attached to the same source button.

## Fix
`PhotoSourceButton` now uses one enum-driven `fullScreenCover(item:)` for both destinations. Camera and Photo Library no longer compete for presentation from the same form row. Both UIKit pickers dismiss by clearing the single parent presentation state.

## Shared coverage
Because this is fixed in `Utilities/PhotoSourcePicker.swift`, it applies to every current `PhotoSourceButton` usage, including unsaved forms for Fixtures, Furniture, Systems, Devices/Appliances, Vendors, Detectors, Consumables, Tasks, Projects, Project Items, Paint/finish photos, and attachment/photo sections.

## Regression test
1. Add Fixture -> Add Photo -> Take Photo.
2. Add Fixture -> Add Photo -> Choose from Photo Library.
3. Repeat both paths in at least one other unsaved form (Furniture or Device).
4. Confirm the selected image preview remains in the form before Save.
5. Confirm saved-record photo `+` actions still work.
