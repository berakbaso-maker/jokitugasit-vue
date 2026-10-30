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
