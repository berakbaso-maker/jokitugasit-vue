-- =============================================================
-- Test: consent & outreach eligibility (V4 Slice A)
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ---------- import admin shared: consent UNKNOWN ----------
do $$
declare pid uuid; p record;
begin
  perform public.import_prospects(
    '[{"ig_username":"consent.admin","campus":"Kampus Consent"}]'::jsonb,
    null, 'ADMIN_SHARED_LIST', null);

  select * into p from public.prospects where ig_username = 'consent.admin';
  if p.consent_status <> 'UNKNOWN' then
    raise exception 'FAIL: admin-shared harus UNKNOWN, dapat %', p.consent_status;
  end if;
  if p.contact_permission_source <> 'ADMIN_PARTNER_SHARED_OPT_IN' then
    raise exception 'FAIL: sumber izin admin salah: %', p.contact_permission_source;
  end if;

  -- manual review tetap boleh, automated belum
  select * into p from public.outreach_eligibility(
    (select id from public.prospects where ig_username = 'consent.admin'), 'MANUAL_DM');
  if not p.eligible then
    raise exception 'FAIL: manual DM harus boleh untuk UNKNOWN';
  end if;

  select * into p from public.outreach_eligibility(
    (select id from public.prospects where ig_username = 'consent.admin'), 'AUTOMATED_DM');
  if p.eligible or p.reason <> 'CONSENT_REQUIRED' then
    raise exception 'FAIL: automated DM harus butuh consent, dapat % / %', p.eligible, p.reason;
  end if;
end $$;

-- ---------- import opt-in: consent OPTED_IN ----------
do $$
declare p record;
begin
  perform public.import_prospects(
    '[{"ig_username":"consent.optin"}]'::jsonb,
    null, 'INBOUND_OPT_IN', null);

  select * into p from public.prospects where ig_username = 'consent.optin';
  if p.consent_status <> 'OPTED_IN' or p.contact_permission_source <> 'WEBSITE_FORM' then
    raise exception 'FAIL: opt-in tidak tercatat (% / %)', p.consent_status, p.contact_permission_source;
  end if;
  if p.consent_at is null then
    raise exception 'FAIL: consent_at opt-in harus terisi';
  end if;
end $$;

-- ---------- opt-out menyalakan DNC ----------
do $$
declare pid uuid; p record; e record;
begin
  select id into pid from public.prospects where ig_username = 'consent.optin';

  p := public.set_prospect_consent(pid, 'OPTED_OUT', 'INBOUND_IG_DM');

  if not p.do_not_contact or p.status <> 'DO_NOT_CONTACT' then
    raise exception 'FAIL: opt-out tidak menyalakan DNC (% / %)', p.do_not_contact, p.status;
  end if;
  if p.consent_status <> 'OPTED_OUT' or p.consent_at is null then
    raise exception 'FAIL: status/consent_at opt-out salah';
  end if;

  select * into e from public.outreach_eligibility(pid, 'MANUAL_DM');
  if e.eligible then
    raise exception 'FAIL: prospek opt-out masih eligible';
  end if;

  -- opt-in saat DNC aktif harus ditolak
  begin
    perform public.set_prospect_consent(pid, 'OPTED_IN', 'WEBSITE_FORM');
    raise exception 'FAIL: opt-in saat DNC diterima';
  exception when sqlstate '42501' then null;
  end;
end $$;

-- ---------- re-import tidak mengubah opt-out ----------
do $$
declare p record;
begin
  perform public.import_prospects(
    '[{"ig_username":"consent.optin"}]'::jsonb,
    null, 'INBOUND_OPT_IN', null);

  select * into p from public.prospects where ig_username = 'consent.optin';
  if p.consent_status <> 'OPTED_OUT' or not p.do_not_contact then
    raise exception 'FAIL: re-import mengubah consent opt-out';
  end if;
end $$;

-- ---------- lepas DNC mereset consent ke UNKNOWN ----------
do $$
declare pid uuid; p record;
begin
  select id into pid from public.prospects where ig_username = 'consent.optin';
  p := public.clear_do_not_contact(pid, 'uji reset consent');

  if p.do_not_contact then
    raise exception 'FAIL: DNC masih aktif';
  end if;
  if p.consent_status <> 'UNKNOWN' then
    raise exception 'FAIL: consent harus UNKNOWN setelah lepas DNC, dapat %', p.consent_status;
  end if;
  if p.contact_permission_source <> 'MANUAL_CONTACT' then
    raise exception 'FAIL: sumber izin harus MANUAL_CONTACT';
  end if;
end $$;

-- ---------- non-engineer ditolak ----------
reset role;
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare pid uuid;
begin
  pid := current_setting('test.consent_prospect', true)::uuid;
  begin
    perform public.set_prospect_consent(pid, 'OPTED_IN', 'WEBSITE_FORM');
    raise exception 'FAIL: customer bisa mengubah consent';
  exception when sqlstate '42501' then null;
  end;

  begin
    perform public.outreach_eligibility(pid, 'MANUAL_DM');
    raise exception 'FAIL: customer bisa memanggil eligibility';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
