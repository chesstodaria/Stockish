-- 0003_private_helpers.sql
-- Fungsi bantu RLS dipindah ke schema `private` supaya tidak ikut terbuka
-- sebagai endpoint RPC publik (`/rest/v1/rpc/...`). PostgREST hanya
-- mengekspos schema public, jadi `authenticated` bisa memakainya di dalam
-- policy tanpa bisa memanggilnya langsung dari klien.
--
-- Ini menutup dua temuan advisor: anon_security_definer_function_executable
-- dan authenticated_security_definer_function_executable.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.current_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public
as $$ select * from public.profiles where id = auth.uid() $$;

create or replace function private.current_warehouse()
returns text
language sql
stable
security definer
set search_path = public
as $$ select warehouse_code from public.profiles where id = auth.uid() $$;

revoke all on function private.current_profile() from public;
revoke all on function private.current_warehouse() from public;
grant execute on function private.current_profile() to authenticated;
grant execute on function private.current_warehouse() to authenticated;

drop policy if exists warehouses_read on public.warehouses;
create policy warehouses_read on public.warehouses
  for select to authenticated using (code = private.current_warehouse());

drop policy if exists items_read on public.items;
create policy items_read on public.items
  for select to authenticated
  using (warehouse_code = private.current_warehouse());

drop policy if exists stocks_read on public.stocks;
create policy stocks_read on public.stocks
  for select to authenticated
  using (warehouse_code = private.current_warehouse());

drop policy if exists docs_read on public.reference_documents;
create policy docs_read on public.reference_documents
  for select to authenticated
  using (warehouse_code = private.current_warehouse());

drop policy if exists doc_items_read on public.reference_document_items;
create policy doc_items_read on public.reference_document_items
  for select to authenticated
  using (exists (
    select 1 from public.reference_documents d
    where d.number = reference_document_items.document_number
      and d.warehouse_code = private.current_warehouse()
  ));

drop policy if exists trx_read on public.transactions;
create policy trx_read on public.transactions
  for select to authenticated
  using (warehouse_code = private.current_warehouse());

drop policy if exists trx_items_read on public.transaction_items;
create policy trx_items_read on public.transaction_items
  for select to authenticated
  using (exists (
    select 1 from public.transactions t
    where t.number = transaction_items.transaction_number
      and t.warehouse_code = private.current_warehouse()
  ));

drop policy if exists audit_read on public.audit_events;
create policy audit_read on public.audit_events
  for select to authenticated
  using (warehouse_code = private.current_warehouse());

drop policy if exists claims_read on public.document_claims;
create policy claims_read on public.document_claims
  for select to authenticated
  using (exists (
    select 1 from public.reference_documents d
    where d.number = document_claims.document_number
      and d.warehouse_code = private.current_warehouse()
  ));

drop function if exists public.current_profile();
drop function if exists public.current_warehouse();
