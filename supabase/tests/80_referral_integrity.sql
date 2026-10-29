-- =============================================================
-- Test: self-referral tidak menghasilkan komisi.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

insert into public.partners (full_name, whatsapp, referral_code, status)
values ('Partner Self', '628777000111', 'REF-SELF77', 'active')
on conflict (referral_code) do nothing;

-- ---------- normalisasi nomor ----------
do $$
begin
  if public.normalize_phone('0812-3456-789') <> '628123456789' then
    raise exception 'FAIL: normalisasi 0xx gagal: %', public.normalize_phone('0812-3456-789');
  end if;
  if public.normalize_phone('+62 812 3456 789') <> '628123456789' then
    raise exception 'FAIL: normalisasi +62 gagal: %', public.normalize_phone('+62 812 3456 789');
  end if;
  if public.normalize_phone(null) <> '' then
    raise exception 'FAIL: normalisasi null harus string kosong';
  end if;
end $$;

-- ---------- form publik: kode partner sendiri dibuang ----------
do $$
declare o text; ref text; src text;
begin
  o := public.create_public_request(
    'Partner Sendiri', '08777000111', 'mau bikin web', 'web', 'besok',
    null, null, null, null, 'REF-SELF77');

  select referral_code, source into ref, src from public.requests where order_no = o;
  if ref is not null then
    raise exception 'FAIL: self-referral masih menyimpan kode %', ref;
  end if;
  if src <> 'INBOUND' then
    raise exception 'FAIL: self-referral harus INBOUND, dapat %', src;
  end if;
end $$;

-- ---------- nomor berbeda tetap dapat atribusi ----------
do $$
declare o text; ref text; src text;
begin
  o := public.create_public_request(
    'Teman Partner', '08777000222', 'mau bikin web', 'web', 'besok',
    null, null, null, null, 'REF-SELF77');

  select referral_code, source into ref, src from public.requests where order_no = o;
  if ref <> 'REF-SELF77' then
    raise exception 'FAIL: referral sah tidak tersimpan, dapat %', ref;
  end if;
  if src <> 'REFERRAL' then
    raise exception 'FAIL: referral sah harus REFERRAL, dapat %', src;
  end if;
end $$;

-- ---------- kode terlanjur tersimpan di proyek self-referral ----------
do $$
declare pid uuid; order_no text;
begin
  order_no := 'JTSELF' || lpad((floor(random()*900000)+100000)::int::text, 6, '0');
  insert into public.requests (
    order_no, customer_name, whatsapp, description, category, deadline,
    status, quote_amount, referral_code, source
  ) values (
    order_no, 'Partner Sendiri', '08777000111', 'proyek self', 'web', 'besok',
    'working', 500000, 'REF-SELF77', 'REFERRAL'
  ) returning id into pid;

  perform public.record_payment(pid, 'SETTLEMENT', 500000, 'self-pay-1', 'transfer');

  if exists (select 1 from public.commissions where request_id = pid) then
    raise exception 'FAIL: self-referral menghasilkan komisi';
  end if;
end $$;

-- ---------- proyek normal tetap dapat komisi ----------
do $$
declare pid uuid; order_no text; c record;
begin
  order_no := 'JTNORM' || lpad((floor(random()*900000)+100000)::int::text, 6, '0');
  insert into public.requests (
    order_no, customer_name, whatsapp, description, category, deadline,
    status, quote_amount, referral_code, source
  ) values (
    order_no, 'Klien Normal', '08777000333', 'proyek normal', 'web', 'besok',
    'working', 500000, 'REF-SELF77', 'REFERRAL'
  ) returning id into pid;

  perform public.record_payment(pid, 'SETTLEMENT', 500000, 'normal-pay-1', 'transfer');

  select * into c from public.commissions where request_id = pid;
  if c.status <> 'ELIGIBLE' or c.amount <> 50000 then
    raise exception 'FAIL: komisi normal harus ELIGIBLE 50000, dapat % / %', c.status, c.amount;
  end if;
end $$;

reset role;
