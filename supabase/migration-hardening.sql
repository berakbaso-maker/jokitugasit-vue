-- =============================================================
-- jokitugasit.my.id — Hardening
-- Jalankan SETELAH migration-project-details.sql.
--
--   1. Kode referral baru: 8 karakter acak (bukan REF-NAMA+2 digit).
--      Kode lama tetap berlaku; rotasi hanya lewat aksi eksplisit.
--   2. Bucket `attachments` dibuat privat + batas ukuran/tipe.
--      Frontend menyimpan path dan meminta signed URL saat dibuka.
--   3. import_prospects_batch bisa menerima beberapa chunk dengan
--      batch id yang sama (akumulasi, bukan baris baru).
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Generator kode referral
-- ---------------------------------------------------------------
create or replace function public.generate_referral_code()
returns text
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code     text;
  v_i        int;
  v_attempt  int;
begin
  for v_attempt in 1..8 loop
    v_code := 'REF-';
    for v_i in 1..8 loop
      v_code := v_code || substr(v_alphabet, floor(random() * length(v_alphabet))::int + 1, 1);
    end loop;

    if not exists (select 1 from public.partners where referral_code = v_code) then
      return v_code;
    end if;
  end loop;

  raise exception 'GAGAL_MEMBUAT_KODE' using errcode = '23505';
end;
$$;

revoke all on function public.generate_referral_code() from public;
grant execute on function public.generate_referral_code() to authenticated;

-- Rotasi kode: hanya engineer, dan hanya kalau diminta eksplisit.
create or replace function public.rotate_partner_code(p_partner_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if not exists (select 1 from public.partners where id = p_partner_id) then
    raise exception 'PARTNER_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  v_code := public.generate_referral_code();
  update public.partners set referral_code = v_code where id = p_partner_id;
  return v_code;
end;
$$;

revoke all on function public.rotate_partner_code(uuid) from public;
grant execute on function public.rotate_partner_code(uuid) to authenticated;

-- ---------------------------------------------------------------
-- 2. Storage: bucket privat + batas file
--    Aman dijalankan di database tanpa schema storage (test lokal).
-- ---------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_tables where schemaname = 'storage' and tablename = 'buckets') then
    update storage.buckets
       set public = false,
           file_size_limit = 10485760, -- 10 MB
           allowed_mime_types = array[
             'application/pdf',
             'application/zip',
             'application/x-zip-compressed',
             'image/png',
             'image/jpeg',
             'image/webp',
             'text/plain'
           ]::text[]
     where id = 'attachments';
  end if;
end $$;

do $$
begin
  if exists (select 1 from pg_tables where schemaname = 'storage' and tablename = 'objects') then
    execute 'drop policy if exists "attachments_public_read" on storage.objects';
    execute 'drop policy if exists "attachments_anon_upload" on storage.objects';
    execute 'drop policy if exists "attachments_engineer_read" on storage.objects';

    execute $sql$create policy "attachments_anon_upload" on storage.objects
      for insert to anon
      with check (bucket_id = 'attachments')$sql$;

    execute $sql$create policy "attachments_engineer_read" on storage.objects
      for select to authenticated
      using (bucket_id = 'attachments' and public.is_engineer())$sql$;
  end if;
end $$;

-- ---------------------------------------------------------------
-- 4. Pendaftaran partner publik (menggantikan insert langsung yang
--    selalu ditolak RLS). Kode dibuat di server.
-- ---------------------------------------------------------------
create or replace function public.register_partner(
  p_full_name   text,
  p_whatsapp    text,
  p_campus      text default null,
  p_ewallet_info text default null
)
returns table (partner_id uuid, referral_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name  text := btrim(coalesce(p_full_name, ''));
  v_phone text := public.normalize_phone(p_whatsapp);
  v_code  text;
  v_id    uuid;
begin
  if char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'NAMA_TIDAK_VALID' using errcode = '22023';
  end if;
  if char_length(v_phone) < 9 or char_length(v_phone) > 15 then
    raise exception 'WHATSAPP_TIDAK_VALID' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.partners where public.normalize_phone(whatsapp) = v_phone
  ) then
    raise exception 'WHATSAPP_SUDAH_TERDAFTAR' using errcode = '23505';
  end if;

  v_code := public.generate_referral_code();

  insert into public.partners (full_name, whatsapp, campus, ewallet_info, referral_code, status)
  values (
    v_name,
    v_phone,
    nullif(btrim(coalesce(p_campus, '')), ''),
    nullif(btrim(coalesce(p_ewallet_info, '')), ''),
    v_code,
    'active'
  )
  returning id into v_id;

  return query select v_id, v_code;
end;
$$;

revoke all on function public.register_partner(text, text, text, text) from public;
grant execute on function public.register_partner(text, text, text, text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 5. Import batch: dukung chunk dengan batch id yang sama
-- ---------------------------------------------------------------
create or replace function public.import_prospects_batch(
  p_file_name        text,
  p_rows             jsonb,
  p_source_account   uuid default null,
  p_permission_basis text default 'MANUAL_ENTRY',
  p_batch_id         uuid default null
)
returns table (
  batch_id              uuid,
  inserted_count        int,
  duplicate_in_file     int,
  duplicate_existing    int,
  invalid_count         int,
  suppressed_count      int,
  invalid_samples       text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch    uuid := coalesce(p_batch_id, gen_random_uuid());
  v_rows     int;
  v_continue boolean;
  v_sum      record;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'FORMAT_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_permission_basis not in ('MANUAL_ENTRY','ADMIN_SHARED_LIST','INBOUND_OPT_IN') then
    raise exception 'BASIS_IZIN_TIDAK_VALID' using errcode = '22023';
  end if;

  v_rows := jsonb_array_length(p_rows);
  select exists (select 1 from public.import_batches where id = v_batch) into v_continue;

  if not v_continue then
    insert into public.import_batches (
      id, file_name, source_account_id, permission_basis, total_rows, created_by
    ) values (
      v_batch,
      nullif(btrim(coalesce(p_file_name, '')), ''),
      p_source_account,
      p_permission_basis,
      0,
      auth.uid()
    );
  end if;

  select * into v_sum
  from public.import_prospects(p_rows, p_source_account, p_permission_basis, v_batch);

  update public.import_batches ib
     set total_rows         = ib.total_rows + v_rows,
         inserted_count     = coalesce(ib.inserted_count, 0) + v_sum.inserted_count,
         duplicate_in_file  = coalesce(ib.duplicate_in_file, 0) + v_sum.duplicate_in_file,
         duplicate_existing = coalesce(ib.duplicate_existing, 0) + v_sum.duplicate_existing,
         invalid_count      = coalesce(ib.invalid_count, 0) + v_sum.invalid_count,
         suppressed_count   = coalesce(ib.suppressed_count, 0) + v_sum.suppressed_count
   where ib.id = v_batch;

  return query
    select v_batch, v_sum.inserted_count, v_sum.duplicate_in_file,
           v_sum.duplicate_existing, v_sum.invalid_count, v_sum.suppressed_count,
           v_sum.invalid_samples;
end;
$$;

revoke all on function public.import_prospects_batch(text, jsonb, uuid, text, uuid) from public;
grant execute on function public.import_prospects_batch(text, jsonb, uuid, text, uuid) to authenticated;
