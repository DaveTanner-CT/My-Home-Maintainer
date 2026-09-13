# My Home Keeper v0.44 - Structured Sync Setup

v0.44 keeps SwiftData as the local/offline store, but changes the cloud transport from one large JSONB snapshot to smaller structured category chunks.

## One-time Supabase database update

In the existing Supabase project, open **SQL Editor**, paste the complete contents of `SUPABASE_SETUP.sql`, and run it.

The script adds:
- `public.household_sync_manifests`
- `public.household_sync_chunks`
- indexes for owner/revision lookup
- Row Level Security policies that restrict each row to its authenticated owner

It does not drop the older v0.43 snapshot table or delete its data.

## Existing Supabase configuration

Keep the current Project URL and publishable client key already configured in the app. Never place a Supabase secret/service-role key in the iOS app.

Keep Apple enabled under **Authentication -> Providers -> Apple**. The configured Client IDs should include the Services ID and native bundle ID already set up for My Home Keeper.

## Build

- Marketing version: `0.44`
- Build number: `440`

Run the existing Codemagic TestFlight workflow after committing the v0.44 source and after the SQL update succeeds.

## First structured sync test

### Populated iPhone
1. Update to v0.44.
2. Open **Cloud Sync**.
3. Confirm Supabase = Configured, Apple Account = Signed In, and Cloud Session = Connected.
4. Tap **Upload This Home to Cloud**.
5. Wait for the success confirmation.

### iPad
1. Update to the same v0.44 build.
2. Sign in with the same Apple account.
3. Open **Cloud Sync**.
4. Tap **Check for My Cloud Household**.
5. Tap **Download to This Empty Device** only if the iPad does not already contain home records you need to preserve.

## What syncs in v0.44

Structured records sync in separate chunks: home profile, rooms, vendors, systems, appliances, fixtures, furniture, paint, projects, project items, measurements, tasks, history, detectors, and consumables.

Photos, project images, attachments, and documents stay local in this release. They will use Supabase Storage in a later phase instead of being embedded in JSONB.
