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
