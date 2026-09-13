-- My Home Keeper v0.45 family invitations and household membership
-- Run this entire script in Supabase Dashboard -> SQL Editor.
-- It preserves v0.44 sync data and adds cloud households, members, invitations,
-- invitation acceptance, and member-aware access to structured sync data.

-- ---------------------------------------------------------------------------
-- Existing v0.44 structured sync tables (safe to re-run)
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- v0.45 household sharing tables
-- ---------------------------------------------------------------------------
create table if not exists public.households (
  id uuid primary key,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  home_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text,
  email text,
  role text not null check (role in ('Owner', 'Editor', 'Viewer')),
  joined_at timestamptz not null default now(),
  unique (household_id, user_id)
);

create table if not exists public.household_invitations (
  id uuid primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  email text not null,
  role text not null check (role in ('Editor', 'Viewer')),
  status text not null default 'Pending' check (status in ('Pending', 'Accepted', 'Revoked')),
  invitation_code text not null unique,
  invited_by uuid not null references auth.users(id) on delete cascade,
  accepted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create index if not exists household_members_user_idx
  on public.household_members (user_id, household_id);
create index if not exists household_members_household_idx
  on public.household_members (household_id, joined_at);
create index if not exists household_invitations_household_idx
  on public.household_invitations (household_id, created_at desc);
create index if not exists household_invitations_email_idx
  on public.household_invitations (lower(email), status);

-- ---------------------------------------------------------------------------
-- Security helper functions. SECURITY DEFINER avoids recursive RLS lookups.
-- ---------------------------------------------------------------------------
create or replace function public.is_household_owner(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.households h
    where h.id = p_household_id
      and h.owner_user_id = auth.uid()
  );
$$;

create or replace function public.is_household_member(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members m
    where m.household_id = p_household_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.can_edit_household(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_household_owner(p_household_id)
      or exists (
        select 1
        from public.household_members m
        where m.household_id = p_household_id
          and m.user_id = auth.uid()
          and m.role in ('Owner', 'Editor')
      );
$$;

create or replace function public.is_household_invited(p_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_invitations i
    where i.household_id = p_household_id
      and i.status = 'Pending'
      and lower(i.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function public.is_household_owner(uuid) from public;
revoke all on function public.is_household_member(uuid) from public;
revoke all on function public.can_edit_household(uuid) from public;
revoke all on function public.is_household_invited(uuid) from public;
grant execute on function public.is_household_owner(uuid) to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
grant execute on function public.can_edit_household(uuid) to authenticated;
grant execute on function public.is_household_invited(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS for household/member/invitation tables
-- ---------------------------------------------------------------------------
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invitations enable row level security;

-- households
drop policy if exists "Users can read their households" on public.households;
create policy "Users can read their households"
on public.households for select to authenticated
using (
  owner_user_id = auth.uid()
  or public.is_household_member(id)
  or public.is_household_invited(id)
);

drop policy if exists "Users can create owned households" on public.households;
create policy "Users can create owned households"
on public.households for insert to authenticated
with check (owner_user_id = auth.uid());

drop policy if exists "Owners can update households" on public.households;
create policy "Owners can update households"
on public.households for update to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists "Owners can delete households" on public.households;
create policy "Owners can delete households"
on public.households for delete to authenticated
using (owner_user_id = auth.uid());

-- members
drop policy if exists "Members can read household members" on public.household_members;
create policy "Members can read household members"
on public.household_members for select to authenticated
using (public.is_household_owner(household_id) or public.is_household_member(household_id));

drop policy if exists "Owners can add household members" on public.household_members;
create policy "Owners can add household members"
on public.household_members for insert to authenticated
with check (public.is_household_owner(household_id));

drop policy if exists "Owners can update household members" on public.household_members;
create policy "Owners can update household members"
on public.household_members for update to authenticated
using (public.is_household_owner(household_id))
with check (public.is_household_owner(household_id));

drop policy if exists "Owners can remove household members" on public.household_members;
create policy "Owners can remove household members"
on public.household_members for delete to authenticated
using (public.is_household_owner(household_id) and user_id <> auth.uid());

-- invitations
drop policy if exists "Owners and invitees can read invitations" on public.household_invitations;
create policy "Owners and invitees can read invitations"
on public.household_invitations for select to authenticated
using (
  public.is_household_owner(household_id)
  or accepted_by = auth.uid()
  or (
    status = 'Pending'
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
);

drop policy if exists "Owners can create invitations" on public.household_invitations;
create policy "Owners can create invitations"
on public.household_invitations for insert to authenticated
with check (public.is_household_owner(household_id) and invited_by = auth.uid());

drop policy if exists "Owners can update invitations" on public.household_invitations;
create policy "Owners can update invitations"
on public.household_invitations for update to authenticated
using (public.is_household_owner(household_id))
with check (public.is_household_owner(household_id));

drop policy if exists "Owners can delete invitations" on public.household_invitations;
create policy "Owners can delete invitations"
on public.household_invitations for delete to authenticated
using (public.is_household_owner(household_id));

-- ---------------------------------------------------------------------------
-- Invitation acceptance RPC. The code itself is the capability; this also
-- avoids failures when Sign in with Apple returns a private relay email.
-- ---------------------------------------------------------------------------
create or replace function public.accept_household_invitation(
  p_code text,
  p_display_name text default '',
  p_email text default ''
)
returns table (
  household_id uuid,
  household_name text,
  home_name text,
  role text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invitation public.household_invitations%rowtype;
  v_household public.households%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to accept a household invitation.';
  end if;

  select * into v_invitation
  from public.household_invitations
  where upper(invitation_code) = upper(trim(p_code))
    and status = 'Pending'
  limit 1;

  if not found then
    raise exception 'Invitation not found, already used, or revoked.';
  end if;

  select * into v_household
  from public.households
  where id = v_invitation.household_id;

  if not found then
    raise exception 'The household for this invitation no longer exists.';
  end if;

  insert into public.household_members (
    household_id, user_id, display_name, email, role, joined_at
  ) values (
    v_invitation.household_id,
    auth.uid(),
    nullif(trim(p_display_name), ''),
    nullif(lower(trim(p_email)), ''),
    v_invitation.role,
    now()
  )
  on conflict (household_id, user_id)
  do update set
    display_name = coalesce(excluded.display_name, public.household_members.display_name),
    email = coalesce(excluded.email, public.household_members.email),
    role = excluded.role;

  update public.household_invitations
  set status = 'Accepted',
      accepted_by = auth.uid(),
      accepted_at = now()
  where id = v_invitation.id;

  return query
  select v_household.id, v_household.name, v_household.home_name, v_invitation.role;
end;
$$;

revoke all on function public.accept_household_invitation(text, text, text) from public;
grant execute on function public.accept_household_invitation(text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Replace v0.44 owner-only sync RLS with household-member-aware policies.
-- Owners remain writers. Members can read the structured cloud copy.
-- ---------------------------------------------------------------------------
alter table public.household_sync_manifests enable row level security;
alter table public.household_sync_chunks enable row level security;

-- Remove old and new names so this script is safe to re-run.
drop policy if exists "Owners can read sync manifests" on public.household_sync_manifests;
drop policy if exists "Owners can insert sync manifests" on public.household_sync_manifests;
drop policy if exists "Owners can update sync manifests" on public.household_sync_manifests;
drop policy if exists "Owners can delete sync manifests" on public.household_sync_manifests;
drop policy if exists "Household members can read sync manifests" on public.household_sync_manifests;
drop policy if exists "Owners can insert sync manifests v045" on public.household_sync_manifests;
drop policy if exists "Owners can update sync manifests v045" on public.household_sync_manifests;
drop policy if exists "Owners can delete sync manifests v045" on public.household_sync_manifests;

create policy "Household members can read sync manifests"
on public.household_sync_manifests for select to authenticated
using (owner_user_id = auth.uid() or public.is_household_member(household_id));

create policy "Owners can insert sync manifests v045"
on public.household_sync_manifests for insert to authenticated
with check (owner_user_id = auth.uid() and public.is_household_owner(household_id));

create policy "Owners can update sync manifests v045"
on public.household_sync_manifests for update to authenticated
using (owner_user_id = auth.uid() and public.is_household_owner(household_id))
with check (owner_user_id = auth.uid() and public.is_household_owner(household_id));

create policy "Owners can delete sync manifests v045"
on public.household_sync_manifests for delete to authenticated
using (owner_user_id = auth.uid() and public.is_household_owner(household_id));

drop policy if exists "Owners can read sync chunks" on public.household_sync_chunks;
drop policy if exists "Owners can insert sync chunks" on public.household_sync_chunks;
drop policy if exists "Owners can update sync chunks" on public.household_sync_chunks;
drop policy if exists "Owners can delete sync chunks" on public.household_sync_chunks;
drop policy if exists "Household members can read sync chunks" on public.household_sync_chunks;
drop policy if exists "Owners can insert sync chunks v045" on public.household_sync_chunks;
drop policy if exists "Owners can update sync chunks v045" on public.household_sync_chunks;
drop policy if exists "Owners can delete sync chunks v045" on public.household_sync_chunks;

create policy "Household members can read sync chunks"
on public.household_sync_chunks for select to authenticated
using (owner_user_id = auth.uid() or public.is_household_member(household_id));

create policy "Owners can insert sync chunks v045"
on public.household_sync_chunks for insert to authenticated
with check (owner_user_id = auth.uid() and public.is_household_owner(household_id));

create policy "Owners can update sync chunks v045"
on public.household_sync_chunks for update to authenticated
using (owner_user_id = auth.uid() and public.is_household_owner(household_id))
with check (owner_user_id = auth.uid() and public.is_household_owner(household_id));

create policy "Owners can delete sync chunks v045"
on public.household_sync_chunks for delete to authenticated
using (owner_user_id = auth.uid() and public.is_household_owner(household_id));

grant select, insert, update, delete on public.households to authenticated;
grant select, insert, update, delete on public.household_members to authenticated;
grant select, insert, update, delete on public.household_invitations to authenticated;
grant select, insert, update, delete on public.household_sync_manifests to authenticated;
grant select, insert, update, delete on public.household_sync_chunks to authenticated;
