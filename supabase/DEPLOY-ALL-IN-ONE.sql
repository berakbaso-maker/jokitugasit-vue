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
--   4. migration-payment-flow.sql
--   5. migration-analytics-source.sql
--   6. migration-import-batches.sql
--   7. migration-referral-integrity.sql
--   8. migration-data-rights.sql
--   9. migration-project-details.sql
--  10. migration-hardening.sql
--  11. migration-consent-guard.sql
--  12. migration-campaigns.sql
--  13. migration-internal-platform.sql
--  14. migration-testimonials.sql
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

-- ============ migration-payment-flow.sql ============

-- =============================================================
-- jokitugasit.my.id — Payment flow (Slice 1)
-- Jalankan SETELAH migration-money-schema.sql.
--
-- Tujuan:
--   1. Status proyek diturunkan dari tabel `payments`, bukan dari klik
--      "Mark as Paid" yang bisa berbohong.
--   2. Pembayaran yang salah input bisa dibatalkan (VOID) dengan alasan,
--      tanpa menghapus baris dan tanpa menghilangkan audit.
--   3. Data lama berstatus `paid` tanpa baris payments TIDAK disentuh
--      supaya tidak ada status historis yang tiba-tiba mundur.
--
-- Semua pernyataan additive/idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 0. Audit untuk pembatalan pembayaran
-- ---------------------------------------------------------------
alter table public.payments
  add column if not exists voided_at timestamptz,
  add column if not exists void_reason text;

-- ---------------------------------------------------------------
-- 1. Sinkronkan requests.status dengan pembayaran yang benar-benar ada
-- ---------------------------------------------------------------
-- Aturan:
--   * net = (pembayaran CONFIRMED selain REFUND) - (refund CONFIRMED)
--   * net >= total  -> 'paid'
--   * status sudah 'paid' tapi net < total dan proyek punya jejak
--     pembayaran -> 'working' (perlu tindakan manual untuk refund penuh;
--     status 'cancelled' belum ada di skema).
--   * proyek tanpa baris payments sama sekali tidak pernah diturunkan.
create or replace function public.sync_request_payment_status(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total    bigint;
  v_paid     bigint;
  v_refunded bigint;
  v_net      bigint;
  v_status   text;
  v_has_pay  boolean;
begin
  -- Boleh dipanggil engineer, atau proses server/migration (tanpa JWT).
  if auth.uid() is not null and not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  select greatest(coalesce(quote_amount, 0) - coalesce(discount_amount, 0), 0),
         status
    into v_total, v_status
  from public.requests
  where id = p_request_id;

  if not found then
    raise exception 'PROYEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  select coalesce(sum(amount) filter (where kind <> 'REFUND'), 0),
         coalesce(sum(amount) filter (where kind = 'REFUND'), 0),
         count(*) > 0
    into v_paid, v_refunded, v_has_pay
  from public.payments
  where request_id = p_request_id and status = 'CONFIRMED';

  v_net := greatest(v_paid - v_refunded, 0);

  if v_total > 0 and v_net >= v_total then
    update public.requests set status = 'paid'
     where id = p_request_id and status <> 'paid';
  elsif v_status = 'paid' and v_net < v_total and v_has_pay then
    update public.requests set status = 'working'
     where id = p_request_id and status = 'paid';
  end if;
end;
$$;

revoke all on function public.sync_request_payment_status(uuid) from public;

-- ---------------------------------------------------------------
-- 2. record_payment: perilaku lama + sinkron status
--    (idempotency_key tetap sama; DP tetap belum eligible)
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

  -- Idempotensi: kirim kunci yang sama dua kali -> kembalikan baris lama.
  if p_idempotency_key is not null then
    select * into v_row from public.payments where idempotency_key = p_idempotency_key;
    if found then
      perform public.recompute_commission_internal(v_row.request_id);
      perform public.sync_request_payment_status(v_row.request_id);
      return v_row;
    end if;
  end if;

  insert into public.payments (request_id, kind, amount, status, method,
                               proof_url, idempotency_key, paid_at, note)
  values (p_request_id, p_kind, p_amount, 'CONFIRMED', p_method,
          p_proof_url, p_idempotency_key, p_paid_at, p_note)
  returning * into v_row;

  perform public.recompute_commission_internal(p_request_id);
  perform public.sync_request_payment_status(p_request_id);
  return v_row;
end;
$$;

revoke all on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) from public;
grant execute on function public.record_payment(uuid, text, bigint, text, text, text, timestamptz, text) to authenticated;

-- ---------------------------------------------------------------
-- 3. void_payment: koreksi salah input, bukan hapus data
-- ---------------------------------------------------------------
create or replace function public.void_payment(
  p_payment_id uuid,
  p_reason     text
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
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'ALASAN_WAJIB' using errcode = '22023';
  end if;

  select * into v_row from public.payments where id = p_payment_id for update;
  if not found then
    raise exception 'PEMBAYARAN_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  if v_row.status <> 'CONFIRMED' then
    raise exception 'PEMBAYARAN_TIDAK_AKTIF: status % tidak bisa dibatalkan', v_row.status
      using errcode = '22023';
  end if;

  update public.payments
     set status = 'VOID',
         voided_at = now(),
         void_reason = btrim(p_reason)
   where id = p_payment_id
  returning * into v_row;

  perform public.recompute_commission_internal(v_row.request_id);
  perform public.sync_request_payment_status(v_row.request_id);

  return v_row;
end;
$$;

revoke all on function public.void_payment(uuid, text) from public;
grant execute on function public.void_payment(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- 4. Backfill defensif: proyek yang sudah punya pembayaran penuh tapi
--    statusnya belum 'paid' (mis. diinput sebelum migration ini).
--    Tidak menyentuh proyek tanpa baris payments.
-- ---------------------------------------------------------------
do $$
declare
  v_id uuid;
begin
  for v_id in
    select distinct request_id from public.payments where status = 'CONFIRMED'
  loop
    perform public.sync_request_payment_status(v_id);
  end loop;
end;
$$;

-- ============ migration-analytics-source.sql ============

-- =============================================================
-- jokitugasit.my.id — Analytics window + sumber akuisisi
-- Jalankan SETELAH migration-payment-flow.sql.
--
-- Perbaikan:
--   1. analytics_overview(...) sebelumnya mengabaikan p_from/p_to untuk
--      omzet dan komisi (selalu all-time) sementara proyek difilter.
--      Sekarang semua metrik mengikuti periode yang sama.
--   2. Tambah kolom requests.source supaya bisa membandingkan kanal
--      (direct DM, admin share, referral, inbound website).
--   3. create_public_request mengisi source otomatis dari kode referral.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Kolom sumber akuisisi
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists source text;

do $$
begin
  alter table public.requests
    add constraint requests_source_valid check (
      source is null or source in ('DIRECT_DM','ADMIN_SHARE','REFERRAL','INBOUND','OTHER')
    );
exception when duplicate_object then null;
end $$;

-- Backfill jujur: semua request publik yang punya kode referral valid
-- dianggap REFERRAL, sisanya INBOUND (form website). Tidak mengarang
-- kanal yang tidak pernah tercatat.
update public.requests
   set source = case when referral_code is not null then 'REFERRAL' else 'INBOUND' end
 where source is null;

create index if not exists requests_source_idx on public.requests (source, created_at desc);

-- ---------------------------------------------------------------
-- 2. create_public_request: isi source dari kode referral
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

  select upper(trim(p_referral_code)) into v_ref
  from public.partners
  where referral_code = upper(trim(coalesce(p_referral_code, '')))
    and status = 'active';
  if not found then v_ref := null; end if;

  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, whatsapp, email, category, description,
        deadline, deadline_date, link, file_url, referral_code, source,
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
        case when v_ref is null then 'INBOUND' else 'REFERRAL' end,
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
-- 3. analytics_overview: satu window untuk semua metrik
-- ---------------------------------------------------------------
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
  windowed_payments as (
    select * from public.payments
    where status = 'CONFIRMED'
      and (p_from is null or coalesce(paid_at, created_at) >= p_from)
      and (p_to   is null or coalesce(paid_at, created_at) <  (p_to + 1))
  ),
  windowed_commissions as (
    select * from public.commissions
    where (p_from is null or created_at >= p_from)
      and (p_to   is null or created_at <  (p_to + 1))
  ),
  windowed_prospects as (
    select * from public.prospects
    where (p_from is null or created_at >= p_from)
      and (p_to   is null or created_at <  (p_to + 1))
  ),
  windowed_logs as (
    select * from public.outreach_logs
    where (p_from is null or sent_at >= p_from)
      and (p_to   is null or sent_at <  (p_to + 1))
  ),
  paid as (
    select coalesce(sum(amount), 0) as gross
    from windowed_payments
    where kind <> 'REFUND'
  ),
  commission_totals as (
    select
      coalesce(sum(amount) filter (where status = 'PAID'), 0)     as paid,
      coalesce(sum(amount) filter (where status = 'ELIGIBLE'), 0) as unpaid
    from windowed_commissions
  ),
  by_source as (
    select
      coalesce(r.source, 'OTHER') as source,
      count(distinct r.id) as projects,
      count(distinct r.id) filter (where r.status = 'paid') as completed,
      coalesce(sum(p.amount) filter (where p.kind <> 'REFUND'), 0) as gross
    from windowed_requests r
    left join public.payments p
      on p.request_id = r.id and p.status = 'CONFIRMED'
    group by coalesce(r.source, 'OTHER')
  )
  select jsonb_build_object(
    'target_accounts',    (select count(*) from public.target_accounts),
    'permission_granted', (select count(*) from public.target_accounts
                            where relationship_status = 'PERMISSION_GRANTED'),
    'prospects_total',    (select count(*) from windowed_prospects),
    'prospects_queue',    (select count(*) from windowed_prospects
                            where status in ('NEW','READY_TO_REVIEW')),
    'prospects_dnc',      (select count(*) from windowed_prospects where do_not_contact),
    'contacts_sent',      (select count(*) from windowed_logs where outcome = 'SENT'),
    'responses',          (select count(*) from windowed_logs
                            where outcome in ('REPLIED','INTERESTED_SERVICE',
                                              'INTERESTED_REFERRAL','NOT_INTERESTED')),
    'interested',         (select count(*) from windowed_logs
                            where outcome in ('INTERESTED_SERVICE','INTERESTED_REFERRAL')),
    'projects_total',     (select count(*) from windowed_requests),
    'projects_completed', (select count(*) from windowed_requests where status = 'paid'),
    'gross_confirmed',    (select gross from paid),
    'commission_paid',    (select paid from commission_totals),
    'commission_unpaid',  (select unpaid from commission_totals),
    'active_partners',    (select count(*) from public.partners where status = 'active'),
    'partners_with_deal', (select count(distinct partner_id) from windowed_commissions
                            where status in ('ELIGIBLE','PAID')),
    'source_breakdown',   coalesce(
      (select jsonb_agg(
                jsonb_build_object(
                  'source',    source,
                  'projects',  projects,
                  'completed', completed,
                  'gross',     gross
                ) order by projects desc, source
              )
         from by_source),
      '[]'::jsonb
    )
  ));
end;
$$;

revoke all on function public.analytics_overview(date, date) from public;
grant execute on function public.analytics_overview(date, date) to authenticated;

-- ============ migration-import-batches.sql ============

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

-- ============ migration-referral-integrity.sql ============

-- =============================================================
-- jokitugasit.my.id — Integritas referral
-- Jalankan SETELAH migration-import-batches.sql.
--
-- Mencegah self-referral: partner tidak mendapat komisi kalau nomor
-- WhatsApp klien sama dengan nomor WhatsApp partner (dinormalisasi:
-- buang non-digit, 0xxx -> 62xxx).
--
-- Guard ditegakkan di dua tempat:
--   1. create_public_request  -> kode tidak disimpan kalau self-referral
--   2. recompute_commission   -> tidak ada partner yang cocok, jadi
--      komisi tidak pernah dibuat walau kode sudah terlanjur tersimpan.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Normalisasi nomor telepon Indonesia
-- ---------------------------------------------------------------
create or replace function public.normalize_phone(p text)
returns text
language sql
immutable
as $$
  select case
    when d = '' then ''
    when left(d, 1) = '0' then '62' || substr(d, 2)
    when left(d, 2) = '62' then d
    else d
  end
  from (select regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g') as d) s;
$$;

revoke all on function public.normalize_phone(text) from public;
grant execute on function public.normalize_phone(text) to authenticated;

-- ---------------------------------------------------------------
-- 2. create_public_request: tolak atribusi ke nomor partner sendiri
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
  v_partner  public.partners%rowtype;
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

  select * into v_partner
  from public.partners
  where referral_code = upper(trim(coalesce(p_referral_code, '')))
    and status = 'active';

  if found then
    -- Self-referral: kode dibuang, bukan disimpan lalu dibatalkan diam-diam.
    if public.normalize_phone(v_partner.whatsapp) = public.normalize_phone(p_whatsapp) then
      v_ref := null;
    else
      v_ref := v_partner.referral_code;
    end if;
  else
    v_ref := null;
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, whatsapp, email, category, description,
        deadline, deadline_date, link, file_url, referral_code, source,
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
        case when v_ref is null then 'INBOUND' else 'REFERRAL' end,
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
-- 3. recompute_commission_internal: partner yang nomornya sama
--    dengan klien tidak pernah cocok
-- ---------------------------------------------------------------
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
    and status = 'active'
    and public.normalize_phone(whatsapp) <> public.normalize_phone(coalesce(v_req.whatsapp, ''));

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

-- ============ migration-data-rights.sql ============

-- =============================================================
-- jokitugasit.my.id — Data rights (hapus prospek + suppression)
-- Jalankan SETELAH migration-referral-integrity.sql.
--
-- Kenapa ada tabel suppression terpisah:
--   Menghapus baris prospek saja akan menghilangkan status
--   do-not-contact. Import berikutnya bisa memunculkan lagi orang yang
--   sudah minta dihapus. Jadi username disimpan minimal (tanpa nama,
--   kampus, atau nomor) di `prospect_suppressions`.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Daftar suppression (data minimal: username saja)
-- ---------------------------------------------------------------
create table if not exists public.prospect_suppressions (
  ig_username citext primary key
              check (ig_username ~ '^[a-z0-9._]{1,30}$'),
  reason      text,
  created_at  timestamptz not null default now(),
  created_by  uuid
);

alter table public.prospect_suppressions enable row level security;

drop policy if exists prospect_suppressions_engineer_all on public.prospect_suppressions;
create policy prospect_suppressions_engineer_all on public.prospect_suppressions
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

-- ---------------------------------------------------------------
-- 2. Hapus prospek, opsional masukkan ke suppression
-- ---------------------------------------------------------------
create or replace function public.delete_prospect(
  p_prospect_id uuid,
  p_reason      text,
  p_suppress    boolean default true
)
returns void
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

  -- Prospek DNC selalu disimpan di suppression: menghapusnya tidak boleh
  -- membuat orang yang menolak bisa diimpor ulang.
  if p_suppress or v_row.do_not_contact then
    insert into public.prospect_suppressions (ig_username, reason, created_by)
    values (v_row.ig_username, btrim(p_reason), auth.uid())
    on conflict (ig_username) do nothing;
  end if;

  -- outreach_logs ikut terhapus (on delete cascade);
  -- requests.prospect_id menjadi null (on delete set null).
  delete from public.prospects where id = p_prospect_id;
end;
$$;

revoke all on function public.delete_prospect(uuid, text, boolean) from public;
grant execute on function public.delete_prospect(uuid, text, boolean) to authenticated;

-- ---------------------------------------------------------------
-- 3. import_prospects: lewati username yang ada di suppression
--    (fungsi lama diganti; perilaku lain tidak berubah)
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

    -- Pernah dihapus atas permintaan pemilik data: jangan dibuat lagi.
    if exists (select 1 from public.prospect_suppressions where ig_username = v_username) then
      v_suppressed := v_suppressed + 1;
      continue;
    end if;

    select * into v_existing from public.prospects where ig_username = v_username;

    if found then
      v_dup_exist := v_dup_exist + 1;

      if v_existing.do_not_contact then
        v_suppressed := v_suppressed + 1;
        -- sengaja tidak mengubah apa pun: DNC harus tetap berlaku
        continue;
      end if;

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

-- ============ migration-project-details.sql ============

-- =============================================================
-- jokitugasit.my.id — Detail proyek + analytics per kampus
-- Jalankan SETELAH migration-data-rights.sql.
--
--   * requests.campus  -> dimensi kampus untuk proyek/omzet
--   * requests.stack   -> stack teknologi yang dipakai proyek
--   * analytics_overview & analytics_funnel menerima p_campus
--   * analytics_campuses() -> daftar kampus untuk dropdown
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Kolom baru (nullable, tidak mengubah data lama)
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists campus text,
  add column if not exists stack text;

create index if not exists requests_campus_idx on public.requests (campus, created_at desc);

-- ---------------------------------------------------------------
-- 2. Konversi prospek mengisi campus otomatis
-- ---------------------------------------------------------------
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
        status, quote_amount, source, prospect_id, campus
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
        p_prospect_id,
        v_prospect.campus
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

-- ---------------------------------------------------------------
-- 3. analytics_overview: tambah p_campus
-- ---------------------------------------------------------------
drop function if exists public.analytics_overview(date, date);

create or replace function public.analytics_overview(
  p_from   date default null,
  p_to     date default null,
  p_campus text default null
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
    select * from public.requests r
    where (p_from is null or r.created_at >= p_from)
      and (p_to   is null or r.created_at <  (p_to + 1))
      and (p_campus is null or r.campus = p_campus)
  ),
  windowed_payments as (
    select p.* from public.payments p
    join public.requests r on r.id = p.request_id
    where p.status = 'CONFIRMED'
      and (p_from is null or coalesce(p.paid_at, p.created_at) >= p_from)
      and (p_to   is null or coalesce(p.paid_at, p.created_at) <  (p_to + 1))
      and (p_campus is null or r.campus = p_campus)
  ),
  windowed_commissions as (
    select c.* from public.commissions c
    join public.requests r on r.id = c.request_id
    where (p_from is null or c.created_at >= p_from)
      and (p_to   is null or c.created_at <  (p_to + 1))
      and (p_campus is null or r.campus = p_campus)
  ),
  windowed_prospects as (
    select * from public.prospects
    where (p_from is null or created_at >= p_from)
      and (p_to   is null or created_at <  (p_to + 1))
      and (p_campus is null or campus = p_campus)
  ),
  windowed_logs as (
    select l.* from public.outreach_logs l
    join public.prospects pr on pr.id = l.prospect_id
    where (p_from is null or l.sent_at >= p_from)
      and (p_to   is null or l.sent_at <  (p_to + 1))
      and (p_campus is null or pr.campus = p_campus)
  ),
  paid as (
    select coalesce(sum(amount), 0) as gross
    from windowed_payments
    where kind <> 'REFUND'
  ),
  commission_totals as (
    select
      coalesce(sum(amount) filter (where status = 'PAID'), 0)     as paid,
      coalesce(sum(amount) filter (where status = 'ELIGIBLE'), 0) as unpaid
    from windowed_commissions
  ),
  by_source as (
    select
      coalesce(r.source, 'OTHER') as source,
      count(distinct r.id) as projects,
      count(distinct r.id) filter (where r.status = 'paid') as completed,
      coalesce(sum(p.amount) filter (where p.kind <> 'REFUND'), 0) as gross
    from windowed_requests r
    left join public.payments p
      on p.request_id = r.id and p.status = 'CONFIRMED'
    group by coalesce(r.source, 'OTHER')
  )
  select jsonb_build_object(
    'target_accounts',    (select count(*) from public.target_accounts
                            where p_campus is null or campus = p_campus),
    'permission_granted', (select count(*) from public.target_accounts
                            where relationship_status = 'PERMISSION_GRANTED'
                              and (p_campus is null or campus = p_campus)),
    'prospects_total',    (select count(*) from windowed_prospects),
    'prospects_queue',    (select count(*) from windowed_prospects
                            where status in ('NEW','READY_TO_REVIEW')),
    'prospects_dnc',      (select count(*) from windowed_prospects where do_not_contact),
    'contacts_sent',      (select count(*) from windowed_logs where outcome = 'SENT'),
    'responses',          (select count(*) from windowed_logs
                            where outcome in ('REPLIED','INTERESTED_SERVICE',
                                              'INTERESTED_REFERRAL','NOT_INTERESTED')),
    'interested',         (select count(*) from windowed_logs
                            where outcome in ('INTERESTED_SERVICE','INTERESTED_REFERRAL')),
    'projects_total',     (select count(*) from windowed_requests),
    'projects_completed', (select count(*) from windowed_requests where status = 'paid'),
    'gross_confirmed',    (select gross from paid),
    'commission_paid',    (select paid from commission_totals),
    'commission_unpaid',  (select unpaid from commission_totals),
    'active_partners',    (select count(*) from public.partners where status = 'active'),
    'partners_with_deal', (select count(distinct partner_id) from windowed_commissions
                            where status in ('ELIGIBLE','PAID')),
    'source_breakdown',   coalesce(
      (select jsonb_agg(
                jsonb_build_object(
                  'source',    source,
                  'projects',  projects,
                  'completed', completed,
                  'gross',     gross
                ) order by projects desc, source
              )
         from by_source),
      '[]'::jsonb
    )
  ));
end;
$$;

revoke all on function public.analytics_overview(date, date, text) from public;
grant execute on function public.analytics_overview(date, date, text) to authenticated;

-- ---------------------------------------------------------------
-- 4. analytics_funnel: tambah p_campus
-- ---------------------------------------------------------------
drop function if exists public.analytics_funnel(date, date);

create or replace function public.analytics_funnel(
  p_from   date default null,
  p_to     date default null,
  p_campus text default null
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
    select l.*
    from public.outreach_logs l
    join public.prospects pr on pr.id = l.prospect_id
    where (p_from is null or l.sent_at >= p_from)
      and (p_to   is null or l.sent_at <  (p_to + 1))
      and (p_campus is null or pr.campus = p_campus)
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
                    and (p_to is null or r.created_at < (p_to + 1))
                    and (p_campus is null or r.campus = p_campus)), 4
  order by 3;
end;
$$;

revoke all on function public.analytics_funnel(date, date, text) from public;
grant execute on function public.analytics_funnel(date, date, text) to authenticated;

-- ---------------------------------------------------------------
-- 5. Daftar kampus untuk dropdown dashboard
-- ---------------------------------------------------------------
create or replace function public.analytics_campuses()
returns table (campus text)
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
  select distinct s.c from (
    select r.campus as c from public.requests r where r.campus is not null
    union
    select p.campus as c from public.prospects p where p.campus is not null
    union
    select t.campus as c from public.target_accounts t where t.campus is not null
  ) s
  where btrim(s.c) <> ''
  order by 1;
end;
$$;

revoke all on function public.analytics_campuses() from public;
grant execute on function public.analytics_campuses() to authenticated;

-- ============ migration-hardening.sql ============

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

-- ============ migration-consent-guard.sql ============

-- =============================================================
-- jokitugasit.my.id — Consent & outreach eligibility (V4, Slice A)
-- Jalankan SETELAH migration-hardening.sql.
--
-- Memisahkan "pernah ditemukan" dari "boleh dihubungi":
--   consent_status: UNKNOWN / OPTED_IN / OPTED_OUT
--   contact_permission_source: dari mana izin/relasi berasal
--   outreach_eligibility(): keputusan per channel, bukan satu boolean
--
-- Additive & idempoten.
-- =============================================================

alter table public.prospects
  add column if not exists consent_status text not null default 'UNKNOWN',
  add column if not exists contact_permission_source text,
  add column if not exists consent_at timestamptz;

do $$
begin
  alter table public.prospects
    add constraint prospects_consent_valid
    check (consent_status in ('UNKNOWN','OPTED_IN','OPTED_OUT'));
exception when duplicate_object then null;
end $$;

do $$
begin
  alter table public.prospects
    add constraint prospects_consent_source_valid
    check (
      contact_permission_source is null
      or contact_permission_source in (
        'WEBSITE_FORM','INBOUND_IG_DM','ADMIN_PARTNER_SHARED_OPT_IN','MANUAL_CONTACT'
      )
    );
exception when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------
-- Backfill hanya untuk baris yang belum punya sumber izin.
-- Tidak menimpa keputusan manual pada re-run.
-- ---------------------------------------------------------------
update public.prospects
   set consent_status = case
         when do_not_contact then 'OPTED_OUT'
         when permission_basis = 'INBOUND_OPT_IN' then 'OPTED_IN'
         else 'UNKNOWN'
       end,
       contact_permission_source = case permission_basis
         when 'INBOUND_OPT_IN' then 'WEBSITE_FORM'
         when 'ADMIN_SHARED_LIST' then 'ADMIN_PARTNER_SHARED_OPT_IN'
         else 'MANUAL_CONTACT'
       end,
       consent_at = case
         when do_not_contact then coalesce(do_not_contact_at, now())
         when permission_basis = 'INBOUND_OPT_IN' then coalesce(first_seen_at, now())
         else null
       end
 where contact_permission_source is null;

-- ---------------------------------------------------------------
-- Trigger: jaga konsistensi DNC <-> consent.
-- Nama trigger sengaja "consent" agar berjalan SEBELUM
-- prospects_guard_dnc_trg (urutan alfabetis).
-- ---------------------------------------------------------------
create or replace function public.prospects_guard_consent()
returns trigger
language plpgsql
as $$
begin
  -- Isi sumber izin dari provenance saat baris baru dibuat / belum diisi.
  if new.contact_permission_source is null then
    new.contact_permission_source := case new.permission_basis
      when 'INBOUND_OPT_IN' then 'WEBSITE_FORM'
      when 'ADMIN_SHARED_LIST' then 'ADMIN_PARTNER_SHARED_OPT_IN'
      else 'MANUAL_CONTACT'
    end;
  end if;

  -- Import opt-in jelas -> OPTED_IN (hanya saat belum pernah diputuskan).
  if tg_op = 'INSERT'
     and new.permission_basis = 'INBOUND_OPT_IN'
     and new.consent_status = 'UNKNOWN' then
    new.consent_status := 'OPTED_IN';
    new.consent_at := coalesce(new.consent_at, now());
  end if;

  -- DNC selalu berarti opt-out.
  if new.do_not_contact then
    new.consent_status := 'OPTED_OUT';
    new.consent_at := coalesce(new.consent_at, new.do_not_contact_at, now());
  elsif new.consent_status = 'OPTED_OUT'
        and (tg_op = 'INSERT' or old.consent_status is distinct from 'OPTED_OUT') then
    -- Opt-out baru menyalakan DNC; trigger DNC yang mengatur status.
    -- Kalau baris sudah OPTED_OUT dan seseorang mencoba mematikan DNC,
    -- biarkan trigger DNC yang menolak (jangan ditutupi di sini).
    new.do_not_contact := true;
    new.consent_at := coalesce(new.consent_at, now());
  elsif new.consent_status = 'OPTED_IN' then
    new.consent_at := coalesce(new.consent_at, now());
  end if;

  return new;
end;
$$;

drop trigger if exists prospects_guard_consent_trg on public.prospects;
create trigger prospects_guard_consent_trg
  before insert or update on public.prospects
  for each row execute function public.prospects_guard_consent();

-- ---------------------------------------------------------------
-- Kelayakan per channel
-- ---------------------------------------------------------------
create or replace function public.outreach_eligibility(
  p_prospect_id uuid,
  p_channel     text default 'MANUAL_DM'
)
returns table (eligible boolean, reason text)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_channel not in ('MANUAL_DM','AUTOMATED_DM','INBOUND_REPLY','WHATSAPP') then
    raise exception 'CHANNEL_TIDAK_VALID' using errcode = '22023';
  end if;

  select * into v from public.prospects where id = p_prospect_id;
  if not found then
    return query select false, 'NOT_FOUND'::text;
    return;
  end if;

  if v.do_not_contact or v.consent_status = 'OPTED_OUT' then
    return query select false, 'OPTED_OUT'::text;
    return;
  end if;

  if p_channel = 'AUTOMATED_DM' and v.consent_status <> 'OPTED_IN' then
    return query select false, 'CONSENT_REQUIRED'::text;
    return;
  end if;

  return query select true, 'OK'::text;
end;
$$;

revoke all on function public.outreach_eligibility(uuid, text) from public;
grant execute on function public.outreach_eligibility(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- Ubah consent secara eksplisit (engineer)
-- ---------------------------------------------------------------
create or replace function public.set_prospect_consent(
  p_prospect_id uuid,
  p_status      text,
  p_source      text default 'MANUAL_CONTACT'
)
returns public.prospects
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if p_status not in ('UNKNOWN','OPTED_IN','OPTED_OUT') then
    raise exception 'STATUS_CONSENT_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_source not in ('WEBSITE_FORM','INBOUND_IG_DM','ADMIN_PARTNER_SHARED_OPT_IN','MANUAL_CONTACT') then
    raise exception 'SUMBER_IZIN_TIDAK_VALID' using errcode = '22023';
  end if;

  select * into v from public.prospects where id = p_prospect_id for update;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  if p_status = 'OPTED_IN' and v.do_not_contact then
    raise exception 'DNC_AKTIF: lepas status jangan-dihubungi dulu (dengan alasan)' using errcode = '42501';
  end if;

  update public.prospects
     set consent_status = p_status,
         contact_permission_source = p_source,
         consent_at = now(),
         do_not_contact = case when p_status = 'OPTED_OUT' then true else do_not_contact end,
         do_not_contact_at = case
           when p_status = 'OPTED_OUT' then coalesce(do_not_contact_at, now())
           else do_not_contact_at
         end
   where id = p_prospect_id
  returning * into v;

  return v;
end;
$$;

revoke all on function public.set_prospect_consent(uuid, text, text) from public;
grant execute on function public.set_prospect_consent(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------
-- Lepas DNC: reset consent ke UNKNOWN (bukan OPTED_IN diam-diam)
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
    status                = 'NEW',
    consent_status        = 'UNKNOWN',
    contact_permission_source = 'MANUAL_CONTACT',
    consent_at            = now()
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

-- ============ migration-campaigns.sql ============

-- =============================================================
-- jokitugasit.my.id — Campaign & distribution (V4, Slice B)
-- Jalankan SETELAH migration-consent-guard.sql.
--
--   campaign → target → event → attribution pada requests
--   Tanpa blast DM: campaign hanya alat ukur + materi + link.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Generator kode campaign
-- ---------------------------------------------------------------
create or replace function public.generate_campaign_code()
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
    v_code := 'CMP-';
    for v_i in 1..8 loop
      v_code := v_code || substr(v_alphabet, floor(random() * length(v_alphabet))::int + 1, 1);
    end loop;
    if not exists (select 1 from public.campaigns where code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception 'GAGAL_MEMBUAT_KODE_CAMPAIGN' using errcode = '23505';
end;
$$;

revoke all on function public.generate_campaign_code() from public;
grant execute on function public.generate_campaign_code() to authenticated;

-- ---------------------------------------------------------------
-- 2. Tabel campaign
-- ---------------------------------------------------------------
create table if not exists public.campaigns (
  id                uuid primary key default gen_random_uuid(),
  code              text unique not null default public.generate_campaign_code(),
  name              text not null,
  objective         text not null
                    check (objective in ('ADMIN_DISTRIBUTION','DIRECT_OUTREACH','REFERRAL','INBOUND')),
  channel           text not null
                    check (channel in ('INSTAGRAM_MANUAL_DM','IG_STORY_PARTNER','WHATSAPP_REFERRAL','WEBSITE_OPT_IN')),
  campus            text,
  cohort_year       int check (cohort_year between 1990 and 2036),
  status            text not null default 'DRAFT'
                    check (status in ('DRAFT','ACTIVE','PAUSED','COMPLETED')),
  starts_on         date,
  ends_on           date,
  cost_rupiah       bigint not null default 0 check (cost_rupiah >= 0),
  time_value_rupiah bigint not null default 0 check (time_value_rupiah >= 0),
  owner             uuid,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index if not exists campaigns_status_idx on public.campaigns (status, created_at desc);
create index if not exists campaigns_code_idx on public.campaigns (code);

create table if not exists public.campaign_targets (
  id                uuid primary key default gen_random_uuid(),
  campaign_id       uuid not null references public.campaigns (id) on delete cascade,
  target_account_id uuid references public.target_accounts (id) on delete cascade,
  prospect_id       uuid references public.prospects (id) on delete cascade,
  status            text not null default 'PLANNED'
                    check (status in ('PLANNED','CONTACTED','PERMISSION_GRANTED','DECLINED','CONVERTED')),
  notes             text,
  created_at        timestamptz not null default now(),
  constraint campaign_targets_one check (target_account_id is not null or prospect_id is not null)
);

create unique index if not exists campaign_targets_account_uniq
  on public.campaign_targets (campaign_id, target_account_id)
  where target_account_id is not null;
create unique index if not exists campaign_targets_prospect_uniq
  on public.campaign_targets (campaign_id, prospect_id)
  where prospect_id is not null;

create table if not exists public.campaign_assets (
  id            uuid primary key default gen_random_uuid(),
  campaign_id   uuid not null references public.campaigns (id) on delete cascade,
  name          text not null,
  kind          text not null default 'COPY' check (kind in ('COPY','LINK','TEMPLATE')),
  body          text,
  template_id   uuid references public.dm_templates (id) on delete set null,
  referral_code text,
  variant       text check (variant in ('A','B')),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

create index if not exists campaign_assets_campaign_idx
  on public.campaign_assets (campaign_id, is_active);

create table if not exists public.campaign_events (
  id          uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.campaigns (id) on delete cascade,
  event_type  text not null
              check (event_type in ('PAGE_VISIT','OPT_IN','LINK_CLICK','INQUIRY',
                                    'WHATSAPP_CLICK','CONSULTATION','DEAL','PAID','REFERRAL_PAID')),
  request_id  uuid references public.requests (id) on delete cascade,
  prospect_id uuid references public.prospects (id) on delete set null,
  occurred_at timestamptz not null default now(),
  metadata    jsonb not null default '{}'::jsonb
);

create index if not exists campaign_events_campaign_idx
  on public.campaign_events (campaign_id, event_type, occurred_at desc);
create unique index if not exists campaign_events_request_uniq
  on public.campaign_events (campaign_id, request_id, event_type)
  where request_id is not null;

-- ---------------------------------------------------------------
-- 3. Attribution pada requests
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists campaign_id uuid references public.campaigns (id) on delete set null,
  add column if not exists utm_source text,
  add column if not exists utm_medium text,
  add column if not exists utm_campaign text,
  add column if not exists utm_content text,
  add column if not exists utm_term text,
  add column if not exists attribution_at timestamptz;

create index if not exists requests_campaign_idx on public.requests (campaign_id, created_at desc);

-- Attribution tidak boleh diubah setelah terkunci (first valid touch).
create or replace function public.requests_guard_attribution()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and old.attribution_at is not null
     and new.campaign_id is distinct from old.campaign_id
     and coalesce(current_setting('app.attribution_override', true), 'off') <> 'on' then
    raise exception 'ATTRIBUTION_TERKUNCI: campaign proyek tidak bisa diubah'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists requests_guard_attribution_trg on public.requests;
create trigger requests_guard_attribution_trg
  before update on public.requests
  for each row execute function public.requests_guard_attribution();

-- ---------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------
alter table public.campaigns        enable row level security;
alter table public.campaign_targets enable row level security;
alter table public.campaign_assets  enable row level security;
alter table public.campaign_events  enable row level security;

drop policy if exists campaigns_engineer_all on public.campaigns;
create policy campaigns_engineer_all on public.campaigns
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists campaign_targets_engineer_all on public.campaign_targets;
create policy campaign_targets_engineer_all on public.campaign_targets
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists campaign_assets_engineer_all on public.campaign_assets;
create policy campaign_assets_engineer_all on public.campaign_assets
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

drop policy if exists campaign_events_engineer_all on public.campaign_events;
create policy campaign_events_engineer_all on public.campaign_events
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

-- ---------------------------------------------------------------
-- 5. create_public_request: campaign + UTM (first touch)
--    Signature lama (10 arg) diganti; argumen baru punya default.
-- ---------------------------------------------------------------
drop function if exists public.create_public_request(
  text, text, text, text, text, date, text, text, text, text);

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
  p_referral_code text default null,
  p_campaign_code text default null,
  p_utm_source    text default null,
  p_utm_medium    text default null,
  p_utm_campaign  text default null,
  p_utm_content   text default null,
  p_utm_term      text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_no  text;
  v_ref       text;
  v_partner   public.partners%rowtype;
  v_campaign  public.campaigns%rowtype;
  v_campaign_id uuid;
  v_source    text := 'INBOUND';
  v_attempt   int := 0;
  v_has_attr  boolean := false;
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

  -- Referral (guard self-referral tetap berlaku)
  select * into v_partner
  from public.partners
  where referral_code = upper(trim(coalesce(p_referral_code, '')))
    and status = 'active';

  if found then
    if public.normalize_phone(v_partner.whatsapp) = public.normalize_phone(p_whatsapp) then
      v_ref := null;
    else
      v_ref := v_partner.referral_code;
    end if;
  else
    v_ref := null;
  end if;

  -- Campaign: hanya kode aktif yang diakui.
  select * into v_campaign
  from public.campaigns
  where code = upper(trim(coalesce(p_campaign_code, '')))
    and status = 'ACTIVE';

  if found then
    v_campaign_id := v_campaign.id;
  end if;

  if v_ref is not null then
    v_source := 'REFERRAL';
  elsif v_campaign_id is not null then
    v_source := case v_campaign.objective
      when 'ADMIN_DISTRIBUTION' then 'ADMIN_SHARE'
      when 'DIRECT_OUTREACH'    then 'DIRECT_DM'
      when 'REFERRAL'           then 'REFERRAL'
      else 'INBOUND'
    end;
  end if;

  v_has_attr := v_ref is not null or v_campaign_id is not null
    or nullif(btrim(coalesce(p_utm_source, '')), '') is not null
    or nullif(btrim(coalesce(p_utm_medium, '')), '') is not null
    or nullif(btrim(coalesce(p_utm_campaign, '')), '') is not null;

  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, whatsapp, email, category, description,
        deadline, deadline_date, link, file_url, referral_code, source,
        campaign_id, utm_source, utm_medium, utm_campaign, utm_content, utm_term,
        attribution_at, status, quote_amount, internal_notes
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
        v_source,
        v_campaign_id,
        nullif(btrim(coalesce(p_utm_source, '')), ''),
        nullif(btrim(coalesce(p_utm_medium, '')), ''),
        nullif(btrim(coalesce(p_utm_campaign, '')), ''),
        nullif(btrim(coalesce(p_utm_content, '')), ''),
        nullif(btrim(coalesce(p_utm_term, '')), ''),
        case when v_has_attr then now() end,
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
  text, text, text, text, text, date, text, text, text, text, text, text, text, text, text, text
) from public;
grant execute on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text, text, text, text, text, text, text
) to anon, authenticated;

-- ---------------------------------------------------------------
-- 6. Resolusi kode campaign untuk UI publik
-- ---------------------------------------------------------------
create or replace function public.resolve_campaign(p_code text)
returns table (code text, name text, objective text, channel text)
language sql
stable
security definer
set search_path = public
as $$
  select c.code, c.name, c.objective, c.channel
  from public.campaigns c
  where c.code = upper(btrim(coalesce(p_code, '')))
    and c.status = 'ACTIVE'
  limit 1;
$$;

revoke all on function public.resolve_campaign(text) from public;
grant execute on function public.resolve_campaign(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 7. Event otomatis: inquiry, deal, paid, referral_paid
-- ---------------------------------------------------------------
create or replace function public.requests_campaign_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.campaign_id is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    insert into public.campaign_events (campaign_id, event_type, request_id, occurred_at)
    values (new.campaign_id, 'INQUIRY', new.id, new.created_at)
    on conflict do nothing;
  end if;

  if tg_op = 'UPDATE'
     and new.status = 'paid'
     and old.status is distinct from 'paid' then
    insert into public.campaign_events (campaign_id, event_type, request_id)
    values (new.campaign_id, 'PAID', new.id)
    on conflict do nothing;
  end if;

  if tg_op = 'UPDATE'
     and new.status in ('working','review','done','paid')
     and old.status in ('new','consultation') then
    insert into public.campaign_events (campaign_id, event_type, request_id)
    values (new.campaign_id, 'DEAL', new.id)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists requests_campaign_events_trg on public.requests;
create trigger requests_campaign_events_trg
  after insert or update of status on public.requests
  for each row execute function public.requests_campaign_events();

create or replace function public.commissions_campaign_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_campaign uuid;
begin
  if new.status <> 'PAID' or old.status = 'PAID' then
    return new;
  end if;

  select campaign_id into v_campaign from public.requests where id = new.request_id;
  if v_campaign is null then
    return new;
  end if;

  insert into public.campaign_events (campaign_id, event_type, request_id, metadata)
  values (v_campaign, 'REFERRAL_PAID', new.request_id,
          jsonb_build_object('commission_id', new.id, 'amount', new.amount))
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists commissions_campaign_events_trg on public.commissions;
create trigger commissions_campaign_events_trg
  after update of status on public.commissions
  for each row execute function public.commissions_campaign_events();

-- ---------------------------------------------------------------
-- 8. Analitik campaign (termasuk CAC)
-- ---------------------------------------------------------------
create or replace function public.analytics_campaigns(
  p_from date default null,
  p_to   date default null
)
returns table (
  campaign_id      uuid,
  code             text,
  name             text,
  objective        text,
  channel          text,
  status           text,
  targets          bigint,
  inquiries        bigint,
  deals            bigint,
  paid_clients     bigint,
  gross            bigint,
  commission_paid  bigint,
  cost             bigint,
  cac              bigint
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
    c.id, c.code, c.name, c.objective, c.channel, c.status,
    (select count(*) from public.campaign_targets t where t.campaign_id = c.id),
    (select count(*) from public.campaign_events e
      where e.campaign_id = c.id and e.event_type = 'INQUIRY'
        and (p_from is null or e.occurred_at >= p_from)
        and (p_to is null or e.occurred_at < (p_to + 1))),
    (select count(*) from public.campaign_events e
      where e.campaign_id = c.id and e.event_type = 'DEAL'
        and (p_from is null or e.occurred_at >= p_from)
        and (p_to is null or e.occurred_at < (p_to + 1))),
    (select count(distinct e.request_id) from public.campaign_events e
      where e.campaign_id = c.id and e.event_type = 'PAID'
        and (p_from is null or e.occurred_at >= p_from)
        and (p_to is null or e.occurred_at < (p_to + 1))),
    coalesce((select sum(p.amount)::bigint from public.payments p
      join public.requests r on r.id = p.request_id
      where r.campaign_id = c.id and p.status = 'CONFIRMED' and p.kind <> 'REFUND'
        and (p_from is null or coalesce(p.paid_at, p.created_at) >= p_from)
        and (p_to is null or coalesce(p.paid_at, p.created_at) < (p_to + 1))), 0),
    coalesce((select sum(cm.amount)::bigint from public.commissions cm
      join public.requests r on r.id = cm.request_id
      where r.campaign_id = c.id and cm.status = 'PAID'
        and (p_from is null or cm.created_at >= p_from)
        and (p_to is null or cm.created_at < (p_to + 1))), 0),
    (c.cost_rupiah + c.time_value_rupiah),
    case
      when (select count(distinct e.request_id) from public.campaign_events e
            where e.campaign_id = c.id and e.event_type = 'PAID'
              and (p_from is null or e.occurred_at >= p_from)
              and (p_to is null or e.occurred_at < (p_to + 1))) > 0
      then ((c.cost_rupiah + c.time_value_rupiah) /
            (select count(distinct e.request_id) from public.campaign_events e
             where e.campaign_id = c.id and e.event_type = 'PAID'
               and (p_from is null or e.occurred_at >= p_from)
               and (p_to is null or e.occurred_at < (p_to + 1))))
      else null
    end
  from public.campaigns c
  where (p_from is null or c.created_at >= p_from)
    and (p_to is null or c.created_at < (p_to + 1))
  order by inquiries desc, c.created_at desc;
end;
$$;

revoke all on function public.analytics_campaigns(date, date) from public;
grant execute on function public.analytics_campaigns(date, date) to authenticated;

-- ============ migration-internal-platform.sql ============

-- =============================================================
-- jokitugasit.my.id — Internal Automation Platform
-- Migration: migration-internal-platform.sql
--
-- ADDITIVE ONLY. Tidak ada drop table, tidak ada rename kolom,
-- tidak ada perubahan signature RPC yang sudah ada.
-- Semua kolom baru nullable atau punya default.
--
-- Jalankan SETELAH semua migrasi sebelumnya:
--   schema.sql -> DEPLOY-ALL-IN-ONE.sql -> migration-*.sql
--
-- Idempoten: aman dijalankan berulang kali.
-- =============================================================

-- -------------------------------------------------------------
-- 0. Guard: butuh is_engineer() dari DEPLOY-ALL-IN-ONE.sql
-- -------------------------------------------------------------
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

-- -------------------------------------------------------------
-- 1. campuses — hierarki geografis & akademik
--    Brief M2: province, city, university, faculty,
--    study_program, cohort, community, contact, consent.
-- -------------------------------------------------------------
create table if not exists public.campuses (
  id                  uuid primary key default gen_random_uuid(),

  province            text not null,
  city                text,
  university          text not null,
  faculty             text,
  study_program       text,
  cohort_year         int check (cohort_year between 1990 and 2040),

  -- Tautan ke akun organisasi mahasiswa publik (target_accounts).
  -- Nullable: kampus boleh tercatat sebelum akunnya ditemukan.
  community_account_id uuid references public.target_accounts (id) on delete set null,
  community_name       text,
  community_type       text
                       check (community_type is null or community_type in
                         ('BEM','HMJ','HIMA','UKM','ANGKATAN','KOMUNITAS','LAINNYA')),

  -- Kontak yang memberi izin. Jangan simpan akun pribadi tanpa izin.
  authorized_contact_name text,
  authorized_contact_role text,
  authorized_contact_ref  text,        -- username/email/WA yang diizinkan kontak

  -- Consent & provenance (brief M2: consent tracking + provenance)
  consent_status      text not null default 'UNKNOWN'
                      check (consent_status in
                        ('UNKNOWN','REQUESTED','GRANTED','DECLINED','WITHDRAWN')),
  consent_recorded_at timestamptz,
  provenance          text not null default 'MANUAL'
                      check (provenance in
                        ('MANUAL','PUBLIC_DIRECTORY','EVENT','REFERRAL','CSV_IMPORT','PARTNER')),
  provenance_ref      text,            -- URL / nama event / file import
  source_verified_at  timestamptz,

  relationship_status text not null default 'NEW'
                      check (relationship_status in
                        ('NEW','CONTACTED','RESPONDED','PARTNERED','DORMANT','DECLINED')),

  tags                text[] not null default '{}',
  notes               text,

  created_by          uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),

  -- Dedup: satu universitas + fakultas + prodi + kohort = satu baris.
  constraint campuses_identity_unique
    unique (university, faculty, study_program, cohort_year)
);

comment on table public.campuses is
  'Direktori kampus nasional. Hanya organisasi/akun publik; tidak menyimpan akun pribadi tanpa izin.';

create index if not exists campuses_province_idx on public.campuses (province);
create index if not exists campuses_university_idx on public.campuses (university);
create index if not exists campuses_consent_idx on public.campuses (consent_status);
create index if not exists campuses_tags_idx on public.campuses using gin (tags);

-- -------------------------------------------------------------
-- 2. leads — pipeline penjualan, TERPISAH dari eligibility
--    Brief M5: eligibility (prospects) != sales status (leads).
-- -------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'lead_stage') then
    create type public.lead_stage as enum (
      'NEW','RESEARCHING','ELIGIBLE_CONTACT','CONTACTED','REPLIED',
      'INTERESTED','QUALIFIED','CLIENT','PARTNER',
      'NOT_INTERESTED','DO_NOT_CONTACT','CLOSED'
    );
  end if;
end $$;

create table if not exists public.leads (
  id              uuid primary key default gen_random_uuid(),

  -- Sumber & relasi
  source          text not null default 'MANUAL'
                  check (source in
                    ('MANUAL','INSTAGRAM','REFERRAL','INBOUND_FORM','CAMPAIGN','CAMPUS_EVENT','PARTNER')),
  campaign_id     uuid references public.campaigns (id) on delete set null,
  campus_id       uuid references public.campuses (id) on delete set null,
  -- Prospek outreach yang jadi asal lead. Nullable: lead boleh datang
  -- dari inbound tanpa prospek IG.
  prospect_id     uuid references public.prospects (id) on delete set null,
  request_id      uuid references public.requests (id) on delete set null,
  partner_id      uuid references public.partners (id) on delete set null,

  -- Identitas kontak
  display_name    text not null,
  organization    text,
  contact_channel text check (contact_channel is null or contact_channel in
                    ('INSTAGRAM','WHATSAPP','EMAIL','PHONE','OTHER')),
  contact_ref     text,               -- @username / nomor / email

  stage           public.lead_stage not null default 'NEW',
  owner_id        uuid references public.profiles (id) on delete set null,

  -- Prioritas kerja & jabatan kontak (dipakai Kanban/table & drawer).
  priority        text not null default 'MEDIUM'
                  check (priority in ('LOW','MEDIUM','HIGH','URGENT')),
  role_title      text,

  interest        text,
  value_estimate  numeric check (value_estimate is null or value_estimate >= 0),
  currency        text not null default 'IDR',

  next_action_at  timestamptz,
  last_contact_at timestamptz,
  notes           text,

  -- Dedup lunak: satu kontak per channel per organisasi.
  dedupe_key      text generated always as (
                    lower(coalesce(contact_ref,'')) || '|' || lower(coalesce(organization,''))
                  ) stored,

  created_by      uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.leads is
  'Pipeline penjualan. Status eligibility outreach tetap di public.prospects.';

create index if not exists leads_stage_idx on public.leads (stage);
create index if not exists leads_owner_idx on public.leads (owner_id);
create index if not exists leads_campaign_idx on public.leads (campaign_id);
create index if not exists leads_campus_idx on public.leads (campus_id);
create index if not exists leads_next_action_idx on public.leads (next_action_at);
create index if not exists leads_dedupe_idx on public.leads (dedupe_key);

-- -------------------------------------------------------------
-- 3. lead_activities — timeline per lead (brief M5)
-- -------------------------------------------------------------
create table if not exists public.lead_activities (
  id          uuid primary key default gen_random_uuid(),
  lead_id     uuid not null references public.leads (id) on delete cascade,
  kind        text not null default 'NOTE'
              check (kind in ('NOTE','STAGE_CHANGE','CONTACT','TASK','REMINDER','MESSAGE','SYSTEM')),
  body        text,
  from_stage  public.lead_stage,
  to_stage    public.lead_stage,
  actor_id    uuid references public.profiles (id) on delete set null,
  metadata    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists lead_activities_lead_idx on public.lead_activities (lead_id, created_at desc);

-- -------------------------------------------------------------
-- 4. projects + tasks + milestones (brief M7)
-- -------------------------------------------------------------
create table if not exists public.projects (
  id            uuid primary key default gen_random_uuid(),
  project_no    text unique,
  name          text not null,
  client_name   text,
  client_contact text,

  request_id    uuid references public.requests (id) on delete set null,
  lead_id       uuid references public.leads (id) on delete set null,
  partner_id    uuid references public.partners (id) on delete set null,
  campaign_id   uuid references public.campaigns (id) on delete set null,

  category      text,
  scope         text,
  status        text not null default 'PLANNING'
                check (status in
                  ('INQUIRY','QUOTED','PLANNING','IN_PROGRESS','REVIEW','DELIVERED','CLOSED','CANCELLED')),
  priority      text not null default 'MEDIUM'
                check (priority in ('LOW','MEDIUM','HIGH','URGENT')),

  budget        numeric check (budget is null or budget >= 0),
  currency      text not null default 'IDR',

  start_date    date,
  due_date      date,
  delivered_at  timestamptz,
  progress_pct  int not null default 0 check (progress_pct between 0 and 100),

  owner_id      uuid references public.profiles (id) on delete set null,
  notes         text,

  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists projects_status_idx on public.projects (status);
create index if not exists projects_due_idx on public.projects (due_date);
create index if not exists projects_lead_idx on public.projects (lead_id);

create table if not exists public.project_tasks (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references public.projects (id) on delete cascade,
  title       text not null,
  detail      text,
  status      text not null default 'TODO'
              check (status in ('TODO','DOING','BLOCKED','DONE')),
  priority    text not null default 'MEDIUM'
              check (priority in ('LOW','MEDIUM','HIGH','URGENT')),
  due_date    date,
  assignee_id uuid references public.profiles (id) on delete set null,
  position    int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists project_tasks_project_idx on public.project_tasks (project_id, position);

create table if not exists public.project_milestones (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references public.projects (id) on delete cascade,
  title       text not null,
  due_date    date,
  reached_at  timestamptz,
  amount      numeric,
  position    int not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists project_milestones_project_idx on public.project_milestones (project_id, position);

-- -------------------------------------------------------------
-- 5. referral_attributions — anti duplikasi atribusi (brief M6)
-- -------------------------------------------------------------
create table if not exists public.referral_attributions (
  id                  uuid primary key default gen_random_uuid(),
  partner_id          uuid not null references public.partners (id) on delete restrict,
  referral_code       text not null,
  lead_id             uuid references public.leads (id) on delete set null,
  project_id          uuid references public.projects (id) on delete set null,
  request_id          uuid references public.requests (id) on delete set null,
  status              text not null default 'ATTRIBUTED'
                      check (status in ('ATTRIBUTED','QUALIFIED','CONVERTED','REVERSED','REJECTED')),
  verified_payment_id uuid references public.payments (id) on delete set null,
  note                text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- Satu request hanya boleh diatribusikan ke satu partner (cegah double-claim).
create unique index if not exists referral_attributions_request_unique
  on public.referral_attributions (request_id)
  where request_id is not null;
create unique index if not exists referral_attributions_project_unique
  on public.referral_attributions (project_id)
  where project_id is not null;

create index if not exists referral_attributions_partner_idx
  on public.referral_attributions (partner_id, status);

-- -------------------------------------------------------------
-- 6. Workflow engine (brief M9)
-- -------------------------------------------------------------
create table if not exists public.workflow_definitions (
  id            uuid primary key default gen_random_uuid(),
  event_key     text not null unique,
  name          text not null,
  description   text,
  enabled       boolean not null default true,
  conditions    jsonb not null default '{}'::jsonb,
  actions       jsonb not null default '[]'::jsonb,
  max_attempts  int not null default 3 check (max_attempts between 1 and 10),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.workflow_runs (
  id              uuid primary key default gen_random_uuid(),
  definition_id   uuid references public.workflow_definitions (id) on delete set null,
  event_key       text not null,
  status          text not null default 'PENDING'
                  check (status in ('PENDING','RUNNING','SUCCEEDED','FAILED','SKIPPED')),
  attempts        int not null default 0,
  payload         jsonb not null default '{}'::jsonb,
  result          jsonb,
  error           text,
  -- Idempotensi: satu event + subject hanya dieksekusi sekali.
  idempotency_key text unique,
  started_at      timestamptz,
  finished_at     timestamptz,
  created_at      timestamptz not null default now()
);

-- Log per langkah eksekusi workflow (dibaca Automation Center).
create table if not exists public.workflow_run_logs (
  id         uuid primary key default gen_random_uuid(),
  run_id     uuid not null references public.workflow_runs (id) on delete cascade,
  level      text not null default 'INFO' check (level in ('INFO','WARN','ERROR')),
  message    text not null,
  meta       jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists workflow_run_logs_run_idx
  on public.workflow_run_logs (run_id, created_at);
create index if not exists workflow_runs_status_idx on public.workflow_runs (status, created_at desc);
create index if not exists workflow_runs_event_idx on public.workflow_runs (event_key, created_at desc);

-- -------------------------------------------------------------
-- 7. crm_tasks + audit_logs
-- -------------------------------------------------------------
create table if not exists public.crm_tasks (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  detail      text,
  status      text not null default 'OPEN'
              check (status in ('OPEN','IN_PROGRESS','DONE','CANCELLED')),
  priority    text not null default 'MEDIUM'
              check (priority in ('LOW','MEDIUM','HIGH','URGENT')),
  due_at      timestamptz,
  lead_id     uuid references public.leads (id) on delete cascade,
  project_id  uuid references public.projects (id) on delete cascade,
  assignee_id uuid references public.profiles (id) on delete set null,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists crm_tasks_status_idx on public.crm_tasks (status, due_at);
create index if not exists crm_tasks_lead_idx on public.crm_tasks (lead_id);

create table if not exists public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid references public.profiles (id) on delete set null,
  table_name  text not null,
  row_id      text,
  action      text not null check (action in ('INSERT','UPDATE','DELETE','APPROVE','REJECT','EXPORT','LOGIN')),
  diff        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists audit_logs_table_idx on public.audit_logs (table_name, created_at desc);
create index if not exists audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);

-- -------------------------------------------------------------
-- 8. Kolom aditif pada tabel lama (nullable, aman)
-- -------------------------------------------------------------
alter table public.target_accounts
  add column if not exists campus_id uuid references public.campuses (id) on delete set null;
alter table public.prospects
  add column if not exists campus_id uuid references public.campuses (id) on delete set null;
alter table public.prospects
  add column if not exists lead_id uuid references public.leads (id) on delete set null;
alter table public.requests
  add column if not exists project_id uuid references public.projects (id) on delete set null;
alter table public.payments
  add column if not exists project_id uuid references public.projects (id) on delete set null;

create index if not exists target_accounts_campus_idx on public.target_accounts (campus_id);
create index if not exists prospects_campus_idx on public.prospects (campus_id);
create index if not exists payments_project_idx on public.payments (project_id);

-- -------------------------------------------------------------
-- 9. updated_at trigger (satu fungsi, dipakai ulang)
-- -------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'campuses','leads','projects','project_tasks','referral_attributions','workflow_definitions','crm_tasks'
  ] loop
    execute format('drop trigger if exists %I_touch on public.%I', t, t);
    execute format(
      'create trigger %I_touch before update on public.%I
       for each row execute function public.touch_updated_at()', t, t
    );
  end loop;
end $$;

-- -------------------------------------------------------------
-- 10. RLS — semua tabel baru engineer-only
--     (partner hanya baca via RPC terbatas, bukan tabel langsung)
-- -------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'campuses','leads','lead_activities','projects','project_tasks',
    'project_milestones','referral_attributions','workflow_definitions',
    'workflow_runs','workflow_run_logs','crm_tasks'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I_engineer_all on public.%I', t, t);
    execute format(
      'create policy %I_engineer_all on public.%I
       for all to authenticated
       using (public.is_engineer())
       with check (public.is_engineer())', t, t
    );
  end loop;
end $$;

-- audit_logs: engineer boleh baca, hanya server yang menulis
-- RLS wajib diaktifkan dulu; tanpa ini policy di bawah tidak berlaku sama sekali.
alter table public.audit_logs enable row level security;
drop policy if exists audit_logs_engineer_read on public.audit_logs;
create policy audit_logs_engineer_read on public.audit_logs
  for select to authenticated using (public.is_engineer());

-- -------------------------------------------------------------
-- 11. Seed workflow definitions (idempoten)
-- -------------------------------------------------------------
insert into public.workflow_definitions (event_key, name, description, actions)
values
  ('inquiry.created', 'Inquiry baru → lead + task admin',
   'Setiap inquiry masuk membuat lead tahap NEW dan task tindak lanjut.',
   '[{"type":"create_lead"},{"type":"create_admin_task"}]'::jsonb),
  ('lead.stage_changed', 'Lead pindah tahap → update analitik pipeline',
   'Mencatat perubahan tahap dan memperbarui agregat pipeline.',
   '[{"type":"log_stage"},{"type":"refresh_pipeline_stats"}]'::jsonb),
  ('partner.approved', 'Partner disetujui → buat kode referral',
   'Menghasilkan kode referral unik saat partner berstatus aktif.',
   '[{"type":"generate_referral_code"}]'::jsonb),
  ('payment.verified', 'Pembayaran terverifikasi → hitung komisi',
   'Menghitung komisi 10% dari pendapatan bersih yang terverifikasi.',
   '[{"type":"compute_commission"}]'::jsonb),
  ('payment.refunded', 'Refund → balik / hitung ulang komisi',
   'Membalik komisi terkait pembayaran yang di-refund.',
   '[{"type":"reverse_commission"}]'::jsonb),
  ('project.deadline_soon', 'Deadline proyek mendekat → tampilkan pengingat',
   'Menandai proyek yang jatuh tempo dalam 3 hari.',
   '[{"type":"create_reminder"}]'::jsonb),
  ('instagram.reply_received', 'Balasan IG (opt-in) → update timeline lead',
   'Menambahkan aktivitas balasan ke timeline lead terkait.',
   '[{"type":"append_lead_activity"}]'::jsonb),
  ('contact.opted_out', 'Kontak opt-out → hentikan pengiriman',
   'Menambahkan suppression agar tidak ada pesan berikutnya.',
   '[{"type":"suppress_contact"}]'::jsonb),
  ('commission.approved', 'Komisi disetujui → buat task payout',
   'Membuat task pembayaran komisi untuk admin.',
   '[{"type":"create_payout_task"}]'::jsonb)
on conflict (event_key) do nothing;

-- -------------------------------------------------------------
-- 12. RPC: dashboard KPI nyata (tidak ada angka karangan)
--     Semua nilai dihitung dari baris yang benar-benar ada.
-- -------------------------------------------------------------
create or replace function public.get_internal_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if not public.is_engineer() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total_campuses',       (select count(*) from public.campuses),
    'opted_in_prospects',   (select count(*) from public.prospects
                              where do_not_contact = false
                                and status not in ('DO_NOT_CONTACT')),
    'active_campaigns',     (select count(*) from public.campaigns where status = 'ACTIVE'),
    'total_campaigns',      (select count(*) from public.campaigns),
    'responses',            (select count(*) from public.lead_activities where kind = 'MESSAGE'),
    'qualified_leads',      (select count(*) from public.leads where stage in ('QUALIFIED','CLIENT','PARTNER')),
    'total_leads',          (select count(*) from public.leads),
    'new_clients',          (select count(*) from public.leads where stage = 'CLIENT'),
    'active_projects',      (select count(*) from public.projects
                              where status in ('PLANNING','IN_PROGRESS','REVIEW')),
    'verified_revenue',     coalesce((select sum(amount) from public.payments where status = 'CONFIRMED'), 0),
    'pending_commissions',  coalesce((select sum(amount) from public.commissions where status in ('PENDING','ELIGIBLE')), 0),
    'paid_commissions',     coalesce((select sum(amount) from public.commissions where status = 'PAID'), 0),
    'referral_conversions', (select count(*) from public.referral_attributions where status = 'CONVERTED'),
    'total_partners',       (select count(*) from public.partners where status = 'active'),
    'tasks_due',            (select count(*) from public.crm_tasks
                              where status <> 'DONE' and due_at is not null and due_at <= now() + interval '7 days'),
    'open_tasks',           (select count(*) from public.crm_tasks where status <> 'DONE'),
    'failed_workflows',     (select count(*) from public.workflow_runs where status = 'FAILED')
  ) into v;

  return v;
end;
$$;

-- -------------------------------------------------------------
-- 13. RPC: tren 30 hari (lead & revenue) dari data nyata
-- -------------------------------------------------------------
create or replace function public.get_internal_trends(p_days int default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if not public.is_engineer() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  with days as (
    select generate_series(
      (current_date - (p_days - 1))::timestamp,
      current_date::timestamp,
      interval '1 day'
    )::date as d
  ),
  leads_by_day as (
    select created_at::date as d, count(*)::int as n
    from public.leads
    where created_at >= current_date - (p_days - 1)
    group by 1
  ),
  revenue_by_day as (
    select coalesce(paid_at, created_at)::date as d, coalesce(sum(amount),0) as amt
    from public.payments
    where status = 'CONFIRMED'
      and coalesce(paid_at, created_at) >= current_date - (p_days - 1)
    group by 1
  )
  select jsonb_agg(jsonb_build_object(
    'date',  days.d,
    'leads', coalesce(l.n, 0),
    'revenue', coalesce(r.amt, 0)
  ) order by days.d)
  into v
  from days
  left join leads_by_day l on l.d = days.d
  left join revenue_by_day r on r.d = days.d;

  return coalesce(v, '[]'::jsonb);
end;
$$;

-- -------------------------------------------------------------
-- 14. RPC: aktivitas terbaru (feed nyata dari beberapa sumber)
-- -------------------------------------------------------------
create or replace function public.get_recent_activity(p_limit int default 12)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if not public.is_engineer() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select jsonb_agg(x order by x.created_at desc)
  into v
  from (
    select 'lead'::text as kind, l.id::text as ref,
           l.display_name || ' masuk pipeline' as title,
           l.stage::text as detail, l.created_at
    from public.leads l
    union all
    select 'project', p.id::text,
           p.name, p.status, p.created_at
    from public.projects p
    union all
    select 'payment', pm.id::text,
           'Pembayaran ' || pm.status, coalesce(pm.note, ''), pm.created_at
    from public.payments pm
    union all
    select 'workflow', w.id::text,
           w.event_key, w.status, w.created_at
    from public.workflow_runs w
    union all
    select 'lead_activity', a.id::text,
           a.kind, coalesce(a.body, ''), a.created_at
    from public.lead_activities a
  ) x
  limit greatest(1, least(p_limit, 100));

  return coalesce(v, '[]'::jsonb);
end;
$$;

-- -------------------------------------------------------------
-- 15. RPC: laporan agregat (brief M10)
-- -------------------------------------------------------------
create or replace function public.get_reports_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if not public.is_engineer() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'by_province', coalesce((
      select jsonb_agg(jsonb_build_object('label', province, 'leads', n) order by n desc)
      from (
        select c.province, count(l.id)::int as n
        from public.campuses c
        left join public.leads l on l.campus_id = c.id
        group by c.province
      ) t
    ), '[]'::jsonb),
    'by_stage', coalesce((
      select jsonb_agg(jsonb_build_object('label', stage::text, 'count', n) order by n desc)
      from (select stage, count(*)::int as n from public.leads group by stage) t
    ), '[]'::jsonb),
    'by_source', coalesce((
      select jsonb_agg(jsonb_build_object('label', source, 'count', n) order by n desc)
      from (select source, count(*)::int as n from public.leads group by source) t
    ), '[]'::jsonb),
    'by_project_status', coalesce((
      select jsonb_agg(jsonb_build_object('label', status, 'count', n) order by n desc)
      from (select status, count(*)::int as n from public.projects group by status) t
    ), '[]'::jsonb),
    'by_partner', coalesce((
      select jsonb_agg(jsonb_build_object(
        'label', p.full_name,
        'attributions', coalesce(a.n, 0),
        'converted', coalesce(a.conv, 0)
      ) order by coalesce(a.conv,0) desc)
      from public.partners p
      left join (
        select partner_id,
               count(*)::int as n,
               count(*) filter (where status = 'CONVERTED')::int as conv
        from public.referral_attributions group by partner_id
      ) a on a.partner_id = p.id
    ), '[]'::jsonb),
    'revenue_by_month', coalesce((
      select jsonb_agg(jsonb_build_object('label', to_char(d,'YYYY-MM'), 'amount', amt) order by d)
      from (
        select date_trunc('month', coalesce(paid_at, created_at)) as d,
               sum(amount) as amt
        from public.payments where status = 'CONFIRMED'
        group by 1
      ) t
    ), '[]'::jsonb)
  ) into v;

  return v;
end;
$$;

-- -------------------------------------------------------------
-- 16. RPC: eksekusi workflow (idempoten, server-side)
-- -------------------------------------------------------------
create or replace function public.run_workflow(
  p_event_key text,
  p_idempotency_key text,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_def   public.workflow_definitions%rowtype;
  v_run   public.workflow_runs%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select * into v_def from public.workflow_definitions where event_key = p_event_key;
  if not found then
    raise exception 'unknown workflow: %', p_event_key;
  end if;

  -- Idempotensi: kalau kunci sudah pernah dipakai, kembalikan run lama.
  select * into v_run from public.workflow_runs where idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object(
      'deduplicated', true, 'run_id', v_run.id, 'status', v_run.status
    );
  end if;

  if not v_def.enabled then
    insert into public.workflow_runs (definition_id, event_key, status, idempotency_key, payload, finished_at)
    values (v_def.id, p_event_key, 'SKIPPED', p_idempotency_key, p_payload, now())
    returning * into v_run;
    return jsonb_build_object('deduplicated', false, 'run_id', v_run.id, 'status', 'SKIPPED');
  end if;

  insert into public.workflow_runs
    (definition_id, event_key, status, idempotency_key, payload, attempts, started_at)
  values (v_def.id, p_event_key, 'RUNNING', p_idempotency_key, p_payload, 1, now())
  returning * into v_run;

  insert into public.workflow_run_logs (run_id, level, message, data)
  values (v_run.id, 'INFO', 'Workflow started', p_payload);

  -- Efek nyata per event. Semua idempoten terhadap data.
  begin
    if p_event_key = 'contact.opted_out' then
      if (p_payload->>'prospect_id') is not null then
        -- prospect_suppressions berkunci pada ig_username (citext), bukan id.
        insert into public.prospect_suppressions (ig_username, reason)
        select pr.ig_username, coalesce(p_payload->>'reason','OPT_OUT')
          from public.prospects pr
         where pr.id = (p_payload->>'prospect_id')::uuid
        on conflict (ig_username) do nothing;
      end if;

    elsif p_event_key = 'partner.approved' then
      if (p_payload->>'partner_id') is not null then
        update public.partners
           set status = 'active'
         where id = (p_payload->>'partner_id')::uuid
           and status <> 'active';
      end if;

    elsif p_event_key = 'commission.approved' then
      if (p_payload->>'commission_id') is not null then
        insert into public.crm_tasks (title, detail, status, due_at)
        values ('Bayar komisi ' || (p_payload->>'commission_id'),
                'Komisi disetujui, siap payout.', 'OPEN', now() + interval '3 days');
      end if;

    elsif p_event_key = 'instagram.reply_received' then
      if (p_payload->>'lead_id') is not null then
        insert into public.lead_activities (lead_id, kind, body, metadata)
        values ((p_payload->>'lead_id')::uuid, 'MESSAGE',
                coalesce(p_payload->>'body','Balasan Instagram diterima'), p_payload);
      end if;
    end if;

    update public.workflow_runs
       set status = 'SUCCEEDED', finished_at = now(),
           result = jsonb_build_object('ok', true)
     where id = v_run.id;

    insert into public.workflow_run_logs (run_id, level, message)
    values (v_run.id, 'INFO', 'Workflow succeeded');

    return jsonb_build_object('deduplicated', false, 'run_id', v_run.id, 'status', 'SUCCEEDED');

  exception when others then
    update public.workflow_runs
       set status = 'FAILED', finished_at = now(), error = sqlerrm
     where id = v_run.id;
    insert into public.workflow_run_logs (run_id, level, message)
    values (v_run.id, 'ERROR', sqlerrm);
    return jsonb_build_object('deduplicated', false, 'run_id', v_run.id, 'status', 'FAILED', 'error', sqlerrm);
  end;
end;
$$;

-- -------------------------------------------------------------
-- 17. Grants
-- -------------------------------------------------------------
grant execute on function public.get_internal_overview() to authenticated;
grant execute on function public.get_internal_trends(int) to authenticated;
grant execute on function public.get_recent_activity(int) to authenticated;
-- -------------------------------------------------------------
-- RPC: rincian laporan per dimensi (provinsi, universitas, prodi,
-- sumber lead, kategori proyek, partner). Semua dari data nyata.
-- -------------------------------------------------------------
create or replace function public.get_report_breakdown(
  p_dimension text default 'province',
  p_days int default 30
)
returns table (label text, leads bigint, projects bigint, revenue numeric)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_since timestamptz := now() - make_interval(days => greatest(coalesce(p_days, 30), 1));
begin
  if not public.is_engineer() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_dimension = 'province' then
    return query
      select coalesce(c.province, 'Tidak diketahui') as label,
             count(distinct l.id) as leads,
             count(distinct p.id) as projects,
             coalesce(sum(pay.amount) filter (where pay.status = 'CONFIRMED' and pay.kind <> 'REFUND'), 0) as revenue
      from public.campuses c
      left join public.leads l on l.campus_id = c.id and l.created_at >= v_since
      left join public.projects p on p.lead_id = l.id
      left join public.requests rq on rq.id = p.request_id
      left join public.payments pay on pay.request_id = rq.id
      group by c.province
      order by leads desc, label;

  elsif p_dimension = 'university' then
    return query
      select coalesce(c.university, 'Tidak diketahui') as label,
             count(distinct l.id), count(distinct p.id),
             coalesce(sum(pay.amount) filter (where pay.status = 'CONFIRMED' and pay.kind <> 'REFUND'), 0)
      from public.campuses c
      left join public.leads l on l.campus_id = c.id and l.created_at >= v_since
      left join public.projects p on p.lead_id = l.id
      left join public.requests rq on rq.id = p.request_id
      left join public.payments pay on pay.request_id = rq.id
      group by c.university
      order by 2 desc, 1;

  elsif p_dimension = 'study_program' then
    return query
      select coalesce(c.study_program, 'Tidak diketahui') as label,
             count(distinct l.id), count(distinct p.id),
             coalesce(sum(pay.amount) filter (where pay.status = 'CONFIRMED' and pay.kind <> 'REFUND'), 0)
      from public.campuses c
      left join public.leads l on l.campus_id = c.id and l.created_at >= v_since
      left join public.projects p on p.lead_id = l.id
      left join public.requests rq on rq.id = p.request_id
      left join public.payments pay on pay.request_id = rq.id
      group by c.study_program
      order by 2 desc, 1;

  elsif p_dimension = 'source' then
    return query
      select coalesce(l.source, 'Tidak diketahui') as label,
             count(distinct l.id), count(distinct p.id),
             coalesce(sum(pay.amount) filter (where pay.status = 'CONFIRMED' and pay.kind <> 'REFUND'), 0)
      from public.leads l
      left join public.projects p on p.lead_id = l.id
      left join public.requests rq on rq.id = p.request_id
      left join public.payments pay on pay.request_id = rq.id
      where l.created_at >= v_since
      group by l.source
      order by 2 desc, 1;

  elsif p_dimension = 'category' then
    return query
      select coalesce(p.category, 'Tanpa kategori') as label,
             count(distinct p.lead_id), count(distinct p.id),
             coalesce(sum(pay.amount) filter (where pay.status = 'CONFIRMED' and pay.kind <> 'REFUND'), 0)
      from public.projects p
      left join public.requests rq on rq.id = p.request_id
      left join public.payments pay on pay.request_id = rq.id
      where p.created_at >= v_since
      group by p.category
      order by 3 desc, 1;

  elsif p_dimension = 'partner' then
    return query
      select coalesce(pt.full_name, 'Tanpa partner') as label,
             count(distinct l.id), count(distinct p.id),
             coalesce(sum(pay.amount) filter (where pay.status = 'CONFIRMED' and pay.kind <> 'REFUND'), 0)
      from public.partners pt
      left join public.leads l on l.partner_id = pt.id and l.created_at >= v_since
      left join public.projects p on p.partner_id = pt.id
      left join public.requests rq on rq.id = p.request_id
      left join public.payments pay on pay.request_id = rq.id
      group by pt.full_name
      order by 2 desc, 1;

  else
    raise exception 'dimensi tidak dikenal: %', p_dimension using errcode = '22023';
  end if;
end;
$$;

grant execute on function public.get_report_breakdown(text, int) to authenticated;

grant execute on function public.get_reports_summary() to authenticated;
grant execute on function public.run_workflow(text, text, jsonb) to authenticated;

-- ============ migration-testimonials.sql ============

-- =============================================================
-- Tabel testimonials + kebijakan RLS
-- Jalankan di: Supabase Dashboard > SQL Editor > New query
-- Aman dijalankan berulang (idempotent).
-- =============================================================

create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text,
  rating smallint not null default 5 check (rating between 1 and 5),
  message text not null,
  project_type text,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists testimonials_published_idx
  on public.testimonials (is_published, created_at desc);

alter table public.testimonials enable row level security;

-- Publik hanya boleh membaca testimoni yang sudah direview.
drop policy if exists "testimonials_public_read" on public.testimonials;
create policy "testimonials_public_read"
  on public.testimonials for select
  to anon, authenticated
  using (is_published = true);

-- Pengunjung boleh mengirim testimoni baru, tapi tidak boleh
-- menerbitkannya sendiri (is_published wajib false).
drop policy if exists "testimonials_anon_insert" on public.testimonials;
create policy "testimonials_anon_insert"
  on public.testimonials for insert
  to anon, authenticated
  with check (is_published = false);

-- Engineer (via service role / dashboard) mengelola sisanya.

-- ==== migration-notify-guard.sql (klaim notifikasi/email) ====
-- =============================================================
-- Notifikasi & email: klaim sekali pakai + data dari DB
-- =============================================================
-- Masalah yang ditutup:
--   1. /api/notify-order bisa dipanggil siapa pun dengan isi pesan bebas →
--      spam + phishing ke chat Telegram engineer.
--   2. /api/send-email menerima alamat tujuan + HTML bebas → domain email
--      dipakai orang lain untuk spam/phishing.
--
-- Pengganti: endpoint hanya menerima order_no. Order harus ada, berumur
-- < 30 menit, dan belum pernah diklaim. Klaim memakai UPDATE ... WHERE
-- sehingga dua pemanggilan paralel tidak bisa mengirim dua kali.
-- Fungsi hanya boleh dipanggil service_role (server), bukan anon.

alter table public.requests
  add column if not exists notified_at timestamptz,
  add column if not exists email_sent_at timestamptz;

-- ---------------------------------------------------------------
-- Klaim notifikasi Telegram
-- ---------------------------------------------------------------
create or replace function public.claim_order_notification(p_order_no text)
returns table (
  order_no      text,
  customer_name text,
  whatsapp      text,
  category      text,
  deadline      text,
  deadline_date date,
  description   text,
  link          text,
  file_url      text
)
language sql
security definer
set search_path = public
as $$
  update public.requests r
     set notified_at = now()
   where upper(r.order_no) = upper(trim(p_order_no))
     and r.notified_at is null
     and r.created_at > now() - interval '30 minutes'
  returning r.order_no, r.customer_name, r.whatsapp, r.category,
            r.deadline, r.deadline_date, r.description, r.link, r.file_url;
$$;

revoke all on function public.claim_order_notification(text) from public;
grant execute on function public.claim_order_notification(text) to service_role;

-- ---------------------------------------------------------------
-- Klaim email booking (butuh kolom email terisi)
-- ---------------------------------------------------------------
create or replace function public.claim_order_email(p_order_no text)
returns table (
  order_no      text,
  customer_name text,
  email         text,
  category      text,
  deadline      text,
  deadline_date date,
  description   text,
  quote_amount  numeric
)
language sql
security definer
set search_path = public
as $$
  update public.requests r
     set email_sent_at = now()
   where upper(r.order_no) = upper(trim(p_order_no))
     and r.email is not null
     and r.email_sent_at is null
     and r.created_at > now() - interval '30 minutes'
  returning r.order_no, r.customer_name, r.email, r.category,
            r.deadline, r.deadline_date, r.description, r.quote_amount;
$$;

revoke all on function public.claim_order_email(text) from public;
grant execute on function public.claim_order_email(text) to service_role;

-- ---------------------------------------------------------------
-- Lepas klaim kalau pengiriman gagal, supaya bisa dicoba ulang
-- ---------------------------------------------------------------
create or replace function public.release_order_claim(p_order_no text, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind = 'email' then
    update public.requests set email_sent_at = null
     where upper(order_no) = upper(trim(p_order_no));
  else
    update public.requests set notified_at = null
     where upper(order_no) = upper(trim(p_order_no));
  end if;
end;
$$;

revoke all on function public.release_order_claim(text, text) from public;
grant execute on function public.release_order_claim(text, text) to service_role;

create index if not exists requests_notified_at_idx on public.requests (notified_at);
create index if not exists requests_email_sent_at_idx on public.requests (email_sent_at);

-- ==== migration-status-notify.sql (kabar perubahan status ke klien) ====
-- ==========================================================================
-- Notifikasi perubahan status ke klien (email)
--
-- Masalah: engineer mengubah status di dashboard, tapi klien tidak diberi tahu
-- sama sekali. Klien harus membuka /track sendiri, sehingga pertanyaan
-- "progresnya gimana?" tetap masuk lewat WhatsApp.
--
-- Desain:
--   - requests.status_notified menyimpan status terakhir yang SUDAH dikabarkan.
--     Klaim = UPDATE bersyarat, jadi atomik dan anti-dobel (dua klik beruntun
--     tidak mengirim dua email).
--   - Kalau status kembali ke nilai sebelumnya (mis. working -> review ->
--     working), klien tetap dikabari karena yang dibandingkan adalah nilai
--     terakhir, bukan riwayat unik.
--   - Tabel log hanya untuk audit (provider_id Resend), tanpa policy RLS:
--     hanya service_role yang menyentuh.
-- ==========================================================================

alter table public.requests
  add column if not exists status_notified text;

create table if not exists public.request_status_notifications (
  id bigserial primary key,
  order_no text not null,
  status text not null,
  provider_id text,
  created_at timestamptz not null default now()
);

create index if not exists idx_status_notif_order on public.request_status_notifications (order_no);

alter table public.request_status_notifications enable row level security;
revoke all on public.request_status_notifications from public, anon, authenticated;

-- Klaim: tandai status ini sedang dikabarkan, kembalikan data yang dibutuhkan
-- untuk menyusun email. Tidak mengembalikan baris kalau:
--   order tidak ada / status tidak cocok / klien tanpa email / sudah dikabarkan.
create or replace function public.claim_status_notification(p_order_no text, p_status text)
returns table (
  order_no text,
  customer_name text,
  email text,
  status text,
  category text,
  deadline text,
  deadline_date date,
  quote_amount numeric
)
language sql
security definer
set search_path = public
as $$
  update public.requests r
     set status_notified = r.status
   where r.order_no = upper(trim(p_order_no))
     and r.status = p_status
     and r.email is not null
     and length(trim(r.email)) > 0
     and coalesce(r.status_notified, '') <> r.status
  returning r.order_no, r.customer_name, r.email, r.status, r.category,
            r.deadline, r.deadline_date, r.quote_amount;
$$;

-- Lepas klaim kalau pengiriman gagal, supaya bisa dicoba lagi.
create or replace function public.release_status_notification(p_order_no text, p_status text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.requests
     set status_notified = null
   where order_no = upper(trim(p_order_no))
     and status = p_status
     and status_notified = p_status;
$$;

revoke all on function public.claim_status_notification(text, text) from public, anon, authenticated;
revoke all on function public.release_status_notification(text, text) from public, anon, authenticated;
grant execute on function public.claim_status_notification(text, text) to service_role;
grant execute on function public.release_status_notification(text, text) to service_role;

-- ==== migration-partner-manage.sql (rekap partner, detail, kode custom, atribusi) ====
-- =============================================================
-- Kelola partner & komisi dari dashboard
-- =============================================================
-- Isi:
--   1. requests.referral_partner_id  → atribusi permanen per order
--   2. trigger pengisi referral_partner_id dari referral_code
--   3. partner_summary(from,to)      → rekap per partner (engineer only)
--   4. partner_detail(id,from,to)    → order + komisi satu partner
--   5. set_partner_code(id,code)     → kode custom (validasi + unik)
--   6. recompute_commission_internal → pakai referral_partner_id lebih dulu
--
-- Kenapa (1)+(6) penting: versi lama mencari partner lewat
-- partners.referral_code = requests.referral_code AND status='active'.
-- Begitu kode dirotasi atau partner dinonaktifkan, order lamanya tidak lagi
-- menemukan partner → komisi jadi VOID saat dihitung ulang.

-- ---------------------------------------------------------------
-- 1. Kolom atribusi permanen
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists referral_partner_id uuid references public.partners (id);

update public.requests r
   set referral_partner_id = p.id
  from public.partners p
 where r.referral_partner_id is null
   and p.referral_code = upper(trim(coalesce(r.referral_code, '')));

create index if not exists requests_referral_partner_idx
  on public.requests (referral_partner_id);

-- ---------------------------------------------------------------
-- 2. Trigger: order baru otomatis mengikat partner
-- ---------------------------------------------------------------
create or replace function public.requests_set_referral_partner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.referral_partner_id is null
     and new.referral_code is not null
     and trim(new.referral_code) <> '' then
    select id into new.referral_partner_id
      from public.partners
     where referral_code = upper(trim(new.referral_code))
     limit 1;
  end if;
  return new;
end;
$$;

drop trigger if exists requests_set_referral_partner_trg on public.requests;
create trigger requests_set_referral_partner_trg
  before insert or update of referral_code on public.requests
  for each row execute function public.requests_set_referral_partner();

-- ---------------------------------------------------------------
-- 3. Rekap per partner
-- ---------------------------------------------------------------
create or replace function public.partner_summary(p_from date default null, p_to date default null)
returns table (
  partner_id          uuid,
  referral_code       text,
  full_name           text,
  whatsapp            text,
  campus              text,
  status              text,
  referrals           bigint,
  deals               bigint,
  gross               numeric,
  commission_pending  numeric,
  commission_paid     numeric,
  last_referral_at    timestamptz
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
  select p.id,
         p.referral_code,
         p.full_name,
         p.whatsapp,
         p.campus,
         p.status,
         count(r.id)                                                        as referrals,
         count(c.id) filter (where c.status <> 'VOID')                       as deals,
         coalesce(sum(r.quote_amount), 0)                                    as gross,
         coalesce(sum(c.eligible_amount) filter (where c.status in ('PENDING','ELIGIBLE')), 0) as commission_pending,
         coalesce(sum(coalesce(c.amount, c.eligible_amount)) filter (where c.status = 'PAID'), 0) as commission_paid,
         max(r.created_at)                                                   as last_referral_at
    from public.partners p
    left join public.requests r
           on r.referral_partner_id = p.id
          and (p_from is null or r.created_at >= p_from)
          and (p_to   is null or r.created_at <  (p_to + 1))
    left join public.commissions c on c.request_id = r.id
   group by p.id, p.referral_code, p.full_name, p.whatsapp, p.campus, p.status
   order by count(r.id) desc, p.created_at desc;
end;
$$;

revoke all on function public.partner_summary(date, date) from public, anon;
grant execute on function public.partner_summary(date, date) to authenticated;

-- ---------------------------------------------------------------
-- 4. Detail satu partner (maks 200 order)
-- ---------------------------------------------------------------
create or replace function public.partner_detail(p_partner_id uuid, p_from date default null, p_to date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_hasil jsonb;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'partner', (select to_jsonb(x) from public.partners x where x.id = p_partner_id),
    'orders', coalesce((
      select jsonb_agg(jsonb_build_object(
               'order_no', q.order_no,
               'customer_name', q.customer_name,
               'status', q.status,
               'quote_amount', q.quote_amount,
               'created_at', q.created_at,
               'commission', (select to_jsonb(c) from public.commissions c where c.request_id = q.id)
             ) order by q.created_at desc)
        from (
          select * from public.requests r
           where r.referral_partner_id = p_partner_id
             and (p_from is null or r.created_at >= p_from)
             and (p_to   is null or r.created_at <  (p_to + 1))
           order by r.created_at desc
           limit 200
        ) q
    ), '[]'::jsonb)
  ) into v_hasil;

  return v_hasil;
end;
$$;

revoke all on function public.partner_detail(uuid, date, date) from public, anon;
grant execute on function public.partner_detail(uuid, date, date) to authenticated;

-- ---------------------------------------------------------------
-- 5. Kode custom
-- ---------------------------------------------------------------
create or replace function public.set_partner_code(p_partner_id uuid, p_code text)
returns public.partners
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_row  public.partners%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;

  v_code := upper(trim(coalesce(p_code, '')));
  if v_code !~ '^REF-[A-Z0-9][A-Z0-9-]{2,15}$' then
    raise exception 'KODE_TIDAK_VALID' using errcode = '22023';
  end if;
  if exists (select 1 from public.partners where referral_code = v_code and id <> p_partner_id) then
    raise exception 'KODE_SUDAH_DIPAKAI' using errcode = '23505';
  end if;

  update public.partners set referral_code = v_code where id = p_partner_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'PARTNER_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

revoke all on function public.set_partner_code(uuid, text) from public, anon;
grant execute on function public.set_partner_code(uuid, text) to authenticated;

-- ---------------------------------------------------------------
-- 6. recompute_commission_internal: atribusi permanen
-- ---------------------------------------------------------------
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

  -- 1) Atribusi permanen menang: kode boleh diganti, partner boleh nonaktif.
  select id into v_partner_id
    from public.partners
   where id = v_req.referral_partner_id;

  -- 2) Fallback order lama (sebelum kolom ini ada) + cegah self-referral.
  if v_partner_id is null then
    select id into v_partner_id
      from public.partners
     where referral_code = upper(trim(coalesce(v_req.referral_code, '')))
       and status = 'active'
       and public.normalize_phone(whatsapp) <> public.normalize_phone(coalesce(v_req.whatsapp, ''));

    if v_partner_id is not null then
      update public.requests set referral_partner_id = v_partner_id where id = p_request_id;
    end if;
  else
    -- self-referral tetap ditolak walau id sudah tertanam
    if exists (
      select 1 from public.partners
       where id = v_partner_id
         and public.normalize_phone(whatsapp) = public.normalize_phone(coalesce(v_req.whatsapp, ''))
    ) then
      v_partner_id := null;
    end if;
  end if;

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

revoke all on function public.recompute_commission_internal(uuid) from public, anon, authenticated;
grant execute on function public.recompute_commission_internal(uuid) to service_role;
