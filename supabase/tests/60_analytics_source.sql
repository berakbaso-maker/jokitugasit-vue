-- =============================================================
-- Test: analytics mengikuti periode + atribusi sumber klien.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

create or replace function pg_temp.src_project(
  p_source text, p_created timestamptz, p_quote bigint default 200000
) returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.requests (order_no, customer_name, description, category, deadline,
                               status, quote_amount, source, created_at)
  values ('JTS' || lpad((floor(random()*900000)+100000)::int::text, 6, '0'),
          'Klien Sumber', 'uji sumber', 'web', 'besok', 'new', p_quote, p_source, p_created)
  returning id into v_id;
  return v_id;
end $$;

-- ---------- create_public_request mengisi source otomatis ----------
do $$
declare o1 text; o2 text; s1 text; s2 text;
begin
  o1 := public.create_public_request(
    'Klien Organik', '628111000111', 'butuh bantuan web', 'web', 'besok',
    null, null, null, null, null);
  select source into s1 from public.requests where order_no = o1;
  if s1 <> 'INBOUND' then
    raise exception 'FAIL: request tanpa kode harus INBOUND, dapat %', s1;
  end if;

  o2 := public.create_public_request(
    'Klien Referral', '628111000222', 'butuh bantuan api', 'web', 'besok',
    null, null, null, null, 'REF-ANDI23');
  select source into s2 from public.requests where order_no = o2;
  if s2 <> 'REFERRAL' then
    raise exception 'FAIL: request dengan kode harus REFERRAL, dapat %', s2;
  end if;
  if (select referral_code from public.requests where order_no = o2) <> 'REF-ANDI23' then
    raise exception 'FAIL: kode referral tidak tersimpan';
  end if;
end $$;

-- ---------- proyek lama tidak ikut di periode ----------
do $$
declare pid uuid; before_all int; before_win int; after_all int; after_win int;
begin
  select (public.analytics_overview(null, null) ->> 'projects_total')::int,
         (public.analytics_overview(current_date, current_date) ->> 'projects_total')::int
    into before_all, before_win;

  pid := pg_temp.src_project('OTHER', now() - interval '60 days');

  select (public.analytics_overview(null, null) ->> 'projects_total')::int,
         (public.analytics_overview(current_date, current_date) ->> 'projects_total')::int
    into after_all, after_win;

  if after_all <> before_all + 1 then
    raise exception 'FAIL: proyek lama tidak terhitung di all-time (% -> %)', before_all, after_all;
  end if;
  if after_win <> before_win then
    raise exception 'FAIL: proyek 60 hari ikut terhitung di periode hari ini (% -> %)', before_win, after_win;
  end if;
end $$;

-- ---------- pembayaran lama tidak menambah omzet periode ----------
do $$
declare pid uuid; before_gross bigint; after_gross bigint; all_gross bigint;
begin
  before_gross := (public.analytics_overview(current_date, current_date) ->> 'gross_confirmed')::bigint;

  pid := pg_temp.src_project('DIRECT_DM', now() - interval '45 days', 500000);
  perform public.record_payment(
    pid, 'SETTLEMENT', 500000, 'old-payment-1', 'transfer', null, now() - interval '45 days');

  after_gross := (public.analytics_overview(current_date, current_date) ->> 'gross_confirmed')::bigint;
  all_gross := (public.analytics_overview(null, null) ->> 'gross_confirmed')::bigint;

  if after_gross <> before_gross then
    raise exception 'FAIL: pembayaran 45 hari masuk omzet hari ini (% -> %)', before_gross, after_gross;
  end if;
  if all_gross < 500000 then
    raise exception 'FAIL: omzet all-time tidak menghitung pembayaran lama';
  end if;
end $$;

-- ---------- breakdown sumber memakai proyek periode ----------
do $$
declare a jsonb; dm jsonb; adm jsonb;
begin
  perform pg_temp.src_project('DIRECT_DM', now());
  perform pg_temp.src_project('ADMIN_SHARE', now());

  a := public.analytics_overview(current_date, current_date);

  select elem into dm
  from jsonb_array_elements(a -> 'source_breakdown') elem
  where elem ->> 'source' = 'DIRECT_DM';
  if dm is null or (dm ->> 'projects')::int < 1 then
    raise exception 'FAIL: DIRECT_DM tidak muncul di breakdown: %', a -> 'source_breakdown';
  end if;

  select elem into adm
  from jsonb_array_elements(a -> 'source_breakdown') elem
  where elem ->> 'source' = 'ADMIN_SHARE';
  if adm is null or (adm ->> 'projects')::int < 1 then
    raise exception 'FAIL: ADMIN_SHARE tidak muncul di breakdown';
  end if;

  -- REFERRAL dari create_public_request juga tercatat
  if not exists (
    select 1 from jsonb_array_elements(a -> 'source_breakdown') elem
    where elem ->> 'source' = 'REFERRAL'
  ) then
    raise exception 'FAIL: REFERRAL tidak muncul di breakdown';
  end if;
end $$;

-- ---------- nilai sumber tidak valid ditolak constraint ----------
do $$
begin
  begin
    perform pg_temp.src_project('IKLAN', now());
    raise exception 'FAIL: sumber tidak valid diterima';
  exception when check_violation then null;
  end;
end $$;

reset role;
drop function pg_temp.src_project(text, timestamptz, bigint);
