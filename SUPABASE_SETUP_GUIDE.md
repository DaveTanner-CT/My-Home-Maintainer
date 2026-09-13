# Supabase Setup — My Home Keeper v0.45

v0.45 requires one additional database migration before family invitations work.

## 1. Run the SQL migration

1. Open the **My Home Keeper** project in Supabase.
2. Open **SQL Editor**.
3. Choose **New query**.
4. Open `SUPABASE_SETUP.sql` from this v0.45 package.
5. Copy the entire file into Supabase.
6. Click **Run**.

Supabase may warn that the query contains destructive operations because the script drops and recreates Row Level Security policies. It does **not** drop the home-data tables or delete your existing sync records.

## 2. Verify the new objects

In **Table Editor**, under the `public` schema, you should now see:

- `household_snapshots` (older v0.43 compatibility table)
- `household_sync_chunks`
- `household_sync_manifests`
- `households`
- `household_members`
- `household_invitations`

The SQL also creates the RPC function:

- `accept_household_invitation`

## 3. Re-upload once from the owner device

After v0.45 is installed, the owner can either create the first invitation or upload the home again. Both paths ensure that the existing local household is represented in the new `households` and `household_members` cloud tables.

## 4. Invite a family member

On the owner's device:

1. Open **Household**.
2. Tap **Invite Family Member**.
3. Enter an email address.
4. Select **Editor** or **Viewer**.
5. Tap **Invite**.
6. Share the generated invitation code.

The email is stored with the invitation for recognition and record-keeping. The invitation code is the reliable acceptance method, including when Apple uses a private relay email.

## 5. Join from another Apple account

On the family member's device:

1. Sign in with their own Apple ID.
2. Confirm **Cloud Session — Connected**.
3. Open **Household**.
4. Tap **Join Household**.
5. Enter the 8-character invitation code.
6. After acceptance, open **Cloud Sync**.
7. Tap **Check for My Cloud Household**.
8. Download the home to the empty device.

## Roles in v0.45

- **Owner** — manages household membership and remains the manual cloud publisher.
- **Editor** — member role is established now; full multi-writer/incremental cloud publishing is planned for the next sync phase.
- **Viewer** — can join and download/view the shared household without membership-management rights.

## Existing data safety

The migration preserves the v0.44 structured sync tables and existing cloud revisions. It adds membership-aware read access without deleting the owner's previously uploaded home.
