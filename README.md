# My Home Keeper v0.45 — Family Invitations & Memberships

Version 0.45 adds real cloud household membership on top of the v0.44 structured Supabase sync.

## What changed

- Owners can create cloud invitations for family members.
- Invitations have Editor or Viewer roles.
- Each invitation gets an 8-character code that can be shared with the family member.
- Family members sign in with their own Apple ID and accept the invitation code.
- Joined members become real Supabase household members.
- Household member lists can be refreshed from the cloud.
- Owners can change Editor/Viewer roles and remove members.
- Joined members can discover and download the existing shared household through Cloud Sync.
- Structured sync RLS now allows household members to read the shared cloud home.
- Settings now displays the actual version and build number dynamically.

## Important sync scope

v0.45 keeps manual structured sync from v0.44. The Owner remains the cloud publisher in this release. Photos/documents are still local and are not part of cloud sync yet.

## Required Supabase step before testing

Run the complete `SUPABASE_SETUP.sql` file in the Supabase SQL Editor before using family invitations. It creates the household/member/invitation tables, the invitation acceptance RPC, and updated Row Level Security policies.

## First family-member test

1. Owner updates to v0.45 and confirms Cloud Session is Connected.
2. Owner opens Household and chooses Invite Family Member.
3. Enter the family member's email, choose Editor or Viewer, and create the invitation.
4. Share the generated 8-character code.
5. Family member installs/updates My Home Keeper, signs in with their own Apple ID, and connects the Cloud Session.
6. Family member opens Household > Join Household and enters the invitation code.
7. After joining, family member opens Cloud Sync > Check for My Cloud Household > Download to This Empty Device.

## Version

- Marketing version: 0.45
- Build: 450
