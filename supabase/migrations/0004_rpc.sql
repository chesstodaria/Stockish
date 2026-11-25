-- 0004_rpc.sql
-- Seluruh penulisan data lewat fungsi SECURITY DEFINER. Tabel publik hanya
-- punya policy SELECT, jadi klien tidak bisa menulis langsung.
--
-- Pemetaan exception ke aplikasi:
--   NOT_SIGNED_IN      -> sesi berakhir
--   NOT_FOUND          -> dokumen bukan milik gudang operator
--   ALREADY_SUBMITTED  -> dokumen sudah diselesaikan operator lain
--   DOCUMENT_CHANGED   -> versi dokumen berubah (sisa barang berubah)
--   RULES_NOT_MET: ... -> aturan bisnis dilanggar, pesan siap tampil

create sequence if not exists public.transaction_number_seq;

-- ------------------------------------------------------------------ klaim
create or replace function public.claim_document(p_document_number text)
returns table (granted boolean, holder_nik text, holder_name text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles := private.current_profile();
  v_doc public.reference_documents;
  v_claim public.document_claims;
  v_expires timestamptz;
begin
  if v_profile.id is null then raise exception 'NOT_SIGNED_IN'; end if;

  select * into v_doc from public.reference_documents where number = p_document_number;
  if v_doc.number is null or v_doc.warehouse_code <> v_profile.warehouse_code then
    raise exception 'NOT_FOUND';
  end if;

  select * into v_claim from public.document_claims
   where document_number = p_document_number for update;

  if v_claim.document_number is not null
     and v_claim.expires_at > now()
     and v_claim.claimed_by <> v_profile.id then
    return query
      select false, p.nik, p.name, v_claim.expires_at
      from public.profiles p where p.id = v_claim.claimed_by;
    return;
  end if;

  v_expires := now() + interval '5 minutes';

  insert into public.document_claims (document_number, claimed_by, claimed_at, expires_at)
  values (p_document_number, v_profile.id, now(), v_expires)
  on conflict (document_number) do update
    set claimed_by = excluded.claimed_by,
        claimed_at = public.document_claims.claimed_at,
        expires_at = excluded.expires_at;

  if v_claim.document_number is null then
    insert into public.audit_events
      (actor_id, actor_nik, warehouse_code, action, entity, entity_id, summary)
    values (v_profile.id, v_profile.nik, v_profile.warehouse_code,
            'claim', 'reference_document', p_document_number,
            'Membuka dan mengunci ' || p_document_number);
  end if;

  return query select true, v_profile.nik, v_profile.name, v_expires;
end $$;

create or replace function public.release_document(p_document_number text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles := private.current_profile();
  v_deleted integer;
begin
  if v_profile.id is null then return; end if;

  delete from public.document_claims
   where document_number = p_document_number and claimed_by = v_profile.id;
  get diagnostics v_deleted = row_count;

  if v_deleted > 0 then
    insert into public.audit_events
      (actor_id, actor_nik, warehouse_code, action, entity, entity_id, summary)
    values (v_profile.id, v_profile.nik, v_profile.warehouse_code,
            'release', 'reference_document', p_document_number,
            'Melepas kunci ' || p_document_number);
  end if;
end $$;

-- ------------------------------------------------------------------- sesi
create or replace function public.start_session(p_device_id text, p_force boolean default false)
returns table (granted boolean, other_device_id text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles := private.current_profile();
  v_row public.active_sessions;
begin
  if v_profile.id is null then raise exception 'NOT_SIGNED_IN'; end if;

  select * into v_row from public.active_sessions
   where profile_id = v_profile.id for update;

  if v_row.profile_id is not null
     and v_row.device_id <> p_device_id
     and not p_force then
    return query select false, v_row.device_id;
    return;
  end if;

  insert into public.active_sessions (profile_id, device_id)
  values (v_profile.id, p_device_id)
  on conflict (profile_id) do update
    set device_id = excluded.device_id, last_seen_at = now();

  if v_row.profile_id is not null and v_row.device_id <> p_device_id then
    insert into public.audit_events
      (actor_id, actor_nik, warehouse_code, action, entity, summary)
    values (v_profile.id, v_profile.nik, v_profile.warehouse_code,
            'force_session', 'session', 'Sesi dipindahkan ke perangkat lain');
  end if;

  return query select true, null::text;
end $$;

-- ----------------------------------------------------------------- submit
create or replace function public.submit_transaction(
  p_document_number text,
  p_based_on_version integer,
  p_lines jsonb,
  p_vendor_delivery_no text,
  p_mode text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.profiles := private.current_profile();
  v_doc public.reference_documents;
  v_row record;
  v_input jsonb;
  v_qty integer;
  v_unavailable boolean;
  v_remaining integer;
  v_all_fulfilled boolean;
  v_closes boolean;
  v_number text;
  v_seq bigint;
  v_count integer := 0;
  v_stock integer;
begin
  if v_profile.id is null then raise exception 'NOT_SIGNED_IN'; end if;

  select * into v_doc from public.reference_documents
   where number = p_document_number for update;
  if v_doc.number is null or v_doc.warehouse_code <> v_profile.warehouse_code then
    raise exception 'NOT_FOUND';
  end if;
  if v_doc.status = 'SUBMITTED' then raise exception 'ALREADY_SUBMITTED'; end if;
  if v_doc.version <> p_based_on_version then raise exception 'DOCUMENT_CHANGED'; end if;
  if v_doc.type = 'RCV' and coalesce(btrim(p_vendor_delivery_no), '') = '' then
    raise exception 'RULES_NOT_MET: nomor surat jalan vendor wajib diisi';
  end if;

  -- Validasi seluruh baris sebelum ada yang diubah.
  for v_row in
    select rdi.item_code, rdi.ordered_quantity, rdi.processed_quantity
      from public.reference_document_items rdi
     where rdi.document_number = p_document_number
  loop
    v_remaining := v_row.ordered_quantity - v_row.processed_quantity;
    continue when v_remaining <= 0;

    select l into v_input from jsonb_array_elements(p_lines) l
     where l->>'item_code' = v_row.item_code limit 1;

    if v_input is null then
      raise exception 'RULES_NOT_MET: item % belum diperiksa', v_row.item_code;
    end if;

    v_unavailable := coalesce((v_input->>'marked_unavailable')::boolean, false);
    v_qty := coalesce((v_input->>'quantity')::integer, 0);

    if v_unavailable then
      v_qty := 0;
    elsif v_qty <= 0 then
      raise exception 'RULES_NOT_MET: jumlah item % harus lebih dari nol', v_row.item_code;
    elsif v_qty > v_remaining then
      raise exception 'RULES_NOT_MET: jumlah item % melebihi sisa %', v_row.item_code, v_remaining;
    end if;

    if v_doc.type = 'INT' and v_qty > 0 then
      select coalesce(quantity, 0) into v_stock from public.stocks
       where item_code = v_row.item_code and warehouse_code = v_doc.warehouse_code;
      if coalesce(v_stock, 0) < v_qty then
        raise exception 'RULES_NOT_MET: stok item % tidak cukup', v_row.item_code;
      end if;
    end if;
  end loop;

  v_seq := nextval('public.transaction_number_seq');
  v_number := 'TRX-' || v_doc.type::text || '-' || to_char(now(), 'YYMMDD')
              || '-' || lpad(v_seq::text, 4, '0');

  insert into public.transactions
    (number, document_number, type, warehouse_code, operator_id,
     vendor_delivery_no, closed_document)
  values (v_number, v_doc.number, v_doc.type, v_doc.warehouse_code, v_profile.id,
          case when v_doc.type = 'RCV' then btrim(p_vendor_delivery_no) else null end,
          false);

  for v_row in
    select rdi.item_code, rdi.ordered_quantity, rdi.processed_quantity,
           i.name, i.uom, i.rack_number
      from public.reference_document_items rdi
      join public.items i on i.code = rdi.item_code
     where rdi.document_number = p_document_number
  loop
    v_remaining := v_row.ordered_quantity - v_row.processed_quantity;
    continue when v_remaining <= 0;

    select l into v_input from jsonb_array_elements(p_lines) l
     where l->>'item_code' = v_row.item_code limit 1;

    v_unavailable := coalesce((v_input->>'marked_unavailable')::boolean, false);
    v_qty := case when v_unavailable then 0
                  else coalesce((v_input->>'quantity')::integer, 0) end;

    insert into public.transaction_items
      (transaction_number, item_code, item_name, uom, rack_number, quantity, marked_unavailable)
    values (v_number, v_row.item_code, v_row.name, v_row.uom, v_row.rack_number,
            v_qty, v_unavailable);

    continue when v_qty = 0;

    update public.reference_document_items
       set processed_quantity = processed_quantity + v_qty
     where document_number = p_document_number and item_code = v_row.item_code;

    update public.stocks
       set quantity = quantity + case when v_doc.type = 'RCV' then v_qty else -v_qty end
     where item_code = v_row.item_code and warehouse_code = v_doc.warehouse_code;

    v_count := v_count + 1;
  end loop;

  update public.reference_document_items
     set status = case
       when processed_quantity >= ordered_quantity then 'COMPLETE'::public.item_status
       when processed_quantity > 0 then 'PARTIAL'::public.item_status
       else 'PENDING'::public.item_status end
   where document_number = p_document_number;

  select bool_and(processed_quantity >= ordered_quantity) into v_all_fulfilled
    from public.reference_document_items where document_number = p_document_number;

  v_closes := (p_mode = 'close') or coalesce(v_all_fulfilled, false);

  update public.transactions set closed_document = v_closes where number = v_number;
  update public.reference_documents
     set status = case when v_closes then 'SUBMITTED'::public.document_status
                       else status end,
         version = version + 1
   where number = p_document_number;

  delete from public.document_claims where document_number = p_document_number;

  insert into public.audit_events
    (actor_id, actor_nik, warehouse_code, action, entity, entity_id, summary)
  values (v_profile.id, v_profile.nik, v_profile.warehouse_code,
          'submit', 'transaction', v_number,
          'Submit ' || v_doc.type::text || ' ' || v_doc.number || ': '
          || v_count || ' item, '
          || case when v_closes then 'dokumen ditutup' else 'dokumen tetap terbuka' end);

  return v_number;
end $$;

revoke all on function public.claim_document(text) from public, anon;
revoke all on function public.release_document(text) from public, anon;
revoke all on function public.start_session(text, boolean) from public, anon;
revoke all on function public.submit_transaction(text, integer, jsonb, text, text)
  from public, anon;

grant execute on function public.claim_document(text) to authenticated;
grant execute on function public.release_document(text) to authenticated;
grant execute on function public.start_session(text, boolean) to authenticated;
grant execute on function public.submit_transaction(text, integer, jsonb, text, text)
  to authenticated;
