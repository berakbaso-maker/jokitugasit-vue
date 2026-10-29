-- =============================================================
-- Test: uang bulat, DP belum eligible, komisi tidak dobel, refund.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- helper: buat proyek baru dengan kode referral aktif
create or replace function pg_temp.new_project(
  p_quote bigint, p_discount bigint default 0, p_ref text default 'REF-ANDI23'
) returns uuid language plpgsql as $$
declare v_id uuid; v_order text;
begin
  v_order := 'JTT' || lpad((floor(random()*900000)+100000)::int::text, 6, '0');
  insert into public.requests (order_no, customer_name, description, category, deadline,
                               status, quote_amount, discount_amount, referral_code)
  values (v_order, 'Klien Uji', 'proyek uji', 'web', 'fleksibel',
          'working', p_quote, p_discount, p_ref)
  returning id into v_id;
  return v_id;
end $$;

-- ---------- DP 50% belum menghasilkan komisi ----------
do $$
declare pid uuid; c record;
begin
  pid := pg_temp.new_project(1000000, 50000);   -- total eligible 950.000

  perform public.record_payment(pid, 'DP', 475000, 'dp-1', 'transfer');

  select * into c from public.commissions where request_id = pid;
  if c.status <> 'PENDING' then
    raise exception 'FAIL: DP langsung bikin komisi %, harus PENDING', c.status;
  end if;
  if c.eligible_amount <> 0 then
    raise exception 'FAIL: eligible_amount DP harus 0, dapat %', c.eligible_amount;
  end if;
  if c.amount <> 0 then
    raise exception 'FAIL: komisi DP harus 0, dapat %', c.amount;
  end if;
end $$;

-- ---------- pelunasan -> eligible, diskon diperhitungkan ----------
do $$
declare pid uuid; c record;
begin
  select id into pid from public.requests where customer_name = 'Klien Uji' order by created_at limit 1;
  perform public.record_payment(pid, 'SETTLEMENT', 475000, 'settle-1', 'transfer');

  select * into c from public.commissions where request_id = pid;
  if c.status <> 'ELIGIBLE' then
    raise exception 'FAIL: setelah lunas status harus ELIGIBLE, dapat %', c.status;
  end if;
  if c.eligible_amount <> 950000 then
    raise exception 'FAIL: eligible harus 950000, dapat %', c.eligible_amount;
  end if;
  if c.amount <> 95000 then
    raise exception 'FAIL: komisi 10%% dari 950000 harus 95000, dapat %', c.amount;
  end if;
  if c.rate_bps <> 1000 then
    raise exception 'FAIL: rate_bps harus 1000';
  end if;
end $$;

-- ---------- idempotensi: kunci sama tidak menggandakan ----------
do $$
declare pid uuid; before_count int; before_amount bigint;
begin
  select id into pid from public.requests where customer_name = 'Klien Uji' order by created_at limit 1;
  select count(*), coalesce(sum(amount),0) into before_count, before_amount
  from public.payments where request_id = pid;

  perform public.record_payment(pid, 'SETTLEMENT', 475000, 'settle-1', 'transfer');

  if (select count(*) from public.payments where request_id = pid) <> before_count then
    raise exception 'FAIL: idempotency_key sama membuat baris pembayaran baru';
  end if;
  if (select sum(amount) from public.payments where request_id = pid and kind <> 'REFUND') <> before_amount then
    raise exception 'FAIL: nominal pembayaran bertambah';
  end if;
  if (select amount from public.commissions where request_id = pid) <> 95000 then
    raise exception 'FAIL: komisi berubah setelah request idempoten';
  end if;
end $$;

-- ---------- pembayaran luber tidak menaikkan komisi ----------
do $$
declare pid uuid;
begin
  select id into pid from public.requests where customer_name = 'Klien Uji' order by created_at limit 1;
  perform public.record_payment(pid, 'SETTLEMENT', 2000000, 'over-1', 'transfer');
  if (select amount from public.commissions where request_id = pid) <> 95000 then
    raise exception 'FAIL: kelebihan bayar menaikkan komisi jadi %',
      (select amount from public.commissions where request_id = pid);
  end if;
end $$;

-- ---------- bayar komisi -> PAID + sinkron ke kolom lama ----------
do $$
declare pid uuid; c record;
begin
  select id into pid from public.requests where customer_name = 'Klien Uji' order by created_at limit 1;

  select * into c from public.mark_commission_paid(
    (select id from public.commissions where request_id = pid), 'https://bukti/1.png', 'transfer DANA');

  if c.status <> 'PAID' or c.paid_at is null then
    raise exception 'FAIL: komisi tidak jadi PAID';
  end if;
  if c.payment_proof <> 'https://bukti/1.png' then
    raise exception 'FAIL: bukti pembayaran komisi tidak tersimpan';
  end if;
  if c.note <> 'transfer DANA' then
    raise exception 'FAIL: catatan payout tidak tersimpan';
  end if;
  if not (select commission_paid from public.requests where id = pid) then
    raise exception 'FAIL: kolom lama commission_paid tidak tersinkron';
  end if;

  -- PAID tidak boleh turun lagi walau pembayaran dihitung ulang
  perform public.recompute_commission(pid);
  if (select status from public.commissions where request_id = pid) <> 'PAID' then
    raise exception 'FAIL: PAID turun setelah recompute';
  end if;
end $$;

-- ---------- mark_commission_paid menolak yang belum eligible ----------
do $$
declare pid uuid; cid uuid;
begin
  pid := pg_temp.new_project(800000);
  perform public.record_payment(pid, 'DP', 400000, 'dp-2', 'transfer');
  select id into cid from public.commissions where request_id = pid;
  begin
    perform public.mark_commission_paid(cid, null, null);
    raise exception 'FAIL: komisi PENDING bisa dibayar';
  exception when sqlstate '22023' then null;
  end;
end $$;

-- ---------- refund mengurangi eligible ----------
do $$
declare pid uuid; c record;
begin
  pid := pg_temp.new_project(500000);
  perform public.record_payment(pid, 'SETTLEMENT', 500000, 'full-refundable', 'transfer');
  if (select eligible_amount from public.commissions where request_id = pid) <> 500000 then
    raise exception 'FAIL: eligible awal harus 500000';
  end if;

  perform public.record_payment(pid, 'REFUND', 100000, 'refund-1', 'transfer');

  select * into c from public.commissions where request_id = pid;
  if c.eligible_amount <> 400000 then
    raise exception 'FAIL: setelah refund 100000 eligible harus 400000, dapat %', c.eligible_amount;
  end if;
  if c.amount <> 40000 then
    raise exception 'FAIL: komisi setelah refund harus 40000, dapat %', c.amount;
  end if;
end $$;

-- ---------- refund penuh -> tidak ada komisi ----------
do $$
declare pid uuid; c record;
begin
  pid := pg_temp.new_project(300000);
  perform public.record_payment(pid, 'SETTLEMENT', 300000, 'full-3', 'transfer');
  perform public.record_payment(pid, 'REFUND', 300000, 'refund-3', 'transfer');

  select * into c from public.commissions where request_id = pid;
  if c.eligible_amount <> 0 or c.status <> 'VOID' then
    raise exception 'FAIL: refund penuh harus membatalkan (VOID), dapat % / %', c.eligible_amount, c.status;
  end if;
end $$;

-- ---------- refund setelah komisi dibayar -> ADJUSTMENT, nominal tidak ditulis ulang ----------
do $$
declare pid uuid; c record;
begin
  pid := pg_temp.new_project(1000000);
  perform public.record_payment(pid, 'SETTLEMENT', 1000000, 'paid-then-refund', 'transfer');
  perform public.mark_commission_paid(
    (select id from public.commissions where request_id = pid), 'https://bukti/2.png', null);

  perform public.record_payment(pid, 'REFUND', 250000, 'refund-after-paid', 'transfer');

  select * into c from public.commissions where request_id = pid;
  if c.status <> 'ADJUSTMENT' then
    raise exception 'FAIL: refund setelah PAID harus ADJUSTMENT, dapat %', c.status;
  end if;
  if c.amount <> 100000 then
    raise exception 'FAIL: nominal yang sudah dibayar tidak boleh ditulis ulang, dapat %', c.amount;
  end if;
end $$;

-- ---------- tanpa kode referral -> tanpa komisi ----------
do $$
declare pid uuid;
begin
  pid := pg_temp.new_project(700000, 0, null);
  perform public.record_payment(pid, 'SETTLEMENT', 700000, 'noref-1', 'transfer');
  if exists (select 1 from public.commissions where request_id = pid) then
    raise exception 'FAIL: proyek tanpa referral menghasilkan komisi';
  end if;
end $$;

-- ---------- kode partner nonaktif -> tidak dapat komisi ----------
do $$
declare pid uuid;
begin
  update public.partners set status = 'inactive' where referral_code = 'REF-ANDI23';
  pid := pg_temp.new_project(400000);
  perform public.record_payment(pid, 'SETTLEMENT', 400000, 'inactive-1', 'transfer');
  if exists (select 1 from public.commissions where request_id = pid) then
    raise exception 'FAIL: kode nonaktif masih menghasilkan komisi';
  end if;
  update public.partners set status = 'active' where referral_code = 'REF-ANDI23';
end $$;

-- ---------- pembulatan integer untuk nominal ganjil ----------
do $$
declare pid uuid; c record;
begin
  pid := pg_temp.new_project(333333);
  perform public.record_payment(pid, 'SETTLEMENT', 333333, 'odd-1', 'transfer');
  select * into c from public.commissions where request_id = pid;
  if c.amount <> 33333 then
    raise exception 'FAIL: 10%% dari 333333 harus 33333 (truncate), dapat %', c.amount;
  end if;
  if c.amount::text like '%.%' then
    raise exception 'FAIL: komisi bukan integer';
  end if;
end $$;

-- ---------- analytics membaca tabel, bukan angka statis ----------
do $$
declare a jsonb; f record;
begin
  a := public.analytics_overview(null, null);
  if (a ->> 'prospects_total')::int <> 2 then
    raise exception 'FAIL: analytics prospek salah: %', a ->> 'prospects_total';
  end if;
  if (a ->> 'partners_with_deal')::int < 1 then
    raise exception 'FAIL: partners_with_deal harus >= 1';
  end if;
  if (a ->> 'commission_paid')::bigint < 95000 then
    raise exception 'FAIL: commission_paid salah: %', a ->> 'commission_paid';
  end if;

  select * into f from public.analytics_funnel(null, null) where stage = 'Berminat';
  if f.count <> 0 then
    raise exception 'FAIL: belum ada prospek berminat, harus 0, dapat %', f.count;
  end if;
end $$;

reset role;
drop function pg_temp.new_project(bigint, bigint, text);
