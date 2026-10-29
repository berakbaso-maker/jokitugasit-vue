-- =============================================================
-- Test: hapus prospek + suppression list + hapus target account.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ---------- hapus prospek: data hilang, suppression tersimpan ----------
do $$
declare ta uuid; pid uuid; req public.requests; logs int; st text;
begin
  insert into public.target_accounts (ig_username, campus, account_type)
  values ('hapus.kampus.2026', 'Kampus Hapus', 'COHORT')
  returning id into ta;

  insert into public.prospects (ig_username, display_name, campus, source_account_id)
  values ('hapus.aku', 'Nama Pribadi', 'Kampus Hapus', ta)
  returning id into pid;

  perform public.log_outreach(pid, null, 'SENT', 'uji hapus', 'INSTAGRAM_DM_MANUAL');

  req := public.create_request_from_prospect(pid, 'web', 'proyek uji hapus', 100000);

  perform public.delete_prospect(pid, 'permintaan penghapusan pemilik data', true);

  if exists (select 1 from public.prospects where id = pid) then
    raise exception 'FAIL: prospek masih ada setelah dihapus';
  end if;
  if not exists (select 1 from public.prospect_suppressions where ig_username = 'hapus.aku') then
    raise exception 'FAIL: suppression tidak tercatat';
  end if;
  select count(*) into logs from public.outreach_logs where prospect_id = pid;
  if logs <> 0 then
    raise exception 'FAIL: log outreach tidak ikut terhapus';
  end if;
  select prospect_id into pid from public.requests where id = req.id;
  if pid is not null then
    raise exception 'FAIL: requests.prospect_id tidak di-set null';
  end if;
end $$;

-- ---------- import ulang tidak menghidupkan lagi ----------
do $$
declare r record;
begin
  select * into r from public.import_prospects(
    '[{"ig_username":"hapus.aku","campus":"Kampus Hapus"}]'::jsonb,
    null, 'MANUAL_ENTRY', null);

  if r.inserted_count <> 0 then
    raise exception 'FAIL: prospek yang dihapus dibuat ulang';
  end if;
  if r.suppressed_count <> 1 then
    raise exception 'FAIL: suppression tidak dihitung, dapat %', r.suppressed_count;
  end if;
  if exists (select 1 from public.prospects where ig_username = 'hapus.aku') then
    raise exception 'FAIL: prospek suppressed muncul lagi';
  end if;
end $$;

-- ---------- hapus tanpa suppression: boleh diimpor lagi (koreksi typo) ----------
do $$
declare pid uuid;
begin
  insert into public.prospects (ig_username, campus) values ('hapus.typo', 'X')
  returning id into pid;

  perform public.delete_prospect(pid, 'salah input username', false);

  if exists (select 1 from public.prospect_suppressions where ig_username = 'hapus.typo') then
    raise exception 'FAIL: koreksi typo ikut masuk suppression';
  end if;

  perform public.import_prospects('[{"ig_username":"hapus.typo"}]'::jsonb, null, 'MANUAL_ENTRY', null);
  if not exists (select 1 from public.prospects where ig_username = 'hapus.typo') then
    raise exception 'FAIL: prospek non-suppressed tidak bisa diimpor lagi';
  end if;
end $$;

-- ---------- prospek DNC selalu masuk suppression ----------
do $$
declare pid uuid;
begin
  insert into public.prospects (ig_username, do_not_contact, status, do_not_contact_reason)
  values ('hapus.dnc', true, 'DO_NOT_CONTACT', 'minta jangan dihubungi')
  returning id into pid;

  perform public.delete_prospect(pid, 'permintaan hapus', false);

  if not exists (select 1 from public.prospect_suppressions where ig_username = 'hapus.dnc') then
    raise exception 'FAIL: DNC hilang saat prospek dihapus tanpa suppression';
  end if;
end $$;

-- ---------- validasi alasan & data ----------
do $$
declare pid uuid;
begin
  insert into public.prospects (ig_username) values ('hapus.tanpa.alasan') returning id into pid;

  begin
    perform public.delete_prospect(pid, '   ', false);
    raise exception 'FAIL: hapus tanpa alasan diterima';
  exception when sqlstate '22023' then null;
  end;

  begin
    perform public.delete_prospect(gen_random_uuid(), 'tidak ada', false);
    raise exception 'FAIL: hapus prospek fiktif diterima';
  exception when sqlstate 'P0002' then null;
  end;
end $$;

-- ---------- hapus target account: prospek tetap, sumber dikosongkan ----------
do $$
declare ta uuid; pid uuid;
begin
  insert into public.target_accounts (ig_username, campus, account_type)
  values ('target.hapus.2026', 'Kampus Target', 'COHORT')
  returning id into ta;

  insert into public.prospects (ig_username, source_account_id)
  values ('sumber.target', ta)
  returning id into pid;

  delete from public.target_accounts where id = ta;

  if exists (select 1 from public.target_accounts where id = ta) then
    raise exception 'FAIL: target account masih ada';
  end if;
  if (select source_account_id from public.prospects where id = pid) is not null then
    raise exception 'FAIL: source_account_id tidak null setelah akun dihapus';
  end if;
end $$;

-- ---------- non-engineer ditolak ----------
-- Simpan id prospek sebelum ganti role: customer tidak bisa membaca tabel.
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'siti_ok';
  if pid is null then
    raise exception 'FAIL: fixture siti_ok tidak ditemukan';
  end if;
  perform set_config('test.subject_prospect', pid::text, false);
end $$;

reset role;
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare pid uuid;
begin
  pid := current_setting('test.subject_prospect')::uuid;

  begin
    perform public.delete_prospect(pid, 'niat jahat', true);
    raise exception 'FAIL: customer bisa menghapus prospek';
  exception when sqlstate '42501' then null;
  end;

  if public.is_engineer() then
    raise exception 'FAIL: customer dianggap engineer';
  end if;
end $$;

reset role;
