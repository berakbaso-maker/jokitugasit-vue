-- =============================================================
-- Test: kebocoran data publik sudah tertutup, RPC tetap bekerja.
-- Dijalankan sebagai superuser, lalu beralih role seperti PostgREST.
-- =============================================================
set client_min_messages to warning;

-- ---------- fixtures ----------
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'engineer@test.local', '{"role":"engineer"}'),
  ('22222222-2222-2222-2222-222222222222', 'customer@test.local', '{}')
on conflict (id) do nothing;

insert into public.partners (full_name, whatsapp, campus, referral_code, ewallet_info)
values ('Andi Pratama', '628111111111', 'Binus', 'REF-ANDI23', 'DANA 081111111111')
on conflict (referral_code) do nothing;

insert into public.requests (order_no, customer_name, whatsapp, category, deadline,
                             description, status, quote_amount, internal_notes, referral_code)
values ('JT1024', 'Raka', '628123456789', 'mobile', 'besok',
        'API data tidak tampil di Flutter', 'review', 500000,
        'catatan internal rahasia', 'REF-ANDI23')
on conflict (order_no) do nothing;

-- =============================================================
-- ANON
-- =============================================================
set role anon;
set request.jwt.claim.role = 'anon';
set request.jwt.claim.sub = '';

-- 1. requests tidak bisa dibaca langsung
do $$
begin
  if (select count(*) from public.requests) <> 0 then
    raise exception 'FAIL: anon masih bisa membaca requests';
  end if;
end $$;

-- 2. kolom sensitif tidak bisa diambil lewat cara lain
do $$
begin
  if exists (select internal_notes from public.requests limit 1) then
    raise exception 'FAIL: anon masih bisa menyentuh internal_notes';
  end if;
  if exists (select quote_amount from public.requests where quote_amount is not null) then
    raise exception 'FAIL: anon masih bisa membaca quote_amount';
  end if;
end $$;

-- 3. partners tidak bisa dibaca langsung
do $$
begin
  if (select count(*) from public.partners) <> 0 then
    raise exception 'FAIL: anon masih bisa membaca partners';
  end if;
end $$;

-- 4. anon tidak bisa insert request langsung (harus lewat RPC)
do $$
begin
  insert into public.requests (order_no, customer_name, description, quote_amount)
  values ('JTEST1', 'Hacker', 'x', 999999999);
  raise exception 'FAIL: anon masih bisa insert langsung';
exception when insufficient_privilege then null;
end $$;

-- 5. RPC track_request mengembalikan kolom publik saja
do $$
declare r record;
begin
  select * into r from public.track_request('JT1024');
  if r.order_no is null then raise exception 'FAIL: track_request tidak menemukan order'; end if;
  if r.customer_name <> 'Raka' then raise exception 'FAIL: track_request salah data'; end if;
end $$;

-- 6. RPC create_public_request menolak input kosong
do $$
begin
  perform public.create_public_request('', '62811', 'desc');
  raise exception 'FAIL: nama kosong diterima';
exception when others then
  if sqlerrm <> 'NAMA_WAJIB' then raise exception 'FAIL: pesan error salah: %', sqlerrm; end if;
end $$;

-- 7. RPC create_public_request tidak bisa memalsukan harga/status
do $$
declare v_order text; r record;
begin
  v_order := public.create_public_request(
    'Siti', '628123', 'Perlu setup routing React', 'web', 'besok', null, null, null, null, 'ref-andi23');
  select * into r from public.track_request(v_order);
  if r.quote_amount is not null then raise exception 'FAIL: quote_amount bisa diisi anon'; end if;
  if r.status <> 'new' then raise exception 'FAIL: status bukan new'; end if;
end $$;

-- 8. kode referral divalidasi, tapi data partner tidak bocor
do $$
declare v record;
begin
  select * into v from public.validate_referral_code('ref-andi23');
  if v.valid is not true then raise exception 'FAIL: kode valid tidak dikenali'; end if;
  if v.display_name <> 'Andi' then raise exception 'FAIL: display_name harus nama depan'; end if;
end $$;

do $$
begin
  if exists (select 1 from public.validate_referral_code('REF-NGAWUR')) then
    raise exception 'FAIL: kode palsu dinyatakan valid';
  end if;
end $$;

-- 9. prospek/outreach tidak terlihat anon
do $$
begin
  if (select count(*) from public.prospects) <> 0 then
    raise exception 'FAIL: anon bisa membaca prospects';
  end if;
  if (select count(*) from public.commissions) <> 0 then
    raise exception 'FAIL: anon bisa membaca commissions';
  end if;
end $$;

reset role;

-- =============================================================
-- AUTHENTICATED TAPI BUKAN ENGINEER
-- =============================================================
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
begin
  if public.is_engineer() then
    raise exception 'FAIL: customer dianggap engineer';
  end if;
  if (select count(*) from public.transactions) <> 0 then
    raise exception 'FAIL: customer bisa membaca transactions';
  end if;
  if (select count(*) from public.prospects) <> 0 then
    raise exception 'FAIL: customer bisa membaca prospects';
  end if;
end $$;

-- RPC engineer harus menolak customer, bukan hanya UI yang menyembunyikan
do $$
begin
  perform public.analytics_overview(null, null);
  raise exception 'FAIL: customer bisa memanggil analytics_overview';
exception when sqlstate '42501' then null;
end $$;

do $$
begin
  perform public.analytics_funnel(null, null);
  raise exception 'FAIL: customer bisa memanggil analytics_funnel';
exception when sqlstate '42501' then null;
end $$;

do $$
begin
  perform public.record_payment(
    (select id from public.requests limit 1), 'SETTLEMENT', 1000, 'hack-1', null);
  raise exception 'FAIL: customer bisa mencatat pembayaran';
exception when sqlstate '42501' then null;
end $$;

do $$
begin
  perform public.import_prospects('[{"ig_username":"hacker.1"}]'::jsonb, null, 'MANUAL_ENTRY', null);
  raise exception 'FAIL: customer bisa mengimpor prospek';
exception when sqlstate '42501' then null;
end $$;

do $$
begin
  perform public.mark_commission_paid(gen_random_uuid(), null, null);
  raise exception 'FAIL: customer bisa menandai komisi lunas';
exception when sqlstate '42501' then null;
end $$;

reset role;

-- =============================================================
-- ENGINEER
-- =============================================================
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
begin
  if not public.is_engineer() then
    raise exception 'FAIL: engineer tidak dikenali';
  end if;
  if (select count(*) from public.requests) = 0 then
    raise exception 'FAIL: engineer tidak bisa membaca requests';
  end if;
  if (select count(*) from public.prospects) <> 0 then
    raise exception 'FAIL: prospek masih kosong, hitungan harus 0';
  end if;
end $$;

reset role;
