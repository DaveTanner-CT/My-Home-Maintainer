# My Home Keeper v0.45 Test Checklist

## Build / identity
- [ ] Build succeeds in Codemagic.
- [ ] TestFlight shows version 0.45 (Build 450).
- [ ] Settings > About shows `0.45 (Build 450)`.
- [ ] Existing owner iPhone data remains intact after update.

## Supabase migration
- [ ] Run v0.45 `SUPABASE_SETUP.sql` successfully.
- [ ] `households` table exists.
- [ ] `household_members` table exists.
- [ ] `household_invitations` table exists.
- [ ] Existing `household_sync_manifests` and `household_sync_chunks` still exist.

## Owner flow
- [ ] Apple Account Signed In.
- [ ] Supabase Configured.
- [ ] Cloud Session Connected.
- [ ] Household screen shows existing household.
- [ ] Invite Family Member opens.
- [ ] Editor invitation can be created.
- [ ] Viewer invitation can be created.
- [ ] Invitation displays an 8-character code.
- [ ] Share Invitation opens the iOS share sheet.
- [ ] Refresh Members shows owner.

## Family member flow
- [ ] Family member signs in with a different Apple ID.
- [ ] Cloud Session becomes Connected.
- [ ] Household > Join Household opens.
- [ ] Invalid code produces a clear error.
- [ ] Valid code accepts the invitation.
- [ ] Local household shell is created.
- [ ] Household screen shows the assigned role.
- [ ] Cloud Sync > Check for My Cloud Household finds the owner's cloud home.
- [ ] Download to This Empty Device succeeds.
- [ ] Representative rooms/systems/tasks/vendors/projects appear.

## Membership management
- [ ] Owner Refresh Members shows joined family member.
- [ ] Owner can switch Editor to Viewer.
- [ ] Owner can switch Viewer to Editor.
- [ ] Owner can remove a non-owner member.
- [ ] Owner cannot remove self through the UI.
- [ ] Owner can revoke a pending invitation.

## Regression
- [ ] Owner can still upload structured cloud home.
- [ ] Existing iPad same-account sync still works.
- [ ] Existing home data is not overwritten unexpectedly.
- [ ] Photos/documents remain local as expected in this release.
