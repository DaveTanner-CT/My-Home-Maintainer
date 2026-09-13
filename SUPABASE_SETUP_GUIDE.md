# My Home Keeper v0.43 — Supabase Setup

v0.43 is built so the populated iPhone can upload a household snapshot and another device signed into the same Apple account can download it. The app continues to use SwiftData locally/offline.

## 1. Create a Supabase project
Create a project at Supabase and wait for it to finish provisioning.

From the project's **Connect** / API settings, copy:
- Project URL
- Publishable key (`sb_publishable_...`; a legacy anon key also works while Supabase still supports it)

Never place a Supabase secret/service-role key in the iOS app.

## 2. Enable Apple authentication in Supabase
In the Supabase dashboard, open **Authentication → Providers → Apple** and enable Apple.

The native iOS app identifier used by My Home Keeper is:

`org.scriptingforschools.HomeMaintainer`

Add that native App ID/bundle ID as an accepted Apple client ID. The app already has Apple's Sign in with Apple capability enabled.

## 3. Create the cloud table and RLS policies
Open **SQL Editor** in Supabase and run the complete contents of:

`SUPABASE_SETUP.sql`

This creates `public.household_snapshots` and Row Level Security policies that only allow the signed-in owner to access that owner's snapshot.

## 4. Put the public Supabase settings into project.yml
In the root `project.yml`, replace:

`YOUR_SUPABASE_PROJECT_URL`

with a value like:

`https://YOUR_PROJECT_REF.supabase.co`

Replace:

`YOUR_SUPABASE_PUBLISHABLE_KEY`

with the project's publishable key.

These are public client configuration values. Do not use the secret key.

## 5. Build v0.43
The build is configured as:
- Marketing version: `0.43`
- Build number: `430`

Run the existing Codemagic TestFlight workflow.

## 6. Re-establish Apple sign-in on both devices
After installing the Supabase-configured build, sign out of My Home Keeper and sign back in with Apple once on each device. v0.43 uses the native Apple identity token to establish the matching Supabase Auth session.

## 7. First household migration
### On the populated iPhone
1. Confirm the Household exists under Settings → Household Sharing.
2. Open Settings → Cloud Sync.
3. Confirm Supabase = Configured and Cloud Session = Connected.
4. Tap **Upload This Home to Cloud**.

### On the iPad
1. Do not recreate the iPhone's home records manually.
2. Sign into My Home Keeper using the same Apple account.
3. Open Settings → Cloud Sync.
4. Tap **Check for My Cloud Household**.
5. Tap **Download to This Empty Device**.

## Current synchronization behavior
v0.43 intentionally uses explicit snapshot push/pull rather than silent conflict merging:
- Upload from the device whose data should become the latest cloud copy.
- Other linked devices can explicitly replace their local structured home data from that cloud copy.
- An initial download is blocked if a device already contains home records.
- Photos and documents stay local until the shared storage phase.

This conservative approach prevents the first cloud release from silently overwriting existing household data.
