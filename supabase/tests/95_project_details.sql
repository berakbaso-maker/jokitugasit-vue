-- =============================================================
-- Test: campus + stack proyek dan filter kampus di analytics.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ---------- konversi prospek mengisi campus ----------
do $$
declare pa uuid; pb uuid; ra public.requests; rb public.requests;
begin
  insert into public.prospects (ig_username, display_name, campus)
  values ('kampus.alpha', 'Alpha', 'Kampus Alpha')
  on conflict (ig_username) do update set campus = excluded.campus
  returning id into pa;

  insert into public.prospects (ig_username, display_name, campus)
  values ('kampus.beta', 'Beta', 'Kampus Beta')
  on conflict (ig_username) do update set campus = excluded.campus
  returning id into pb;

  -- bersihkan proyek lama dari username ini supaya test deterministik
  delete from public.requests where prospect_id in (pa, pb);

  ra := public.create_request_from_prospect(pa, 'web', 'proyek alpha', 300000);
  rb := public.create_request_from_prospect(pb, 'web', 'proyek beta', 900000);

  if ra.campus <> 'Kampus Alpha' then
    raise exception 'FAIL: campus tidak terisi dari prospek: %', ra.campus;
  end if;
  if rb.campus <> 'Kampus Beta' then
    raise exception 'FAIL: campus beta salah: %', rb.campus;
  end if;

  update public.requests set status = 'working', stack = 'Vue + Supabase'
   where id = ra.id;

  if (select stack from public.requests where id = ra.id) <> 'Vue + Supabase' then
    raise exception 'FAIL: kolom stack tidak tersimpan';
  end if;

  perform public.record_payment(ra.id, 'SETTLEMENT', 300000, 'alpha-pay-1', 'transfer');
  perform public.record_payment(rb.id, 'SETTLEMENT', 900000, 'beta-pay-1', 'transfer');
end $$;

-- ---------- analytics difilter kampus ----------
do $$
declare a jsonb; f record;
begin
  a := public.analytics_overview(null, null, 'Kampus Alpha');

  if (a ->> 'projects_total')::int <> 1 then
    raise exception 'FAIL: proyek Kampus Alpha harus 1, dapat %', a ->> 'projects_total';
  end if;
  if (a ->> 'gross_confirmed')::bigint <> 300000 then
    raise exception 'FAIL: omzet Kampus Alpha harus 300000, dapat %', a ->> 'gross_confirmed';
  end if;
  if jsonb_array_length(a -> 'source_breakdown') <> 1 then
    raise exception 'FAIL: breakdown harus hanya 1 sumber';
  end if;

  select * into f from public.analytics_funnel(null, null, 'Kampus Alpha') where stage = 'Deal';
  if f.count <> 1 then
    raise exception 'FAIL: Deal Kampus Alpha harus 1, dapat %', f.count;
  end if;

  -- tanpa filter, kedua proyek tetap terhitung
  a := public.analytics_overview(null, null);
  if (a ->> 'projects_total')::int < 2 then
    raise exception 'FAIL: analitik tanpa filter harus memuat >= 2 proyek';
  end if;
end $$;

-- ---------- daftar kampus ----------
do $$
begin
  if not exists (select 1 from public.analytics_campuses() where campus = 'Kampus Alpha') then
    raise exception 'FAIL: Kampus Alpha tidak ada di daftar';
  end if;
  if not exists (select 1 from public.analytics_campuses() where campus = 'Kampus Beta') then
    raise exception 'FAIL: Kampus Beta tidak ada di daftar';
  end if;
end $$;

-- ---------- non-engineer ditolak ----------
reset role;
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
begin
  begin
    perform public.analytics_campuses();
    raise exception 'FAIL: customer bisa membaca daftar kampus';
  exception when sqlstate '42501' then null;
  end;

  begin
    perform public.analytics_overview(null, null, 'Kampus Alpha');
    raise exception 'FAIL: customer bisa memanggil analytics kampus';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
