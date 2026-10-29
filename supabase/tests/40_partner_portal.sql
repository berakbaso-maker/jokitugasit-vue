-- =============================================================
-- Test: portal partner hanya mengembalikan milik sendiri, tanpa
-- email/ewallet/whatsapp partner lain.
-- =============================================================
set client_min_messages to warning;

-- partner kedua
insert into public.partners (full_name, whatsapp, campus, referral_code, ewallet_info)
values ('Budi Santoso', '628222222222', 'Telkom', 'REF-BUDI77', 'OVO 082222222222')
on conflict (referral_code) do nothing;

set role anon;
set request.jwt.claim.role = 'anon';
set request.jwt.claim.sub = '';

do $$
declare p jsonb;
begin
  p := public.partner_portal('ref-andi23');

  if p is null then raise exception 'FAIL: portal tidak menemukan partner'; end if;
  if p -> 'partner' ->> 'referral_code' <> 'REF-ANDI23' then
    raise exception 'FAIL: kode partner salah';
  end if;
  -- data sensitif partner tidak boleh ikut keluar
  if (p::text) like '%ewallet%' or (p::text) like '%DANA 081111111111%' then
    raise exception 'FAIL: data e-wallet bocor lewat portal';
  end if;
  if (p::text) like '%628111111111%' then
    raise exception 'FAIL: nomor WhatsApp partner bocor lewat portal';
  end if;
  -- hanya komisi milik partner ini
  if exists (
    select 1 from jsonb_array_elements(p -> 'commissions') x
    where x ->> 'order_no' is null
  ) then
    raise exception 'FAIL: baris komisi tidak lengkap';
  end if;
end $$;

do $$
begin
  if public.partner_portal('REF-NGAWUR') is not null then
    raise exception 'FAIL: kode palsu mengembalikan data';
  end if;
end $$;

do $$
begin
  if public.partner_portal('REF-BUDI77') -> 'partner' ->> 'full_name' <> 'Budi Santoso' then
    raise exception 'FAIL: partner lain tidak bisa membuka portalnya sendiri';
  end if;
  -- Budi tidak boleh melihat komisi Andi
  if jsonb_array_length(public.partner_portal('REF-BUDI77') -> 'commissions') <> 0 then
    raise exception 'FAIL: Budi melihat komisi partner lain';
  end if;
end $$;

reset role;
