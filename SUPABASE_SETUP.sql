-- My Home Keeper v0.44 structured cloud sync
-- Run this entire script in Supabase Dashboard -> SQL Editor.
-- This keeps the older household_snapshots table intact for compatibility, and
-- adds the new structured manifest/chunk tables used by v0.44.

create table if not exists public.household_sync_manifests (
  household_id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  household_name text not null,
  home_name text,
  revision uuid not null,
  format_version integer not null default 1,
  app_version text not null,
  package_type text not null,
  exported_at timestamptz not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.household_sync_chunks (
  household_id uuid not null,
  revision uuid not null,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  chunk_type text not null,
  payload jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (household_id, revision, chunk_type)
);

create index if not exists household_sync_manifests_owner_updated_idx
  on public.household_sync_manifests (owner_user_id, updated_at desc);

create index if not exists household_sync_chunks_household_revision_idx
  on public.household_sync_chunks (household_id, revision);

alter table public.household_sync_manifests enable row level security;
alter table public.household_sync_chunks enable row level security;

drop policy if exists "Owners can read sync manifests" on public.household_sync_manifests;
create policy "Owners can read sync manifests"
on public.household_sync_manifests
for select
to authenticated
using (auth.uid() = owner_user_id);

drop policy if exists "Owners can insert sync manifests" on public.household_sync_manifests;
create policy "Owners can insert sync manifests"
on public.household_sync_manifests
for insert
to authenticated
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can update sync manifests" on public.household_sync_manifests;
create policy "Owners can update sync manifests"
on public.household_sync_manifests
for update
to authenticated
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can delete sync manifests" on public.household_sync_manifests;
create policy "Owners can delete sync manifests"
on public.household_sync_manifests
for delete
to authenticated
using (auth.uid() = owner_user_id);

drop policy if exists "Owners can read sync chunks" on public.household_sync_chunks;
create policy "Owners can read sync chunks"
on public.household_sync_chunks
for select
to authenticated
using (auth.uid() = owner_user_id);

drop policy if exists "Owners can insert sync chunks" on public.household_sync_chunks;
create policy "Owners can insert sync chunks"
on public.household_sync_chunks
for insert
to authenticated
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can update sync chunks" on public.household_sync_chunks;
create policy "Owners can update sync chunks"
on public.household_sync_chunks
for update
to authenticated
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can delete sync chunks" on public.household_sync_chunks;
create policy "Owners can delete sync chunks"
on public.household_sync_chunks
for delete
to authenticated
using (auth.uid() = owner_user_id);

grant select, insert, update, delete on public.household_sync_manifests to authenticated;
grant select, insert, update, delete on public.household_sync_chunks to authenticated;
