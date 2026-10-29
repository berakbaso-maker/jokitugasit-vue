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
