-- =============================================================
-- Test: alur pembayaran (Slice 1)
--   * DP tidak melunasi proyek
--   * pelunasan -> status 'paid' + komisi ELIGIBLE
--   * void pembayaran -> status & komisi mundur dengan benar
--   * data lama 'paid' tanpa payments tidak disentuh
--   * refund penuh -> proyek tidak lagi dianggap lunas
--   * non-engineer tidak bisa void
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- partner khusus test ini
insert into public.partners (full_name, whatsapp, referral_code, status)
values ('Partner Flow', '6281234567899', 'REF-FLOW99', 'active')
on conflict (referral_code) do nothing;

create or replace function pg_temp.flow_project(
  p_quote bigint, p_discount bigint default 0, p_ref text default 'REF-FLOW99'
) returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into public.requests (order_no, customer_name, whatsapp, description, category, deadline,
                               status, quote_amount, discount_amount, referral_code)
  values ('JTF' || lpad((floor(random()*900000)+100000)::int::text, 6, '0'),
          'Klien Flow', '628111222333', 'proyek uji alur pembayaran', 'web', 'fleksibel',
          'working', p_quote, p_discount, p_ref)
  returning id into v_id;
  return v_id;
end $$;

-- ---------- DP: proyek belum lunas, komisi PENDING ----------
do $$
declare pid uuid; st text; c text;
begin
  pid := pg_temp.flow_project(1000000);

  perform public.record_payment(pid, 'DP', 500000, 'flow-dp-1', 'transfer');

  select status into st from public.requests where id = pid;
  if st <> 'working' then
    raise exception 'FAIL: DP tidak boleh melunasi proyek, status = %', st;
  end if;

  select status into c from public.commissions where request_id = pid;
  if c <> 'PENDING' then
    raise exception 'FAIL: komisi setelah DP harus PENDING, dapat %', c;
  end if;
end $$;

-- ---------- pelunasan: status paid + komisi ELIGIBLE ----------
do $$
declare pid uuid; st text; c record;
begin
  select id into pid from public.requests where customer_name = 'Klien Flow' order by created_at limit 1;

  perform public.record_payment(pid, 'SETTLEMENT', 500000, 'flow-settle-1', 'transfer');

  select status into st from public.requests where id = pid;
  if st <> 'paid' then
    raise exception 'FAIL: setelah pelunasan status harus paid, dapat %', st;
  end if;

  select * into c from public.commissions where request_id = pid;
  if c.status <> 'ELIGIBLE' or c.amount <> 100000 then
    raise exception 'FAIL: komisi harus ELIGIBLE 100000, dapat % / %', c.status, c.amount;
  end if;
end $$;

-- ---------- void pelunasan: status & komisi mundur, audit tercatat ----------
do $$
declare pid uuid; pay_id uuid; st text; c text; p record;
begin
  select id into pid from public.requests where customer_name = 'Klien Flow' order by created_at limit 1;
  select id into pay_id from public.payments
   where request_id = pid and kind = 'SETTLEMENT' and status = 'CONFIRMED';

  p := public.void_payment(pay_id, 'salah input nominal');
  if p.status <> 'VOID' or p.voided_at is null or p.void_reason is null then
    raise exception 'FAIL: void tidak menulis audit';
  end if;

  select status into st from public.requests where id = pid;
  if st <> 'working' then
    raise exception 'FAIL: setelah void status harus working, dapat %', st;
  end if;

  select status into c from public.commissions where request_id = pid;
  if c <> 'PENDING' then
    raise exception 'FAIL: setelah void komisi harus PENDING, dapat %', c;
  end if;

  -- nominal yang sudah di-void tidak ikut dihitung sebagai pembayaran
  if (select coalesce(sum(amount), 0) from public.payments
      where request_id = pid and status = 'CONFIRMED' and kind <> 'REFUND') <> 500000 then
    raise exception 'FAIL: pembayaran void masih dihitung';
  end if;
end $$;

-- ---------- void dua kali ditolak ----------
do $$
declare pay_id uuid;
begin
  select id into pay_id from public.payments
   where kind = 'SETTLEMENT' and status = 'VOID'
   order by voided_at desc limit 1;
  begin
    perform public.void_payment(pay_id, 'coba lagi');
    raise exception 'FAIL: pembayaran VOID bisa dibatalkan dua kali';
  exception when sqlstate '22023' then null;
  end;
end $$;

-- ---------- void tanpa alasan ditolak ----------
do $$
declare pay_id uuid;
begin
  select id into pay_id from public.payments
   where request_id = (select id from public.requests where customer_name = 'Klien Flow' order by created_at limit 1)
     and status = 'CONFIRMED' limit 1;
  begin
    perform public.void_payment(pay_id, '   ');
    raise exception 'FAIL: void tanpa alasan diterima';
  exception when sqlstate '22023' then null;
  end;
end $$;

-- ---------- data lama 'paid' tanpa payments tidak disentuh ----------
do $$
declare pid uuid; st text;
begin
  insert into public.requests (order_no, customer_name, description, category, deadline,
                               status, quote_amount)
  values ('JTFLEGACY1', 'Klien Legacy', 'data lama', 'web', 'besok', 'paid', 750000)
  returning id into pid;

  perform public.sync_request_payment_status(pid);

  select status into st from public.requests where id = pid;
  if st <> 'paid' then
    raise exception 'FAIL: status legacy paid diturunkan menjadi %', st;
  end if;
end $$;

-- ---------- refund penuh: proyek tidak lagi lunas ----------
do $$
declare pid uuid; st text; c text;
begin
  pid := pg_temp.flow_project(300000);
  perform public.record_payment(pid, 'SETTLEMENT', 300000, 'flow-full-1', 'transfer');
  perform public.record_payment(pid, 'REFUND', 300000, 'flow-refund-1', 'transfer');

  select status into st from public.requests where id = pid;
  if st = 'paid' then
    raise exception 'FAIL: proyek yang direfund penuh masih paid';
  end if;

  select status into c from public.commissions where request_id = pid;
  if c <> 'VOID' then
    raise exception 'FAIL: komisi setelah refund penuh harus VOID, dapat %', c;
  end if;
end $$;

-- ---------- non-engineer tidak bisa void ----------
reset role;
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare pay_id uuid;
begin
  select id into pay_id from public.payments where status = 'CONFIRMED' limit 1;
  begin
    perform public.void_payment(pay_id, 'niat jahat');
    raise exception 'FAIL: customer bisa membatalkan pembayaran';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
drop function pg_temp.flow_project(bigint, bigint, text);
