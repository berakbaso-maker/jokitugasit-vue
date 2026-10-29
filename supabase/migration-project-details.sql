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
