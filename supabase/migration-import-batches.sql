-- =============================================================
-- jokitugasit.my.id — Import batch, statistik prospek, konversi klien
-- Jalankan SETELAH migration-analytics-source.sql.
--
--   * import_batches: jejak setiap file/daftar yang diimpor, supaya
--     sumber data bisa diaudit tanpa menyimpan file mentahnya.
--   * prospect_stats(): angka untuk halaman antrean tanpa mengunduh
--     seluruh tabel prospek ke browser.
--   * create_request_from_prospect(): menghubungkan prospek ke proyek
--     nyata sehingga atribusi sumber dan omzet bisa dilacak.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. import_batches
-- ---------------------------------------------------------------
create table if not exists public.import_batches (
  id                 uuid primary key default gen_random_uuid(),
  file_name          text,
  source_account_id  uuid references public.target_accounts (id) on delete set null,
  permission_basis   text not null default 'MANUAL_ENTRY'
                     check (permission_basis in ('MANUAL_ENTRY','ADMIN_SHARED_LIST','INBOUND_OPT_IN')),
  total_rows         int not null default 0,
  inserted_count     int,
  duplicate_in_file  int,
  duplicate_existing int,
  invalid_count      int,
  suppressed_count   int,
  created_by         uuid,
  created_at         timestamptz not null default now()
);

create index if not exists import_batches_created_idx
  on public.import_batches (created_at desc);

alter table public.import_batches enable row level security;

drop policy if exists import_batches_engineer_all on public.import_batches;
create policy import_batches_engineer_all on public.import_batches
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

-- FK opsional dari prospects.import_batch_id (data lama null, aman)
do $$
begin
  alter table public.prospects
    add constraint prospects_import_batch_fk
    foreign key (import_batch_id) references public.import_batches (id) on delete set null;
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------
-- 2. Import + catat batch dalam satu transaksi
--    (import_prospects yang lama tetap ada; ini hanya pembungkus)
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
  v_batch uuid := coalesce(p_batch_id, gen_random_uuid());
  v_sum   record;
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

  insert into public.import_batches (
    id, file_name, source_account_id, permission_basis, total_rows, created_by
  ) values (
    v_batch,
    nullif(btrim(coalesce(p_file_name, '')), ''),
    p_source_account,
    p_permission_basis,
    jsonb_array_length(p_rows),
    auth.uid()
  );

  select * into v_sum
  from public.import_prospects(p_rows, p_source_account, p_permission_basis, v_batch);

  update public.import_batches ib
     set inserted_count     = v_sum.inserted_count,
         duplicate_in_file  = v_sum.duplicate_in_file,
         duplicate_existing = v_sum.duplicate_existing,
         invalid_count      = v_sum.invalid_count,
         suppressed_count   = v_sum.suppressed_count
   where ib.id = v_batch;

  return query
    select v_batch, v_sum.inserted_count, v_sum.duplicate_in_file,
           v_sum.duplicate_existing, v_sum.invalid_count, v_sum.suppressed_count,
           v_sum.invalid_samples;
end;
$$;

revoke all on function public.import_prospects_batch(text, jsonb, uuid, text, uuid) from public;
grant execute on function public.import_prospects_batch(text, jsonb, uuid, text, uuid) to authenticated;

-- ---------------------------------------------------------------
-- 3. Statistik prospek (dipakai halaman antrean tanpa full download)
-- ---------------------------------------------------------------
create or replace function public.prospect_stats()
returns table (
  total       bigint,
  in_queue    bigint,
  contacted   bigint,
  interested  bigint,
  converted   bigint,
  dnc         bigint
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  return query
  select
    count(*),
    count(*) filter (where status in ('NEW','READY_TO_REVIEW')),
    count(*) filter (where status = 'CONTACTED'),
    count(*) filter (where status in ('INTERESTED_SERVICE','INTERESTED_REFERRAL')),
    count(*) filter (where status = 'CONVERTED'),
    count(*) filter (where do_not_contact)
  from public.prospects;
end;
$$;

revoke all on function public.prospect_stats() from public;
grant execute on function public.prospect_stats() to authenticated;

-- ---------------------------------------------------------------
-- 4. Hubungkan prospek ke proyek nyata
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists prospect_id uuid references public.prospects (id) on delete set null;

create unique index if not exists requests_prospect_unique
  on public.requests (prospect_id)
  where prospect_id is not null;

create or replace function public.create_request_from_prospect(
  p_prospect_id uuid,
  p_category    text default 'web',
  p_description text default null,
  p_quote       bigint default null
)
returns public.requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prospect public.prospects%rowtype;
  v_row      public.requests%rowtype;
  v_order_no text;
  v_attempt  int := 0;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_category not in ('web','mobile','desktop','database','ai','debug',
                        'skripsi','tugas_kuliah','design','lainnya') then
    raise exception 'KATEGORI_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_quote is not null and p_quote < 0 then
    raise exception 'NOMINAL_TIDAK_VALID' using errcode = '22023';
  end if;

  select * into v_prospect from public.prospects where id = p_prospect_id for update;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if v_prospect.do_not_contact then
    raise exception 'DNC_LOCKED: prospek ini meminta tidak dihubungi' using errcode = '42501';
  end if;

  if exists (select 1 from public.requests where prospect_id = p_prospect_id) then
    raise exception 'PROSPEK_SUDAH_DIKONVERSI' using errcode = '23505';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, category, description, deadline,
        status, quote_amount, source, prospect_id
      ) values (
        v_order_no,
        coalesce(nullif(btrim(v_prospect.display_name), ''),
                 '@' || v_prospect.ig_username::text),
        p_category,
        coalesce(nullif(btrim(p_description), ''),
                 'Prospek dari outreach Instagram @' || v_prospect.ig_username::text),
        'besok',
        'consultation',
        p_quote,
        'DIRECT_DM',
        p_prospect_id
      )
      returning * into v_row;
      exit;
    exception when unique_violation then
      if v_attempt >= 8 then
        raise exception 'GAGAL_MEMBUAT_ORDER' using errcode = '23505';
      end if;
    end;
  end loop;

  update public.prospects
     set status = 'CONVERTED'
   where id = p_prospect_id;

  return v_row;
end;
$$;

revoke all on function public.create_request_from_prospect(uuid, text, text, bigint) from public;
grant execute on function public.create_request_from_prospect(uuid, text, text, bigint) to authenticated;
