-- 0001_schema.sql
-- Skema Stockisi: delapan tabel rancangan laporan bagian 2.7, ditambah tiga
-- tabel untuk fitur operasional (audit, klaim dokumen, sesi perangkat).
--
-- Dijalankan pada project Supabase `btbwmdzffjquhfgvuesb` (region Singapore).

create extension if not exists pgcrypto with schema extensions;

do $$ begin
  create type document_type as enum ('RCV', 'INT');
exception when duplicate_object then null; end $$;

do $$ begin
  create type document_status as enum ('OPEN', 'SUBMITTED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type item_status as enum ('PENDING', 'PARTIAL', 'COMPLETE', 'FULFILLED');
exception when duplicate_object then null; end $$;

create table if not exists warehouses (
  code text primary key,
  name text not null
);

-- profiles.id disamakan dengan auth.users.id supaya Row Level Security bisa
-- memakai auth.uid(). NIK tetap identitas bisnis yang dipakai di seluruh app.
create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nik text not null unique,
  name text not null,
  warehouse_code text not null references warehouses (code),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists items (
  code text primary key,
  name text not null,
  uom text not null,
  warehouse_code text not null references warehouses (code),
  rack_number text not null
);

create table if not exists stocks (
  item_code text not null references items (code) on delete cascade,
  warehouse_code text not null references warehouses (code),
  quantity integer not null default 0 check (quantity >= 0),
  primary key (item_code, warehouse_code)
);

create table if not exists reference_documents (
  number text primary key,
  type document_type not null,
  warehouse_code text not null references warehouses (code),
  counterparty text not null,
  document_date date not null,
  status document_status not null default 'OPEN',
  version integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists reference_document_items (
  document_number text not null
    references reference_documents (number) on delete cascade,
  item_code text not null references items (code),
  ordered_quantity integer not null check (ordered_quantity > 0),
  processed_quantity integer not null default 0 check (processed_quantity >= 0),
  status item_status not null default 'PENDING',
  primary key (document_number, item_code),
  check (processed_quantity <= ordered_quantity)
);

create table if not exists transactions (
  number text primary key,
  document_number text not null references reference_documents (number),
  type document_type not null,
  warehouse_code text not null references warehouses (code),
  operator_id uuid not null references profiles (id),
  submitted_at timestamptz not null default now(),
  vendor_delivery_no text,
  closed_document boolean not null
);

create table if not exists transaction_items (
  transaction_number text not null
    references transactions (number) on delete cascade,
  item_code text not null references items (code),
  item_name text not null,
  uom text not null,
  rack_number text not null,
  quantity integer not null check (quantity >= 0),
  marked_unavailable boolean not null default false,
  primary key (transaction_number, item_code)
);

-- Ditulis hanya oleh trigger dan RPC. Tidak ada policy INSERT untuk klien.
create table if not exists audit_events (
  id bigserial primary key,
  at timestamptz not null default now(),
  actor_id uuid references profiles (id),
  actor_nik text not null,
  warehouse_code text not null,
  action text not null,
  entity text not null,
  entity_id text,
  summary text not null,
  metadata jsonb
);

create table if not exists document_claims (
  document_number text primary key
    references reference_documents (number) on delete cascade,
  claimed_by uuid not null references profiles (id),
  claimed_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create table if not exists active_sessions (
  profile_id uuid primary key references profiles (id) on delete cascade,
  device_id text not null,
  started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists items_warehouse_idx on items (warehouse_code);
create index if not exists docs_lookup_idx
  on reference_documents (warehouse_code, type, status, document_date desc);
create index if not exists trx_lookup_idx
  on transactions (warehouse_code, submitted_at desc);
create index if not exists audit_lookup_idx
  on audit_events (warehouse_code, at desc);
create index if not exists claims_expiry_idx on document_claims (expires_at);
