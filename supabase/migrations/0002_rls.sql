-- 0002_rls.sql
-- Row Level Security: deny by default, hanya SELECT yang diizinkan lewat
-- policy. Semua penulisan lewat RPC SECURITY DEFINER (lihat 0004).

alter table public.warehouses               enable row level security;
alter table public.profiles                 enable row level security;
alter table public.items                    enable row level security;
alter table public.stocks                   enable row level security;
alter table public.reference_documents      enable row level security;
alter table public.reference_document_items enable row level security;
alter table public.transactions             enable row level security;
alter table public.transaction_items        enable row level security;
alter table public.audit_events             enable row level security;
alter table public.document_claims          enable row level security;
alter table public.active_sessions          enable row level security;

-- Fungsi bantu versi pertama (dipindah ke schema private pada 0003).
create or replace function public.current_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public
as $$ select * from public.profiles where id = auth.uid() $$;

create or replace function public.current_warehouse()
returns text
language sql
stable
security definer
set search_path = public
as $$ select warehouse_code from public.profiles where id = auth.uid() $$;

create policy warehouses_read on public.warehouses
  for select to authenticated using (code = public.current_warehouse());

create policy profiles_read_own on public.profiles
  for select to authenticated using (id = auth.uid());

create policy items_read on public.items
  for select to authenticated
  using (warehouse_code = public.current_warehouse());

create policy stocks_read on public.stocks
  for select to authenticated
  using (warehouse_code = public.current_warehouse());

create policy docs_read on public.reference_documents
  for select to authenticated
  using (warehouse_code = public.current_warehouse());

create policy doc_items_read on public.reference_document_items
  for select to authenticated
  using (exists (
    select 1 from public.reference_documents d
    where d.number = reference_document_items.document_number
      and d.warehouse_code = public.current_warehouse()
  ));

create policy trx_read on public.transactions
  for select to authenticated
  using (warehouse_code = public.current_warehouse());

create policy trx_items_read on public.transaction_items
  for select to authenticated
  using (exists (
    select 1 from public.transactions t
    where t.number = transaction_items.transaction_number
      and t.warehouse_code = public.current_warehouse()
  ));

create policy audit_read on public.audit_events
  for select to authenticated
  using (warehouse_code = public.current_warehouse());

create policy claims_read on public.document_claims
  for select to authenticated
  using (exists (
    select 1 from public.reference_documents d
    where d.number = document_claims.document_number
      and d.warehouse_code = public.current_warehouse()
  ));

create policy sessions_read_own on public.active_sessions
  for select to authenticated using (profile_id = auth.uid());

grant select on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;
revoke insert, update, delete on all tables in schema public from authenticated;
