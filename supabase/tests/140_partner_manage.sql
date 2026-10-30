-- =============================================================
-- Test: kelola partner (rekap, detail, kode custom) + atribusi permanen
-- =============================================================
set client_min_messages to warning;

-- ---------- fixtures ----------
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'engineer@test.local', '{"role":"engineer"}')
on conflict (id) do nothing;

insert into public.partners (full_name, whatsapp, campus, referral_code, ewallet_info)
values ('Citra Lestari', '628333333333', 'UI', 'REF-CITRA9', 'OVO 083333333333')
on conflict (referral_code) do nothing;

-- dipakai untuk uji kode duplikat / format salah
insert into public.partners (full_name, whatsapp, campus, referral_code, ewallet_info)
values ('Andi Pratama', '628111111111', 'Binus', 'REF-ANDI23', 'DANA 081111111111')
on conflict (referral_code) do nothing;

-- order baru yang mengikat partner lewat trigger referral_partner_id
insert into public.requests (order_no, customer_name, whatsapp, category, deadline,
                             description, status, quote_amount, referral_code)
values ('JT9001', 'Dewi', '628777777777', 'web', 'besok',
        'uji rekap partner', 'done', 1000000, 'REF-CITRA9')
on conflict (order_no) do update set referral_code = 'REF-CITRA9';

-- pembayaran penuh supaya ada komisi
insert into public.payments (request_id, kind, amount, status, idempotency_key)
select id, 'SETTLEMENT', 1000000, 'CONFIRMED', 'uji-partner-manage-1'
  from public.requests where order_no = 'JT9001'
on conflict (idempotency_key) do nothing;

select public.recompute_commission_internal((select id from public.requests where order_no = 'JT9001'));

-- =============================================================
-- SUPERUSER: trigger mengisi referral_partner_id
-- =============================================================
do $$
declare v_pid uuid; v_req uuid; v_link uuid;
begin
  select id into v_pid from public.partners where referral_code = 'REF-CITRA9';
  select id, referral_partner_id into v_req, v_link from public.requests where order_no = 'JT9001';
  if v_link is null then
    raise exception 'FAIL: trigger tidak mengisi referral_partner_id';
  end if;
  if v_link <> v_pid then
    raise exception 'FAIL: referral_partner_id menunjuk partner lain';
  end if;
end $$;

-- =============================================================
-- ENGINEER
-- =============================================================
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare s record;
begin
  select * into s from public.partner_summary() where referral_code = 'REF-CITRA9';
  if s is null then raise exception 'FAIL: rekap tidak memuat partner'; end if;
  if s.referrals < 1 then raise exception 'FAIL: referrals = %', s.referrals; end if;
  if s.deals < 1 then raise exception 'FAIL: deals = %', s.deals; end if;
  if s.commission_pending <= 0 then raise exception 'FAIL: komisi pending = %', s.commission_pending; end if;
  if s.gross < 1000000 then raise exception 'FAIL: omzet = %', s.gross; end if;
end $$;

do $$
declare d jsonb;
begin
  d := public.partner_detail((select id from public.partners where referral_code = 'REF-CITRA9'));
  if d -> 'partner' ->> 'referral_code' <> 'REF-CITRA9' then
    raise exception 'FAIL: detail partner salah';
  end if;
  if jsonb_array_length(d -> 'orders') < 1 then
    raise exception 'FAIL: detail tidak memuat order';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(d -> 'orders') o
    where o ->> 'order_no' = 'JT9001'
  ) then
    raise exception 'FAIL: order JT9001 tidak ada di detail';
  end if;
end $$;

-- kode custom: lowercase dinormalisasi
do $$
declare r public.partners;
begin
  r := public.set_partner_code((select id from public.partners where referral_code = 'REF-CITRA9'), 'ref-citrabaru');
  if r.referral_code <> 'REF-CITRABARU' then
    raise exception 'FAIL: kode tidak dinormalisasi: %', r.referral_code;
  end if;
end $$;

-- kode duplikat ditolak
do $$
begin
  perform public.set_partner_code(
    (select id from public.partners where referral_code = 'REF-ANDI23'),
    'REF-CITRABARU');
  raise exception 'FAIL: kode duplikat diterima';
exception when unique_violation then
  null; -- diharapkan
end $$;

-- format kode salah ditolak
do $$
begin
  perform public.set_partner_code(
    (select id from public.partners where referral_code = 'REF-ANDI23'), 'bukan ref!');
  raise exception 'FAIL: kode tidak valid diterima';
exception when sqlstate '22023' then
  null; -- diharapkan
end $$;

-- =============================================================
-- ATRIBUSI PERMANEN: ganti kode tidak boleh mem-VOID komisi lama
-- =============================================================
select public.recompute_commission((select id from public.requests where order_no = 'JT9001'));

do $$
declare st text;
begin
  select c.status into st from public.commissions c
    join public.requests r on r.id = c.request_id
   where r.order_no = 'JT9001';
  if st = 'VOID' then
    raise exception 'FAIL: komisi jadi VOID setelah kode partner diganti';
  end if;
end $$;

-- partner dinonaktifkan: komisi lama tetap sah
update public.partners set status = 'inactive' where referral_code = 'REF-CITRABARU';
select public.recompute_commission((select id from public.requests where order_no = 'JT9001'));

do $$
declare st text;
begin
  select c.status into st from public.commissions c
    join public.requests r on r.id = c.request_id
   where r.order_no = 'JT9001';
  if st = 'VOID' then
    raise exception 'FAIL: komisi jadi VOID setelah partner dinonaktifkan';
  end if;
end $$;

-- =============================================================
-- ANON: tidak boleh memakai RPC baru
-- =============================================================
reset role;
set role anon;
set request.jwt.claim.role = 'anon';
set request.jwt.claim.sub = '';

do $$
begin
  perform public.partner_summary();
  raise exception 'FAIL: anon bisa memanggil partner_summary';
exception when insufficient_privilege then
  null; -- diharapkan
end $$;

do $$
begin
  perform public.partner_detail('00000000-0000-0000-0000-000000000000');
  raise exception 'FAIL: anon bisa memanggil partner_detail';
exception when insufficient_privilege then
  null;
end $$;

do $$
begin
  perform public.set_partner_code('00000000-0000-0000-0000-000000000000', 'REF-HACK');
  raise exception 'FAIL: anon bisa memanggil set_partner_code';
exception when insufficient_privilege then
  null;
end $$;

reset role;
