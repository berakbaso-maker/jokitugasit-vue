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
