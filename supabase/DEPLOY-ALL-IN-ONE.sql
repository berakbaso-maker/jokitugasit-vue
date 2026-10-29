-- =============================================================
-- jokitugasit.my.id — DEPLOY BUNDLE
--
-- Tempel SELURUH isi file ini ke Supabase Dashboard > SQL Editor,
-- lalu klik Run. Aman dijalankan berulang: semua pernyataan idempoten.
--
-- URUTAN PENTING: jalankan file ini SEBELUM deploy frontend baru.
-- Frontend baru memanggil RPC yang dibuat di sini; kalau frontend
-- dideploy lebih dulu, halaman tracking & form request akan error.
--
-- Isi = gabungan berurutan:
--   1. migration-security-hardening.sql
--   2. migration-outreach-schema.sql
--   3. migration-money-schema.sql
-- =============================================================

-- ============ migration-security-hardening.sql ============

-- =============================================================
-- jokitugasit.my.id — Security hardening
-- Urutan: jalankan SETELAH schema.sql, migration-referral-partner.sql,
-- dan migration-delivery-walkthrough.sql.
--
-- Menutup empat masalah pada policy lama:
--   1. requests_anon_select_status (using true)  -> anon bisa dump semua
--      nama, whatsapp, deskripsi, internal_notes, quote_amount.
--   2. requests_anon_insert (with check true)    -> anon bisa menulis
--      quote_amount/internal_notes/status bebas.
--   3. partners_anon_validate_code (using status='active') -> anon bisa
--      membaca full_name, whatsapp, ewallet_info milik semua partner.
--   4. transactions_engineer_select (using true untuk role authenticated)
--      -> siapa pun yang punya akun bisa membaca semua transaksi.
--
-- Pengganti: RPC dengan kolom terbatas (security definer).
-- =============================================================

-- ---------------------------------------------------------------
-- 0. Helper dipakai oleh policy di bawah
-- ---------------------------------------------------------------
create or replace function public.is_engineer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'engineer'
  );
$$;

revoke all on function public.is_engineer() from public;
grant execute on function public.is_engineer() to authenticated;

-- ---------------------------------------------------------------
-- 0b. Kolom yang dipakai RPC di bawah (defensif)
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists referral_code text,
  add column if not exists email text;

-- ---------------------------------------------------------------
-- 1. requests: buang policy seleksi + insert publik yang terlalu luas
-- ---------------------------------------------------------------
drop policy if exists "requests_anon_select_status" on public.requests;
drop policy if exists "requests_anon_insert" on public.requests;

-- Engineer tetap memakai policy "requests_engineer_select".
-- Customer tidak lagi menyentuh tabel; gunakan RPC di bawah.

-- ---------------------------------------------------------------
-- 2. RPC publik: kirim request tanpa bisa memalsukan kolom internal
-- ---------------------------------------------------------------
create or replace function public.create_public_request(
  p_customer_name text,
  p_whatsapp      text,
  p_description   text,
  p_category      text default 'web',
  p_deadline      text default 'besok',
  p_deadline_date date default null,
  p_link          text default null,
  p_file_url      text default null,
  p_email         text default null,
  p_referral_code text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_no text;
  v_ref      text;
  v_attempt  int := 0;
begin
  if coalesce(trim(p_customer_name), '') = '' then
    raise exception 'NAMA_WAJIB' using errcode = '22023';
  end if;
  if coalesce(trim(p_whatsapp), '') = '' then
    raise exception 'WHATSAPP_WAJIB' using errcode = '22023';
  end if;
  if coalesce(trim(p_description), '') = '' then
    raise exception 'DESKRIPSI_WAJIB' using errcode = '22023';
  end if;
  if p_category not in ('web','mobile','desktop','database','ai','debug',
                        'skripsi','tugas_kuliah','design','lainnya') then
    raise exception 'KATEGORI_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_deadline not in ('hari_ini','besok','fleksibel') then
    raise exception 'DEADLINE_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_deadline = 'fleksibel' and p_deadline_date is null then
    raise exception 'TANGGAL_WAJIB' using errcode = '22023';
  end if;

  -- Hanya terima kode referral yang benar-benar aktif.
  select upper(trim(p_referral_code)) into v_ref
  from public.partners
  where referral_code = upper(trim(coalesce(p_referral_code, '')))
    and status = 'active';
  if not found then v_ref := null; end if;

  -- Order number dibuat server-side: 6 digit, bukan 4, supaya tidak
  -- bisa dienumerasi berurutan.
  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, whatsapp, email, category, description,
        deadline, deadline_date, link, file_url, referral_code,
        status, quote_amount, internal_notes
      ) values (
        v_order_no,
        trim(p_customer_name),
        trim(p_whatsapp),
        nullif(trim(coalesce(p_email, '')), ''),
        p_category,
        trim(p_description),
        p_deadline,
        case when p_deadline = 'fleksibel' then p_deadline_date end,
        nullif(trim(coalesce(p_link, '')), ''),
        nullif(trim(coalesce(p_file_url, '')), ''),
        v_ref,
        'new',
        null,
        null
      );
      return v_order_no;
    exception when unique_violation then
      if v_attempt >= 8 then
        raise exception 'GAGAL_MEMBUAT_ORDER' using errcode = '23505';
      end if;
    end;
  end loop;
end;
$$;

revoke all on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text
) from public;
grant execute on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text
) to anon, authenticated;

-- ---------------------------------------------------------------
-- 3. RPC publik: lacak order tanpa membocorkan kolom internal
-- ---------------------------------------------------------------
create or replace function public.track_request(p_order_no text)
returns table (
  order_no      text,
  customer_name text,
  category      text,
  deadline      text,
  deadline_date date,
  description   text,
  status        text,
  quote_amount  numeric,
  created_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select r.order_no, r.customer_name, r.category, r.deadline, r.deadline_date,
         r.description, r.status, r.quote_amount, r.created_at
  from public.requests r
  where upper(r.order_no) = upper(trim(p_order_no))
  limit 1;
$$;

revoke all on function public.track_request(text) from public;
grant execute on function public.track_request(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 4. partners: hentikan kebocoran data partner, ganti dengan RPC
-- ---------------------------------------------------------------
-- Pastikan tabel partners ada (isi sama dengan migration-referral-partner.sql)
-- supaya urutan migration tidak bisa membuat deploy gagal separuh jalan.
create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  whatsapp text not null,
  campus text,
  referral_code text unique not null,
  ewallet_info text,
  total_referrals int default 0,
  total_commission numeric default 0,
  status text default 'active' check (status in ('active','inactive')),
  notes text,
  created_at timestamptz default now()
);

alter table public.partners enable row level security;

drop policy if exists "partners_engineer_all" on public.partners;
create policy "partners_engineer_all"
  on public.partners for all
  to authenticated
  using (public.is_engineer())
  with check (public.is_engineer());

drop policy if exists "partners_anon_validate_code" on public.partners;

create index if not exists idx_partners_referral_code on public.partners (referral_code);

create or replace function public.validate_referral_code(p_code text)
returns table (
  valid        boolean,
  display_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select true,
         coalesce(nullif(split_part(p.full_name, ' ', 1), ''), 'Partner')
  from public.partners p
  where p.referral_code = upper(trim(p_code))
    and p.status = 'active'
  limit 1;
$$;

revoke all on function public.validate_referral_code(text) from public;
grant execute on function public.validate_referral_code(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 5. transactions: hanya engineer
-- ---------------------------------------------------------------
drop policy if exists "transactions_engineer_select" on public.transactions;

create policy "transactions_engineer_select"
  on public.transactions for select
  to authenticated
  using (public.is_engineer());

-- ---------------------------------------------------------------
-- 6. Jaring pengaman: apa pun yang lolos ke anon tidak boleh
--    menyentuh kolom finansial/internal.
-- ---------------------------------------------------------------
create or replace function public.requests_guard_anon()
returns trigger
language plpgsql
as $$
begin
  -- PostgREST menjalankan request anonim sebagai role database "anon".
  -- Memakai current_user (bukan JWT claim) supaya sesi administratif
  -- seperti SQL Editor / migration tidak ikut terblokir.
  if current_user = 'anon' then
    new.quote_amount   := null;
    new.internal_notes := null;
    new.status         := 'new';
    if tg_op = 'UPDATE' then
      raise exception 'AKSES_DITOLAK' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists requests_guard_anon_trg on public.requests;
create trigger requests_guard_anon_trg
  before insert or update on public.requests
  for each row execute function public.requests_guard_anon();

-- ============ migration-outreach-schema.sql ============

-- =============================================================
-- jokitugasit.my.id — Outreach schema (target accounts, prospects,
-- DM templates, outreach logs)
-- Urutan: jalankan SETELAH schema.sql + migration-security-hardening.sql.
--
-- Prinsip:
--   * Tidak ada kredensial Instagram, tidak ada cookie sesi.
--   * Prospek hanya boleh masuk lewat input manual atau daftar yang
--     diserahkan admin dengan izin (permission_basis wajib).
--   * do_not_contact bersifat lengket: tidak bisa dilepas oleh import,
--     upsert, atau update biasa.
-- =============================================================

create extension if not exists citext;

-- ---------------------------------------------------------------
-- target_accounts: akun angkatan/jurusan sebagai SUMBER prospek
-- ---------------------------------------------------------------
create table if not exists public.target_accounts (
  id                 uuid primary key default gen_random_uuid(),
  ig_username        citext not null unique
                     check (ig_username ~ '^[a-z0-9._]{1,30}$'),
  instagram_profile_url text,
  campus             text,
  major              text,
  cohort_year        int check (cohort_year between 1990 and 2036),
  account_type       text not null default 'COHORT'
                     check (account_type in ('COHORT','DEPARTMENT','STUDENT_ORG','OTHER')),
  relationship_status text not null default 'NEW'
                     check (relationship_status in ('NEW','CONTACTED','PERMISSION_GRANTED','DECLINED')),
  admin_contact      text,
  permission_granted_at timestamptz,
  notes              text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index if not exists target_accounts_status_idx
  on public.target_accounts (relationship_status, campus);

-- ---------------------------------------------------------------
-- prospects: satu baris per username, unik lintas sumber
-- ---------------------------------------------------------------
create table if not exists public.prospects (
  id                    uuid primary key default gen_random_uuid(),
  ig_username           citext not null unique
                        check (ig_username ~ '^[a-z0-9._]{1,30}$'),
  display_name          text,
  campus                text,
  major                 text,
  cohort_year           int check (cohort_year between 1990 and 2036),
  status                text not null default 'NEW'
                        check (status in ('NEW','READY_TO_REVIEW','CONTACTED','REPLIED',
                                          'INTERESTED_SERVICE','INTERESTED_REFERRAL',
                                          'NOT_INTERESTED','DO_NOT_CONTACT','CONVERTED')),
  do_not_contact        boolean not null default false,
  do_not_contact_reason text,
  do_not_contact_at     timestamptz,
  permission_basis      text not null default 'MANUAL_ENTRY'
                        check (permission_basis in ('MANUAL_ENTRY','ADMIN_SHARED_LIST','INBOUND_OPT_IN')),
  source_account_id     uuid references public.target_accounts (id) on delete set null,
  import_batch_id       uuid,
  collected_at          timestamptz,
  first_seen_at         timestamptz not null default now(),
  last_contacted_at     timestamptz,
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  -- status dan flag DNC tidak boleh saling bertentangan
  constraint prospects_dnc_consistent check (
    (do_not_contact and status = 'DO_NOT_CONTACT')
    or (not do_not_contact and status <> 'DO_NOT_CONTACT')
  )
);

create index if not exists prospects_queue_idx
  on public.prospects (status, campus, first_seen_at desc);
create index if not exists prospects_source_idx
  on public.prospects (source_account_id);

-- ---------------------------------------------------------------
-- Bukti DNC tidak bisa dilepas tanpa sengaja (import/upsert/update)
-- ---------------------------------------------------------------
create or replace function public.prospects_guard_dnc()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and old.do_not_contact and not new.do_not_contact then
    if coalesce(current_setting('app.dnc_override', true), 'off') <> 'on' then
      raise exception 'DNC_LOCKED: prospek % berstatus do-not-contact', old.ig_username
        using errcode = '42501';
    end if;
  end if;

  if new.do_not_contact and not coalesce(old.do_not_contact, false) then
    new.do_not_contact_at := coalesce(new.do_not_contact_at, now());
    new.status := 'DO_NOT_CONTACT';
  end if;

  if new.status = 'DO_NOT_CONTACT' then
    new.do_not_contact := true;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists prospects_guard_dnc_trg on public.prospects;
create trigger prospects_guard_dnc_trg
  before insert or update on public.prospects
  for each row execute function public.prospects_guard_dnc();

-- ---------------------------------------------------------------
-- dm_templates
-- ---------------------------------------------------------------
create table if not exists public.dm_templates (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  category   text not null default 'DUAL_OFFER'
             check (category in ('ADMIN','DIRECT','DUAL_OFFER','REFERRAL','WEBSITE_REPLY','OPT_OUT')),
  body       text not null,
  is_active  boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------
-- outreach_logs: catatan manual, bukan pengiriman otomatis
-- ---------------------------------------------------------------
create table if not exists public.outreach_logs (
  id           uuid primary key default gen_random_uuid(),
  prospect_id  uuid not null references public.prospects (id) on delete cascade,
  template_id  uuid references public.dm_templates (id) on delete set null,
  channel      text not null default 'INSTAGRAM_DM_MANUAL'
               check (channel in ('INSTAGRAM_DM_MANUAL','INSTAGRAM_COMMENT_REPLY','WHATSAPP','OTHER')),
  outcome      text not null default 'SENT'
               check (outcome in ('SENT','REPLIED','INTERESTED_SERVICE','INTERESTED_REFERRAL',
                                  'NOT_INTERESTED','NO_RESPONSE','DO_NOT_CONTACT')),
  note         text,
  sent_at      timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create index if not exists outreach_logs_prospect_idx
  on public.outreach_logs (prospect_id, sent_at desc);

-- ---------------------------------------------------------------
-- RLS: hanya engineer. Prospek tidak pernah dibaca anon.
-- ---------------------------------------------------------------
alter table public.target_accounts enable row level security;
alter table public.prospects       enable row level security;
alter table public.dm_templates    enable row level security;
alter table public.outreach_logs   enable row level security;

drop policy if exists target_accounts_engineer_all on public.target_accounts;
create policy target_accounts_engineer_all on public.target_accounts
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists prospects_engineer_all on public.prospects;
create policy prospects_engineer_all on public.prospects
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists dm_templates_engineer_all on public.dm_templates;
create policy dm_templates_engineer_all on public.dm_templates
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists outreach_logs_engineer_all on public.outreach_logs;
create policy outreach_logs_engineer_all on public.outreach_logs
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

-- ---------------------------------------------------------------
-- Normalisasi username: trim, buang '@', lowercase
-- ---------------------------------------------------------------
create or replace function public.normalize_ig_username(p text)
returns text
language sql
immutable
as $$
  select lower(regexp_replace(btrim(coalesce(p, '')), '^@+', ''));
$$;

-- ---------------------------------------------------------------
-- Import prospek: dedupe, validasi, dan TIDAK menyentuh DNC
-- Mengembalikan ringkasan supaya UI bisa menampilkan report.
-- ---------------------------------------------------------------
create or replace function public.import_prospects(
  p_rows         jsonb,
  p_source_account uuid default null,
  p_permission_basis text default 'MANUAL_ENTRY',
  p_batch_id     uuid default null
)
returns table (
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
  v_row        jsonb;
  v_username   text;
  v_seen       text[] := '{}';
  v_invalid    text[] := '{}';
  v_ins        int := 0;
  v_dup_file   int := 0;
  v_dup_exist  int := 0;
  v_suppressed int := 0;
  v_existing   public.prospects%rowtype;
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

  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_username := public.normalize_ig_username(v_row ->> 'ig_username');

    if v_username !~ '^[a-z0-9._]{1,30}$' then
      v_invalid := v_invalid || coalesce(v_row ->> 'ig_username', '');
      continue;
    end if;

    if v_username = any (v_seen) then
      v_dup_file := v_dup_file + 1;
      continue;
    end if;
    v_seen := v_seen || v_username;

    select * into v_existing from public.prospects where ig_username = v_username;

    if found then
      v_dup_exist := v_dup_exist + 1;

      if v_existing.do_not_contact then
        v_suppressed := v_suppressed + 1;
        -- sengaja tidak mengubah apa pun: DNC harus tetap berlaku
        continue;
      end if;

      -- Lengkapi metadata yang masih kosong, jangan timpa yang sudah ada.
      update public.prospects set
        display_name      = coalesce(display_name, nullif(btrim(coalesce(v_row ->> 'display_name', '')), '')),
        campus            = coalesce(campus, nullif(btrim(coalesce(v_row ->> 'campus', '')), '')),
        cohort_year       = coalesce(cohort_year, nullif(v_row ->> 'cohort_year', '')::int),
        source_account_id = coalesce(source_account_id, p_source_account)
      where id = v_existing.id;
      continue;
    end if;

    insert into public.prospects (
      ig_username, display_name, campus, cohort_year, permission_basis,
      source_account_id, import_batch_id, collected_at
    ) values (
      v_username,
      nullif(btrim(coalesce(v_row ->> 'display_name', '')), ''),
      nullif(btrim(coalesce(v_row ->> 'campus', '')), ''),
      nullif(v_row ->> 'cohort_year', '')::int,
      p_permission_basis,
      p_source_account,
      p_batch_id,
      now()
    );
    v_ins := v_ins + 1;
  end loop;

  return query select v_ins, v_dup_file, v_dup_exist, coalesce(array_length(v_invalid, 1), 0),
                      v_suppressed, v_invalid;
end;
$$;

revoke all on function public.import_prospects(jsonb, uuid, text, uuid) from public;
grant execute on function public.import_prospects(jsonb, uuid, text, uuid) to authenticated;

-- ---------------------------------------------------------------
-- Catat hasil kontak + ubah status prospek dalam satu transaksi
-- ---------------------------------------------------------------
create or replace function public.log_outreach(
  p_prospect_id uuid,
  p_template_id uuid default null,
  p_outcome     text default 'SENT',
  p_note        text default null,
  p_channel     text default 'INSTAGRAM_DM_MANUAL'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_dnc boolean;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_outcome not in ('SENT','REPLIED','INTERESTED_SERVICE','INTERESTED_REFERRAL',
                       'NOT_INTERESTED','NO_RESPONSE','DO_NOT_CONTACT') then
    raise exception 'OUTCOME_TIDAK_VALID' using errcode = '22023';
  end if;

  select do_not_contact into v_dnc from public.prospects where id = p_prospect_id;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if v_dnc then
    raise exception 'DNC_LOCKED: prospek ini meminta tidak dihubungi'
      using errcode = '42501';
  end if;

  insert into public.outreach_logs (prospect_id, template_id, channel, outcome, note)
  values (p_prospect_id, p_template_id, p_channel, p_outcome, p_note);

  update public.prospects set
    status = case p_outcome
               when 'SENT'                   then 'CONTACTED'
               when 'REPLIED'                then 'REPLIED'
               when 'INTERESTED_SERVICE'     then 'INTERESTED_SERVICE'
               when 'INTERESTED_REFERRAL'    then 'INTERESTED_REFERRAL'
               when 'NOT_INTERESTED'         then 'NOT_INTERESTED'
               when 'DO_NOT_CONTACT'         then 'DO_NOT_CONTACT'
               else status
             end,
    do_not_contact = case when p_outcome = 'DO_NOT_CONTACT' then true else do_not_contact end,
    last_contacted_at = case when p_outcome = 'SENT' then now() else last_contacted_at end
  where id = p_prospect_id;
end;
$$;

revoke all on function public.log_outreach(uuid, uuid, text, text, text) from public;
grant execute on function public.log_outreach(uuid, uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------
-- Lepas DNC secara sengaja (dengan alasan wajib + audit)
-- Trigger prospects_guard_dnc memblokir pelepasan biasa, jadi ini
-- satu-satunya jalan yang sah.
-- ---------------------------------------------------------------
create or replace function public.clear_do_not_contact(
  p_prospect_id uuid,
  p_reason      text
)
returns public.prospects
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'ALASAN_WAJIB' using errcode = '22023';
  end if;

  select * into v_row from public.prospects where id = p_prospect_id for update;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if not v_row.do_not_contact then
    return v_row;
  end if;

  perform set_config('app.dnc_override', 'on', true);

  update public.prospects set
    do_not_contact        = false,
    do_not_contact_reason = null,
    do_not_contact_at     = null,
    status                = 'NEW'
  where id = p_prospect_id
  returning * into v_row;

  perform set_config('app.dnc_override', 'off', true);

  insert into public.outreach_logs (prospect_id, channel, outcome, note)
  values (p_prospect_id, 'OTHER', 'NO_RESPONSE',
          'DNC dilepas manual. Alasan: ' || btrim(p_reason));

  return v_row;
end;
$$;

revoke all on function public.clear_do_not_contact(uuid, text) from public;
grant execute on function public.clear_do_not_contact(uuid, text) to authenticated;

-- ============ migration-money-schema.sql ============

-- =============================================================
-- jokitugasit.my.id — Money & commission schema
-- Urutan: jalankan SETELAH migration-security-hardening.sql.
--
-- Menggantikan `requests.commission_paid` (boolean, tanpa audit) dengan
-- tabel commissions yang:
--   * menyimpan nominal sebagai bigint rupiah (tidak ada float),
--   * hanya menjadi ELIGIBLE setelah pembayaran lunas (DP tidak dihitung),
--   * tidak bisa dihitung ganda walau ada dua baris pembayaran,
--   * idempoten lewat idempotency_key pada payments.
-- =============================================================

-- ---------------------------------------------------------------
-- 0. Prasyarat: kolom dari migration-referral-partner.sql
--    (dibuat defensif supaya file ini aman dijalankan di database
--    yang mungkin belum menjalankan migration tersebut)
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists referral_code text,
  add column if not exists email text,
  add column if not exists commission_paid boolean default false;

create index if not exists idx_requests_referral_code on public.requests (referral_code);

-- ---------------------------------------------------------------
-- 1. quote_amount jadi integer rupiah
-- ---------------------------------------------------------------
alter table public.requests
  alter column quote_amount type bigint using round(coalesce(quote_amount, 0))::bigint;

alter table public.requests
  add column if not exists discount_amount bigint not null default 0
    check (discount_amount >= 0);

-- Engineer perlu bisa membuat proyek dari dashboard (policy lama hanya
-- mengizinkan SELECT/UPDATE).
drop policy if exists "requests_engineer_insert" on public.requests;
create policy "requests_engineer_insert"
  on public.requests for insert
  to authenticated
  with check (public.is_engineer());

-- ---------------------------------------------------------------
-- 2. payments
-- ---------------------------------------------------------------
create table if not exists public.payments (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null references public.requests (id) on delete restrict,
  kind            text not null check (kind in ('DP','SETTLEMENT','REFUND')),
  amount          bigint not null check (amount > 0),
  status          text not null default 'CONFIRMED'
                  check (status in ('PENDING','CONFIRMED','VOID')),
  method          text,
  proof_url       text,
  idempotency_key text unique,
  paid_at         timestamptz,
  note            text,
  created_at      timestamptz not null default now()
);

create index if not exists payments_request_idx on public.payments (request_id, status);

-- ---------------------------------------------------------------
-- 3. commissions
-- ---------------------------------------------------------------
create table if not exists public.commissions (
  id              uuid primary key default gen_random_uuid(),
  request_id      uuid not null unique references public.requests (id) on delete restrict,
  partner_id      uuid not null references public.partners (id) on delete restrict,
  eligible_amount bigint not null default 0 check (eligible_amount >= 0),
  rate_bps        int not null default 1000 check (rate_bps between 0 and 10000),
  amount          bigint generated always as ((eligible_amount * rate_bps) / 10000) stored,
  status          text not null default 'PENDING'
                  check (status in ('PENDING','ELIGIBLE','PAID','VOID','ADJUSTMENT')),
  paid_at         timestamptz,
  payment_proof   text,
  note            text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- PAID wajib punya bukti waktu bayar
  constraint commissions_paid_has_timestamp check (
    status <> 'PAID' or paid_at is not null
  )
);

create index if not exists commissions_partner_idx on public.commissions (partner_id, status);
create index if not exists commissions_status_idx on public.commissions (status, created_at desc);

-- Satu proyek hanya boleh punya satu attribution partner.
create unique index if not exists commissions_one_per_request
  on public.commissions (request_id);

-- ---------------------------------------------------------------
-- 4. Hitung ulang komisi dari pembayaran yang benar-benar CONFIRMED
-- ---------------------------------------------------------------
-- Inti perhitungan. Tidak diekspos ke PostgREST; hanya dipanggil oleh
-- wrapper berizin di bawah atau oleh migration/backfill.
create or replace function public.recompute_commission_internal(p_request_id uuid)
returns public.commissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req        public.requests%rowtype;
  v_partner_id uuid;
  v_paid       bigint;
  v_refunded   bigint;
  v_total      bigint;
  v_eligible   bigint;
  v_row        public.commissions%rowtype;
begin
  select * into v_req from public.requests where id = p_request_id;
  if not found then
    raise exception 'PROYEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  select id into v_partner_id
  from public.partners
  where referral_code = upper(trim(coalesce(v_req.referral_code, '')))
    and status = 'active';

  -- Tanpa partner aktif: tidak ada komisi, dan baris lama (jika ada) dibatalkan.
  if v_partner_id is null then
    update public.commissions
       set status = 'VOID', eligible_amount = 0, updated_at = now()
     where request_id = p_request_id
       and status in ('PENDING','ELIGIBLE');
    select * into v_row from public.commissions where request_id = p_request_id;
    return v_row;
  end if;

  select coalesce(sum(amount), 0) into v_paid
  from public.payments
  where request_id = p_request_id and status = 'CONFIRMED' and kind <> 'REFUND';

  select coalesce(sum(amount), 0) into v_refunded
  from public.payments
  where request_id = p_request_id and status = 'CONFIRMED' and kind = 'REFUND';

  v_total := greatest(coalesce(v_req.quote_amount, 0) - coalesce(v_req.discount_amount, 0), 0);

  -- DP / pembayaran sebagian TIDAK membuat komisi eligible.
  -- Refund mengurangi nilai yang dikomisikan, bukan membatalkan seluruh
  -- komisi (kecuali refund-nya memang menutup seluruh nilai transaksi).
  if v_total > 0 and v_paid >= v_total then
    v_eligible := greatest(v_total - v_refunded, 0);
  else
    v_eligible := 0;
  end if;

  insert into public.commissions (request_id, partner_id, eligible_amount, status)
  values (p_request_id, v_partner_id, v_eligible,
          case
            when v_eligible > 0 then 'ELIGIBLE'
            when v_refunded > 0 then 'VOID'
            else 'PENDING'
          end)
  on conflict (request_id) do update
    set partner_id = excluded.partner_id,
        status = case
                   -- Sudah dibayar: jangan pernah menurunkan status atau
                   -- menulis ulang nominal yang sudah dibayarkan. Kalau nilai
                   -- eligible berubah, tandai ADJUSTMENT untuk review manual.
                   when public.commissions.status = 'PAID' then
                     case when excluded.eligible_amount <> public.commissions.eligible_amount
                          then 'ADJUSTMENT' else 'PAID' end
                   when public.commissions.status = 'ADJUSTMENT' then 'ADJUSTMENT'
                   else excluded.status
                 end,
        eligible_amount = case
                            when public.commissions.status in ('PAID','ADJUSTMENT')
                              then public.commissions.eligible_amount
                            else excluded.eligible_amount
                          end,
        updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.recompute_commission_internal(uuid) from public;

create or replace function public.recompute_commission(p_request_id uuid)
returns public.commissions
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  return public.recompute_commission_internal(p_request_id);
end;
$$;

revoke all on function public.recompute_commission(uuid) from public;
grant execute on function public.recompute_commission(uuid) to authenticated;

-- ---------------------------------------------------------------
-- 5. Catat pembayaran (idempoten) lalu hitung ulang komisi
-- ---------------------------------------------------------------
create or replace function public.record_payment(
  p_request_id      uuid,
  p_kind            text,
  p_amount          bigint,
  p_idempotency_key text default null,
  p_method          text default null,
  p_proof_url       text default null,
  p_paid_at         timestamptz default now(),
  p_note            text default null
)
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.payments%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_kind not in ('DP','SETTLEMENT','REFUND') then
    raise exception 'JENIS_PEMBAYARAN_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'NOMINAL_TIDAK_VALID' using errcode = '22023';
  end if;

  -- Idempotensi: kirim kunci yang sama dua kali -> kembalikan baris lama,
  -- jangan pernah menambah komisi dua kali.
  if p_idempotency_key is not null then
    select * into v_row from public.payments where idempotency_key = p_idempotency_key;
    if found then
      perform public.recompute_commission_internal(v_row.request_id);
      return v_row;
    end if;
  end if;

  insert into public.payments (request_id, kind, amount, status, method,
                               proof_url, idempotency_key, paid_at, note)
  values (p_request_id, p_kind, p_amount, 'CONFIRMED', p_method,
          p_proof_url, p_idempotency_key, p_paid_at, p_note)
  returning * into v_row;

  perform public.recompute_commission_internal(p_request_id);
  return v_row;
end;
$$;

revoke all on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) from public;
grant execute on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------
-- 6. Tandai komisi dibayar
-- ---------------------------------------------------------------
create or replace function public.mark_commission_paid(
  p_commission_id uuid,
  p_proof_url     text default null,
  p_note          text default null
)
returns public.commissions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.commissions%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  select * into v_row from public.commissions where id = p_commission_id for update;
  if not found then
    raise exception 'KOMISI_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if v_row.status <> 'ELIGIBLE' then
    raise exception 'KOMISI_BELUM_ELIGIBLE: status % tidak bisa dibayar', v_row.status
      using errcode = '22023';
  end if;

  update public.commissions
     set status = 'PAID', paid_at = now(),
         payment_proof = p_proof_url, note = coalesce(p_note, note),
         updated_at = now()
   where id = p_commission_id
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.mark_commission_paid(uuid, text, text) from public;
grant execute on function public.mark_commission_paid(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------
-- 7. Sinkronkan kolom warisan supaya UI lama tidak menampilkan data palsu
-- ---------------------------------------------------------------
create or replace function public.sync_legacy_commission_flag()
returns trigger
language plpgsql
as $$
begin
  update public.requests
     set commission_paid = (new.status = 'PAID')
   where id = new.request_id;
  return new;
end;
$$;

drop trigger if exists commissions_sync_legacy_trg on public.commissions;
create trigger commissions_sync_legacy_trg
  after insert or update of status on public.commissions
  for each row execute function public.sync_legacy_commission_flag();

-- ---------------------------------------------------------------
-- 8. Backfill: proyek lama dengan referral_code
-- ---------------------------------------------------------------
do $$
declare
  v_req_id uuid;
begin
  for v_req_id in
    select id from public.requests
    where referral_code is not null and quote_amount is not null
  loop
    perform public.recompute_commission_internal(v_req_id);
  end loop;

  -- Data lama yang sudah ditandai commission_paid=true dianggap sudah dibayar.
  update public.commissions c
     set status = 'PAID', paid_at = coalesce(c.paid_at, now()),
         note = coalesce(c.note, 'backfill dari commission_paid')
    from public.requests req
   where req.id = c.request_id
     and req.commission_paid = true
     and c.status = 'ELIGIBLE';
end;
$$;

-- ---------------------------------------------------------------
-- 9. RLS
-- ---------------------------------------------------------------
alter table public.payments    enable row level security;
alter table public.commissions enable row level security;

drop policy if exists payments_engineer_all on public.payments;
create policy payments_engineer_all on public.payments
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists commissions_engineer_all on public.commissions;
create policy commissions_engineer_all on public.commissions
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

create or replace function public.analytics_overview(
  p_from date default null,
  p_to   date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  return (
  with windowed_requests as (
    select * from public.requests
    where (p_from is null or created_at >= p_from)
      and (p_to   is null or created_at <  (p_to + 1))
  ),
  paid as (
    select coalesce(sum(amount), 0) as gross
    from public.payments
    where status = 'CONFIRMED' and kind <> 'REFUND'
  ),
  commission_totals as (
    select
      coalesce(sum(amount) filter (where status = 'PAID'), 0)     as paid,
      coalesce(sum(amount) filter (where status = 'ELIGIBLE'), 0) as unpaid
    from public.commissions
  )
  select jsonb_build_object(
    'target_accounts',    (select count(*) from public.target_accounts),
    'permission_granted', (select count(*) from public.target_accounts
                            where relationship_status = 'PERMISSION_GRANTED'),
    'prospects_total',    (select count(*) from public.prospects),
    'prospects_queue',    (select count(*) from public.prospects
                            where status in ('NEW','READY_TO_REVIEW')),
    'prospects_dnc',      (select count(*) from public.prospects where do_not_contact),
    'contacts_sent',      (select count(*) from public.outreach_logs where outcome = 'SENT'),
    'responses',          (select count(*) from public.outreach_logs
                            where outcome in ('REPLIED','INTERESTED_SERVICE',
                                              'INTERESTED_REFERRAL','NOT_INTERESTED')),
    'interested',         (select count(*) from public.outreach_logs
                            where outcome in ('INTERESTED_SERVICE','INTERESTED_REFERRAL')),
    'projects_total',     (select count(*) from windowed_requests),
    'projects_completed', (select count(*) from windowed_requests where status = 'paid'),
    'gross_confirmed',    (select gross from paid),
    'commission_paid',    (select paid from commission_totals),
    'commission_unpaid',  (select unpaid from commission_totals),
    'active_partners',    (select count(*) from public.partners where status = 'active'),
    'partners_with_deal', (select count(distinct partner_id) from public.commissions
                            where status in ('ELIGIBLE','PAID'))
  ));
end;
$$;

revoke all on function public.analytics_overview(date, date) from public;
grant execute on function public.analytics_overview(date, date) to authenticated;

create or replace function public.analytics_funnel(
  p_from date default null,
  p_to   date default null
)
returns table (
  stage    text,
  count    bigint,
  ordering int
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
  with base as (
    select * from public.outreach_logs
    where (p_from is null or sent_at >= p_from)
      and (p_to   is null or sent_at <  (p_to + 1))
  )
  select 'Dihubungi', count(*), 1 from base
  union all
  select 'Dibalas', count(*) filter (where outcome in
    ('REPLIED','INTERESTED_SERVICE','INTERESTED_REFERRAL','NOT_INTERESTED')), 2 from base
  union all
  select 'Berminat', count(*) filter (where outcome in
    ('INTERESTED_SERVICE','INTERESTED_REFERRAL')), 3 from base
  union all
  select 'Deal', (select count(*) from public.requests r
                  where r.status in ('working','review','done','paid')
                    and (p_from is null or r.created_at >= p_from)
                    and (p_to is null or r.created_at < (p_to + 1))), 4
  order by 3;
end;
$$;

revoke all on function public.analytics_funnel(date, date) from public;
grant execute on function public.analytics_funnel(date, date) to authenticated;

-- ---------------------------------------------------------------
-- 10b. Portal partner (publik, tapi hanya data partner itu sendiri)
-- ---------------------------------------------------------------
create or replace function public.partner_portal(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_partner public.partners%rowtype;
  v_code    text := upper(btrim(coalesce(p_code, '')));
begin
  select * into v_partner
  from public.partners
  where referral_code = v_code and status = 'active';

  if not found then return null; end if;

  return jsonb_build_object(
    'partner', jsonb_build_object(
      'full_name',     v_partner.full_name,
      'referral_code', v_partner.referral_code,
      'campus',        v_partner.campus,
      'status',        v_partner.status
    ),
    'stats', jsonb_build_object(
      'referral_count', count(*),
      'deal_count',     count(*) filter (where c.status in ('ELIGIBLE','PAID','ADJUSTMENT')),
      'total_paid',     coalesce(sum(c.amount) filter (where c.status = 'PAID'), 0),
      'total_pending',  coalesce(sum(c.amount) filter (where c.status = 'ELIGIBLE'), 0)
    ),
    'commissions', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'order_no',    r.order_no,
          'category',    r.category,
          'status',      c.status,
          'amount',      c.amount,
          'created_at',  c.created_at,
          'paid_at',     c.paid_at
        ) order by c.created_at desc
      ) filter (where c.id is not null),
      '[]'::jsonb
    )
  )
  from public.commissions c
  join public.requests r on r.id = c.request_id
  where c.partner_id = v_partner.id;
end;
$$;

revoke all on function public.partner_portal(text) from public;
grant execute on function public.partner_portal(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 11. Seed template DM
-- ---------------------------------------------------------------
insert into public.dm_templates (name, category, body, sort_order)
select * from (values
  ('Perkenalan ke admin angkatan', 'ADMIN',
   'Halo kak, izin perkenalan. Saya software engineer yang membuka jasa konsultasi coding, debugging, integrasi API/database, serta pengembangan software. Saya ingin memperkenalkan layanan ini kepada teman-teman mahasiswa IT di angkatan kakak. Saya juga menyediakan komisi referral 10% untuk rekomendasi yang berhasil menjadi klien. Apakah berkenan jika saya kirim website dan informasi singkatnya untuk dipertimbangkan atau dibagikan? Terima kasih, kak.', 1),
  ('Direct client + referral', 'DUAL_OFFER',
   'Halo kak, salam kenal! Saya software engineer dan sedang membuka jasa bantuan teknis coding, debugging, API/database, dan pengembangan aplikasi. Kalau kakak sedang butuh bantuan teknis atau punya teman yang membutuhkan, boleh menghubungi saya. Saya juga menyediakan komisi referral 10% untuk rekomendasi yang berhasil menjadi klien. Jika berkenan, boleh saya bagikan website dan portofolionya?', 2),
  ('Penjelasan skema referral', 'REFERRAL',
   'Terima kasih sudah tertarik, kak! Skemanya sederhana: kakak cukup merekomendasikan website/jasa saya kepada teman yang memang membutuhkan. Jika teman kakak jadi menggunakan jasa saya dan pembayarannya sudah lunas, kakak mendapatkan komisi 10% dari nilai transaksi setelah diskon. Seluruh pekerjaan teknis saya yang menangani. Kalau berkenan, nanti saya berikan kode referral khusus.', 3),
  ('Balasan setelah minta website', 'WEBSITE_REPLY',
   'Siap kak, ini website/portofolio saya: {website_url}. Silakan dilihat dulu. Kalau ada kendala teknis atau project yang mau didiskusikan, boleh cerita kebutuhan dan stack yang digunakan. Kalau ingin merekomendasikan ke teman, saya juga bisa buatkan kode referral.', 4),
  ('Penolakan / opt-out', 'OPT_OUT',
   'Baik kak, terima kasih sudah membalas. Saya tidak akan menghubungi lagi terkait penawaran ini. Semoga aktivitasnya lancar ya.', 5)
) as t(name, category, body, sort_order)
where not exists (select 1 from public.dm_templates);
