-- 우리끼리 — create the family accounts. Run AFTER schema.sql.
-- Replace the passwords below before running, and keep the real file private
-- (never commit it). Re-running deletes and recreates these accounts.

do $$
declare
  acct record;
  uid uuid;
begin
  -- Remove every earlier account of this app (including half-finished sign-ups).
  delete from auth.users where email like '%@users.urikkiri.app';

  for acct in
    select * from (values
      ('harry',   '해리',  'CHANGE-ME-1'),
      ('family2', '가족2', 'CHANGE-ME-2'),
      ('family3', '가족3', 'CHANGE-ME-3'),
      ('family4', '가족4', 'CHANGE-ME-4')
    ) as t(username, display_name, password)
  loop
    uid := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token)
    values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      acct.username || '@users.urikkiri.app',
      extensions.crypt(acct.password, extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', '', '', '', '', '');
    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', acct.username || '@users.urikkiri.app',
                         'email_verified', true),
      'email', now(), now(), now());
    insert into public.profiles (id, username, display_name)
    values (uid, acct.username, acct.display_name);
  end loop;
end $$;

select username, display_name from public.profiles order by username;
