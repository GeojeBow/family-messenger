-- 우리끼리 (Urikkiri) — Supabase schema, fixed-family edition
-- Run once in the Supabase SQL editor. Safe to re-run: it drops and rebuilds
-- the app's tables (all messages are deleted).
--
-- There is no sign-up. The admin creates the accounts in the Supabase
-- dashboard (Authentication -> Users -> Add user) as <username>@users.urikkiri.app,
-- and a trigger turns the allowed usernames below into family members. Every
-- member can talk to every other member; nobody else can see anything.
-- The server only ever stores ciphertext.

-- ---------------------------------------------------------------------------
-- Reset (also removes objects from the earlier invite-based version)
-- ---------------------------------------------------------------------------
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop table if exists public.messages cascade;
drop table if exists public.contacts cascade;
drop table if exists public.invites cascade;
drop table if exists public.profiles cascade;
drop function if exists public.register_profile(text, text, text, text, text);
drop function if exists public.create_invite();
drop function if exists public.send_contact_request(text);
drop function if exists public.respond_contact_request(bigint, boolean);
drop function if exists public.remove_contact(uuid);
drop function if exists public.mark_read(uuid);
drop function if exists public.is_contact(uuid, uuid);
drop function if exists public.is_member();
drop function if exists public.random_code(int);

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id              uuid primary key references auth.users on delete cascade,
  username        text unique not null,
  display_name    text not null check (char_length(display_name) between 1 and 30),
  dh_public_key   text,   -- X25519, base64; set by the app on first sign-in
  sign_public_key text,   -- Ed25519, base64
  created_at      timestamptz not null default now()
);

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
  check (char_length(body) < 200000),
  check (sender_id <> recipient_id)
);
create index messages_pair_idx on public.messages (sender_id, recipient_id, created_at desc);
create index messages_recipient_idx on public.messages (recipient_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Helpers / RPCs
-- ---------------------------------------------------------------------------

create or replace function public.is_member()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid());
$$;

create or replace function public.mark_read(p_other uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now()
   where recipient_id = auth.uid() and sender_id = p_other and read_at is null;
$$;

revoke all on function public.is_member, public.mark_read from public, anon;
grant execute on function public.is_member, public.mark_read to authenticated;

-- Only these usernames can ever become family members.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_username text := split_part(new.email, '@', 1);
  v_name text;
begin
  if split_part(new.email, '@', 2) <> 'users.urikkiri.app' then return new; end if;
  v_name := case v_username
    when 'harry' then '해리'
    when 'family2' then '가족2'
    when 'family3' then '가족3'
    when 'family4' then '가족4'
  end;
  if v_name is not null then
    insert into profiles (id, username, display_name) values (new.id, v_username, v_name)
    on conflict do nothing;
  end if;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- Accounts that already exist (e.g. created before this script ran).
insert into public.profiles (id, username, display_name)
select distinct on (split_part(u.email, '@', 1)) u.id, split_part(u.email, '@', 1),
  case split_part(u.email, '@', 1)
    when 'harry' then '해리' when 'family2' then '가족2'
    when 'family3' then '가족3' when 'family4' then '가족4' end
from auth.users u
where split_part(u.email, '@', 2) = 'users.urikkiri.app'
  and split_part(u.email, '@', 1) in ('harry', 'family2', 'family3', 'family4')
order by split_part(u.email, '@', 1), u.created_at desc
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.messages enable row level security;

create policy profiles_select on public.profiles for select to authenticated
  using (public.is_member());

create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy messages_select on public.messages for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.is_member()
              and exists (select 1 from public.profiles p where p.id = recipient_id));

create policy messages_delete on public.messages for delete to authenticated
  using (sender_id = auth.uid());

-- Members may only change their name and keys.
revoke insert, update, delete on public.profiles from authenticated;
grant update (display_name, dh_public_key, sign_public_key) on public.profiles to authenticated;
revoke update on public.messages from authenticated;
revoke all on public.profiles, public.messages from anon;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.messages, public.profiles;

select 'OK: 우리끼리 설정 완료' as result;
