-- =============================================================
-- Test: notifikasi perubahan status ke klien (klaim sekali per transisi)
-- =============================================================
set client_min_messages to warning;

-- ---------- fixtures ----------
insert into public.requests (order_no, customer_name, whatsapp, email, category, deadline,
                             description, status, quote_amount)
values ('JT9002', 'Fajar Nugroho', '628999999001', 'klien@contoh.test', 'web', 'besok',
        'uji notifikasi status', 'working', 750000)
on conflict (order_no) do update
  set status = 'working', status_notified = null, email = 'klien@contoh.test';

-- order tanpa email: tidak boleh mengklaim
insert into public.requests (order_no, customer_name, whatsapp, category, deadline,
                             description, status)
values ('JT9003', 'Tanpa Email', '628999999002', 'web', 'besok', 'uji tanpa email', 'working')
on conflict (order_no) do update set status = 'working', status_notified = null, email = null;

-- =============================================================
-- SUPERUSER: klaim pertama dapat 1 baris, kedua 0 (anti dobel klik)
-- =============================================================
do $$
declare n int;
begin
  select count(*) into n from public.claim_status_notification('JT9002', 'working');
  if n <> 1 then raise exception 'FAIL: klaim pertama harus 1 baris, dapat %', n; end if;

  select count(*) into n from public.claim_status_notification('JT9002', 'working');
  if n <> 0 then raise exception 'FAIL: klaim kedua harus 0 baris (dobel), dapat %', n; end if;
end $$;

-- status_notified terisi status yang dikabarkan
do $$
declare v text;
begin
  select status_notified into v from public.requests where order_no = 'JT9002';
  if v is distinct from 'working' then
    raise exception 'FAIL: status_notified harus working, dapat %', coalesce(v, 'null');
  end if;
end $$;

-- =============================================================
-- Status tidak cocok / order tanpa email -> tidak ada klaim
-- =============================================================
do $$
declare n int;
begin
  select count(*) into n from public.claim_status_notification('JT9002', 'done');
  if n <> 0 then raise exception 'FAIL: status tidak cocok seharusnya 0, dapat %', n; end if;

  select count(*) into n from public.claim_status_notification('JT9003', 'working');
  if n <> 0 then raise exception 'FAIL: order tanpa email seharusnya 0, dapat %', n; end if;

  select count(*) into n from public.claim_status_notification('JT000000', 'working');
  if n <> 0 then raise exception 'FAIL: order tidak ada seharusnya 0, dapat %', n; end if;
end $$;

-- =============================================================
-- Gagal kirim -> release -> bisa klaim lagi
-- =============================================================
do $$
declare n int;
begin
  perform public.release_status_notification('JT9002', 'working');
  select count(*) into n from public.claim_status_notification('JT9002', 'working');
  if n <> 1 then raise exception 'FAIL: setelah release harus bisa klaim lagi, dapat %', n; end if;
end $$;

-- =============================================================
-- Balik ke status lama tetap dikabari (working -> review -> working)
-- =============================================================
do $$
declare n int;
begin
  update public.requests set status = 'review' where order_no = 'JT9002';
  select count(*) into n from public.claim_status_notification('JT9002', 'review');
  if n <> 1 then raise exception 'FAIL: status review harus dikabari, dapat %', n; end if;

  update public.requests set status = 'working' where order_no = 'JT9002';
  select count(*) into n from public.claim_status_notification('JT9002', 'working');
  if n <> 1 then raise exception 'FAIL: balik ke working harus dikabari lagi, dapat %', n; end if;
end $$;

-- =============================================================
-- ANON & AUTHENTICATED: tidak boleh memakai RPC klaim
-- =============================================================
set role anon;
set request.jwt.claim.role = 'anon';
set request.jwt.claim.sub = '';

do $$
begin
  perform public.claim_status_notification('JT9002', 'done');
  raise exception 'FAIL: anon bisa memanggil claim_status_notification';
exception when insufficient_privilege then null;
end $$;

do $$
begin
  perform public.release_status_notification('JT9002', 'done');
  raise exception 'FAIL: anon bisa memanggil release_status_notification';
exception when insufficient_privilege then null;
end $$;

reset role;

-- authenticated juga ditolak
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
begin
  perform public.claim_status_notification('JT9002', 'done');
  raise exception 'FAIL: authenticated bisa memanggil claim_status_notification';
exception when insufficient_privilege then null;
end $$;

reset role;
