-- 0005_seed_accounts.sql
-- Gudang dan empat akun demo.
--
-- Catatan penting: Supabase Auth tidak menyediakan API publik untuk membuat
-- pengguna tanpa service role key. Baris `auth.users` di bawah ditulis
-- langsung lewat SQL dengan sandi bcrypt. Yang wajib diperhatikan:
--
--   1. Kolom token (confirmation_token, recovery_token, email_change, dst.)
--      HARUS berisi string kosong, bukan NULL. Kalau NULL, GoTrue gagal
--      membaca baris dan login mengembalikan 500 "Database error querying
--      schema".
--   2. email_confirmed_at harus terisi, kalau tidak login ditolak karena
--      email dianggap belum dikonfirmasi.
--   3. Satu baris auth.identities diperlukan untuk provider 'email'.
--
-- Sudah diuji: keempat akun berhasil login lewat /auth/v1/token dengan
-- grant_type=password.

insert into public.warehouses (code, name) values
  ('WH01', 'Gudang Bahan Baku Sidoarjo'),
  ('WH02', 'Gudang Barang Jadi Pasuruan')
on conflict (code) do nothing;

with akun (uid, nik, nama, wh, aktif) as (
  values
    ('11111111-1111-1111-1111-111111111111'::uuid, '210457', 'Budi Santoso',   'WH01', true),
    ('22222222-2222-2222-2222-222222222222'::uuid, '210512', 'Rina Wulandari', 'WH01', true),
    ('33333333-3333-3333-3333-333333333333'::uuid, '198803', 'Agus Prasetyo',  'WH01', false),
    ('44444444-4444-4444-4444-444444444444'::uuid, '220118', 'Siti Rahmawati', 'WH02', true)
)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current, phone_change, phone_change_token,
  reauthentication_token, email_change_confirm_status, is_super_admin,
  is_sso_user, is_anonymous
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  a.uid, 'authenticated', 'authenticated',
  a.nik || '@stockisi.local',
  extensions.crypt('stockisi123', extensions.gen_salt('bf')),
  now(), now(), now(),
  jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
  jsonb_build_object('nik', a.nik, 'name', a.nama),
  '', '', '', '', '', '', '', '', 0, false, false, false
from akun a
on conflict (id) do nothing;

with akun (uid, nik) as (
  values
    ('11111111-1111-1111-1111-111111111111'::uuid, '210457'),
    ('22222222-2222-2222-2222-222222222222'::uuid, '210512'),
    ('33333333-3333-3333-3333-333333333333'::uuid, '198803'),
    ('44444444-4444-4444-4444-444444444444'::uuid, '220118')
)
insert into auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
)
select
  gen_random_uuid(), a.nik || '@stockisi.local', a.uid,
  jsonb_build_object('sub', a.uid::text,
                     'email', a.nik || '@stockisi.local',
                     'email_verified', true),
  'email', now(), now(), now()
from akun a
on conflict do nothing;

insert into public.profiles (id, nik, name, warehouse_code, is_active) values
  ('11111111-1111-1111-1111-111111111111'::uuid, '210457', 'Budi Santoso',   'WH01', true),
  ('22222222-2222-2222-2222-222222222222'::uuid, '210512', 'Rina Wulandari', 'WH01', true),
  ('33333333-3333-3333-3333-333333333333'::uuid, '198803', 'Agus Prasetyo',  'WH01', false),
  ('44444444-4444-4444-4444-444444444444'::uuid, '220118', 'Siti Rahmawati', 'WH02', true)
on conflict (id) do update
  set nik = excluded.nik,
      name = excluded.name,
      warehouse_code = excluded.warehouse_code,
      is_active = excluded.is_active;
