-- 우리끼리 (Urikkiri) — Supabase schema
-- Run once in the Supabase SQL editor.
-- The server only ever stores ciphertext. Everything a client can touch is
-- guarded by row level security, and the sensitive steps (registration,
-- contact requests, invites) go through security definer functions.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id              uuid primary key references auth.users on delete cascade,
  username        text unique not null check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name    text not null check (char_length(display_name) between 1 and 30),
  friend_code     text unique not null,
  dh_public_key   text not null,   -- X25519, base64
  sign_public_key text not null,   -- Ed25519, base64
  created_at      timestamptz not null default now()
);

create table public.invites (
  code        text primary key,
  created_by  uuid not null references public.profiles on delete cascade,
  used_by     uuid references public.profiles on delete set null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '3 days'
);

create table public.contacts (
  id          bigint generated always as identity primary key,
  requester   uuid not null references public.profiles on delete cascade,
  addressee   uuid not null references public.profiles on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (requester <> addressee)
);
create unique index contacts_pair_idx
  on public.contacts (least(requester, addressee), greatest(requester, addressee));

create table public.messages (
  id                uuid primary key default gen_random_uuid(),
  sender_id         uuid not null default auth.uid() references public.profiles on delete cascade,
  recipient_id      uuid not null references public.profiles on delete cascade,
  body              text not null,  -- XChaCha20-Poly1305 ciphertext, base64
  key_for_recipient text not null,  -- content key wrapped for the recipient
  key_for_sender    text not null,  -- content key wrapped for the sender
  signature         text not null,  -- Ed25519 over the fields above
  created_at        timestamptz not null default now(),
  read_at           timestamptz,
  check (char_length(body) < 200000)
);
create index messages_pair_idx on public.messages (sender_id, recipient_id, created_at desc);
create index messages_recipient_idx on public.messages (recipient_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_member()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid());
$$;

create or replace function public.is_contact(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from contacts
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

create or replace function public.random_code(len int)
returns text language sql volatile as $$
  -- Unambiguous alphabet (no 0/O/1/I/L).
  select string_agg(substr('23456789ABCDEFGHJKMNPQRSTUVWXYZ', 1 + (get_byte(b, i) % 31), 1), '')
  from (select gen_random_bytes(len) as b) s, generate_series(0, len - 1) as i;
$$;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

-- Registration needs a valid, unused invite code. The very first account
-- (the family admin) may register without one.
create or replace function public.register_profile(
  p_invite_code text, p_username text, p_display_name text,
  p_dh_public_key text, p_sign_public_key text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_invite invites%rowtype;
  v_first boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'already registered';
  end if;

  perform pg_advisory_xact_lock(4242);
  v_first := not exists (select 1 from profiles);

  if not v_first then
    select * into v_invite from invites
      where code = upper(trim(p_invite_code)) and used_by is null and expires_at > now()
      for update;
    if not found then raise exception 'invalid invite code'; end if;
  end if;

  insert into profiles (id, username, display_name, friend_code, dh_public_key, sign_public_key)
  values (auth.uid(), lower(p_username), p_display_name, random_code(10), p_dh_public_key, p_sign_public_key);

  if not v_first then
    update invites set used_by = auth.uid() where code = v_invite.code;
    -- The inviter vouched for this person and the invitee accepted the
    -- invite, so they start out as mutual contacts.
    insert into contacts (requester, addressee, status)
    values (v_invite.created_by, auth.uid(), 'accepted');
  end if;
end $$;

create or replace function public.create_invite()
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not is_member() then raise exception 'not a member'; end if;
  if (select count(*) from invites where created_by = auth.uid() and used_by is null and expires_at > now()) >= 5 then
    raise exception 'too many open invites';
  end if;
  v_code := random_code(8);
  insert into invites (code, created_by) values (v_code, auth.uid());
  return v_code;
end $$;

-- Ask someone to become a contact. You need their private friend code, which
-- they share with you in person; there is no directory or search.
create or replace function public.send_contact_request(p_friend_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_target uuid;
begin
  if not is_member() then raise exception 'not a member'; end if;
  select id into v_target from profiles where friend_code = upper(trim(p_friend_code));
  if v_target is null or v_target = auth.uid() then raise exception 'invalid friend code'; end if;
  insert into contacts (requester, addressee) values (auth.uid(), v_target)
  on conflict ((least(requester, addressee)), (greatest(requester, addressee))) do update
    set status = case when contacts.status = 'rejected' then 'pending' else contacts.status end,
        requester = case when contacts.status = 'rejected' then auth.uid() else contacts.requester end,
        addressee = case when contacts.status = 'rejected' then v_target else contacts.addressee end,
        updated_at = now();
end $$;

create or replace function public.respond_contact_request(p_id bigint, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update contacts
     set status = case when p_accept then 'accepted' else 'rejected' end, updated_at = now()
   where id = p_id and addressee = auth.uid() and status = 'pending';
  if not found then raise exception 'request not found'; end if;
end $$;

create or replace function public.remove_contact(p_other uuid)
returns void language sql security definer set search_path = public as $$
  delete from contacts
   where (requester = auth.uid() and addressee = p_other)
      or (requester = p_other and addressee = auth.uid());
$$;

create or replace function public.mark_read(p_other uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now()
   where recipient_id = auth.uid() and sender_id = p_other and read_at is null;
$$;

-- Lock down the helpers so only signed-in users can call the RPCs.
revoke all on function public.register_profile, public.create_invite, public.send_contact_request,
  public.respond_contact_request, public.remove_contact, public.mark_read, public.random_code
  from public, anon;
grant execute on function public.register_profile, public.create_invite, public.send_contact_request,
  public.respond_contact_request, public.remove_contact, public.mark_read
  to authenticated;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.invites  enable row level security;
alter table public.contacts enable row level security;
alter table public.messages enable row level security;

-- You see yourself, and people you share a contact row with (any status, so
-- a pending request shows who is asking).
create policy profiles_select on public.profiles for select to authenticated using (
  id = auth.uid() or exists (
    select 1 from contacts c
    where (c.requester = auth.uid() and c.addressee = profiles.id)
       or (c.addressee = auth.uid() and c.requester = profiles.id)));

create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy invites_select on public.invites for select to authenticated
  using (created_by = auth.uid());

create policy contacts_select on public.contacts for select to authenticated
  using (requester = auth.uid() or addressee = auth.uid());

create policy messages_select on public.messages for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_contact(auth.uid(), recipient_id));

create policy messages_delete on public.messages for delete to authenticated
  using (sender_id = auth.uid());

-- Users may only change a few profile columns themselves.
revoke update on public.profiles from authenticated;
grant update (display_name, dh_public_key, sign_public_key) on public.profiles to authenticated;
revoke insert, update, delete on public.invites, public.contacts from authenticated;
revoke update on public.messages from authenticated;
revoke all on public.profiles, public.invites, public.contacts, public.messages from anon;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.messages, public.contacts;
