-- =============================================================
-- Test: campaign, atribusi UTM, event, CAC (V4 Slice B)
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ---------- campaign admin distribution ----------
do $$
declare cid uuid; o text; r public.requests; ev int;
begin
  insert into public.campaigns (code, name, objective, channel, campus, status,
                                cost_rupiah, time_value_rupiah)
  values ('CMP-TESTA1', 'Admin Kampus X', 'ADMIN_DISTRIBUTION', 'INSTAGRAM_MANUAL_DM',
          'Kampus X', 'ACTIVE', 100000, 50000)
  returning id into cid;

  o := public.create_public_request(
    'Klien Campaign', '628111222333', 'butuh web', 'web', 'besok',
    null, null, null, null, null,
    'CMP-TESTA1', 'instagram', 'admin_share', 'angkatan23', null, null);

  select * into r from public.requests where order_no = o;
  if r.campaign_id <> cid then
    raise exception 'FAIL: campaign_id tidak tersimpan';
  end if;
  if r.source <> 'ADMIN_SHARE' then
    raise exception 'FAIL: source harus ADMIN_SHARE, dapat %', r.source;
  end if;
  if r.attribution_at is null or r.utm_source <> 'instagram' or r.utm_campaign <> 'angkatan23' then
    raise exception 'FAIL: atribusi UTM tidak lengkap';
  end if;

  select count(*) into ev from public.campaign_events
   where campaign_id = cid and event_type = 'INQUIRY' and request_id = r.id;
  if ev <> 1 then
    raise exception 'FAIL: event INQUIRY harus 1, dapat %', ev;
  end if;

  -- lunas -> PAID + DEAL (quote diset sebelum pembayaran)
  update public.requests set quote_amount = 500000 where id = r.id;
  perform public.record_payment(r.id, 'SETTLEMENT', 500000, 'camp-pay-1', 'transfer', null, now(), null);

  select count(*) into ev from public.campaign_events
   where campaign_id = cid and event_type = 'PAID' and request_id = r.id;
  if ev <> 1 then
    raise exception 'FAIL: event PAID harus 1, dapat %', ev;
  end if;
end $$;

-- ---------- kode campaign tidak valid diabaikan ----------
do $$
declare o text; r public.requests;
begin
  o := public.create_public_request(
    'Klien Tanpa Campaign', '628111222444', 'butuh api', 'web', 'besok',
    null, null, null, null, null, 'CMP-TIDAKADA', null, null, null, null, null);
  select * into r from public.requests where order_no = o;
  if r.campaign_id is not null then
    raise exception 'FAIL: kode campaign palsu diterima';
  end if;
  if r.source <> 'INBOUND' then
    raise exception 'FAIL: tanpa campaign harus INBOUND, dapat %', r.source;
  end if;
end $$;

-- ---------- atribusi terkunci ----------
do $$
declare pid uuid; c2 uuid;
begin
  select id into pid from public.requests where customer_name = 'Klien Campaign' order by created_at limit 1;
  insert into public.campaigns (code, name, objective, channel, status)
  values ('CMP-TESTB2', 'Campaign Lain', 'INBOUND', 'WEBSITE_OPT_IN', 'ACTIVE')
  returning id into c2;

  begin
    update public.requests set campaign_id = c2 where id = pid;
    raise exception 'FAIL: atribusi bisa diubah tanpa override';
  exception when sqlstate '42501' then null;
  end;
end $$;

-- ---------- commission paid -> REFERRAL_PAID ----------
do $$
declare cid uuid; o text; pid uuid; ev int;
begin
  insert into public.campaigns (code, name, objective, channel, status)
  values ('CMP-TESTC3', 'Referral Campaign', 'REFERRAL', 'WHATSAPP_REFERRAL', 'ACTIVE')
  returning id into cid;

  o := public.create_public_request(
    'Klien Referral Campaign', '628111222555', 'butuh mobile', 'mobile', 'besok',
    null, null, null, null, 'REF-ANDI23', 'CMP-TESTC3', null, null, null, null, null);

  select id into pid from public.requests where order_no = o;
  update public.requests set quote_amount = 400000 where id = pid;
  perform public.record_payment(pid, 'SETTLEMENT', 400000, 'camp-ref-1', 'transfer', null, now(), null);
  perform public.mark_commission_paid(
    (select id from public.commissions where request_id = pid), 'https://bukti/camp.png', null);

  select count(*) into ev from public.campaign_events
   where campaign_id = cid and event_type = 'REFERRAL_PAID' and request_id = pid;
  if ev <> 1 then
    raise exception 'FAIL: event REFERRAL_PAID harus 1, dapat %', ev;
  end if;
  if (select source from public.requests where id = pid) <> 'REFERRAL' then
    raise exception 'FAIL: source referral campaign salah';
  end if;
end $$;

-- ---------- analytics campaign ----------
do $$
declare a record;
begin
  select * into a from public.analytics_campaigns(null, null) where code = 'CMP-TESTA1';
  if a.inquiries < 1 or a.paid_clients < 1 or a.gross < 500000 then
    raise exception 'FAIL: analytics campaign salah (% / % / %)', a.inquiries, a.paid_clients, a.gross;
  end if;
  if a.cost <> 150000 then
    raise exception 'FAIL: cost harus 150000, dapat %', a.cost;
  end if;
  if a.cac is null then
    raise exception 'FAIL: CAC harus terisi saat ada paid client';
  end if;
end $$;

-- ---------- anon: resolve boleh, tabel tidak ----------
reset role;
set role anon;
set request.jwt.claim.role = 'anon';
set request.jwt.claim.sub = '';

do $$
declare r record; n int;
begin
  select * into r from public.resolve_campaign('CMP-TESTA1');
  if r.name <> 'Admin Kampus X' then
    raise exception 'FAIL: resolve_campaign tidak mengembalikan campaign aktif';
  end if;

  select count(*) into n from public.campaigns;
  if n <> 0 then
    raise exception 'FAIL: anon bisa membaca tabel campaigns';
  end if;

  begin
    perform public.analytics_campaigns(null, null);
    raise exception 'FAIL: anon bisa memanggil analytics_campaigns';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
