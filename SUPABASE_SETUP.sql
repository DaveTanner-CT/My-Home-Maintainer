-- My Home Keeper v0.43
-- Run this in Supabase Dashboard -> SQL Editor for the project used by the app.

create table if not exists public.household_snapshots (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  household_name text not null,
  home_name text,
  archive jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.household_snapshots enable row level security;

drop policy if exists "Owners can read household snapshots" on public.household_snapshots;
create policy "Owners can read household snapshots"
on public.household_snapshots
for select
to authenticated
using (auth.uid() = owner_user_id);

drop policy if exists "Owners can insert household snapshots" on public.household_snapshots;
create policy "Owners can insert household snapshots"
on public.household_snapshots
for insert
to authenticated
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can update household snapshots" on public.household_snapshots;
create policy "Owners can update household snapshots"
on public.household_snapshots
for update
to authenticated
using (auth.uid() = owner_user_id)
with check (auth.uid() = owner_user_id);

drop policy if exists "Owners can delete household snapshots" on public.household_snapshots;
create policy "Owners can delete household snapshots"
on public.household_snapshots
for delete
to authenticated
using (auth.uid() = owner_user_id);

grant select, insert, update, delete on public.household_snapshots to authenticated;
