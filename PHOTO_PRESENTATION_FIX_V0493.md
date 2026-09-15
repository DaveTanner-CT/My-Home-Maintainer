# My Home Keeper v0.49.3 — New-record photo presentation fix

## Problem fixed
On long unsaved forms such as Add Fixture, Add Furniture, and Add Device / Equipment, choosing Camera or Photo Library could dismiss the source popup, jump the form to the top, and never present the picker.

The old shared photo control used a confirmation dialog followed by a delayed second presentation. Dismissing the dialog could cause SwiftUI to rebuild the long Form before the delayed presentation occurred.

## Fix
- Removed the chained confirmationDialog -> delayed picker presentation.
- `PhotoSourceButton` now opens one stable full-screen photo flow immediately.
- Camera and Photo Library are chosen inside that same presentation.
- Switching to camera/library changes the content of the already-presented photo flow; no second SwiftUI sheet/fullScreenCover is requested.
- This shared fix applies everywhere `PhotoSourceButton` is used, including new and existing records.

## Room / Area enhancement
The Add/Edit Room / Area form now includes a Photo section. A selected photo is saved as a room attachment when the room is saved.

## Primary regression tests
1. Add Fixture -> Add Photo -> Take Photo.
2. Add Fixture -> Add Photo -> Choose from Photo Library.
3. Repeat on Add Furniture and Add Device / Equipment.
4. Confirm Add System and Safety-related forms still work.
5. Add Room / Area -> Add Photo -> select/capture -> Save -> verify photo appears on room detail.
6. Verify existing-record + photo actions still work.
