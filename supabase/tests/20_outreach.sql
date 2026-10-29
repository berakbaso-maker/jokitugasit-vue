-- =============================================================
-- Test: CSV/import dedupe, normalisasi username, dan DNC yang lengket.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ---------- normalisasi ----------
do $$
begin
  if public.normalize_ig_username('  @Andi.23  ') <> 'andi.23' then
    raise exception 'FAIL: normalisasi gagal: %', public.normalize_ig_username('  @Andi.23  ');
  end if;
  if public.normalize_ig_username(null) <> '' then
    raise exception 'FAIL: null harus jadi string kosong';
  end if;
end $$;

-- ---------- target account ----------
insert into public.target_accounts (ig_username, campus, major, cohort_year, account_type)
values ('hmif.binus.2023', 'Binus', 'Informatika', 2023, 'COHORT');

-- ---------- import dengan data kotor ----------
do $$
declare
  src uuid;
  r record;
begin
  select id into src from public.target_accounts where ig_username = 'hmif.binus.2023';

  select * into r from public.import_prospects(
    '[
      {"ig_username":"  @Andi.23  ","display_name":"Andi","campus":"Binus","cohort_year":2023},
      {"ig_username":"andi.23"},
      {"ig_username":"bukan username!"},
      {"ig_username":""},
      {"ig_username":"Siti_OK","display_name":"Siti"}
    ]'::jsonb,
    src, 'ADMIN_SHARED_LIST', null
  );

  if r.inserted_count <> 2 then
    raise exception 'FAIL: inserted_count harus 2, dapat %', r.inserted_count;
  end if;
  if r.duplicate_in_file <> 1 then
    raise exception 'FAIL: duplicate_in_file harus 1, dapat %', r.duplicate_in_file;
  end if;
  if r.invalid_count <> 2 then
    raise exception 'FAIL: invalid_count harus 2, dapat %', r.invalid_count;
  end if;
  if (select ig_username::text from public.prospects where display_name = 'Andi') <> 'andi.23' then
    raise exception 'FAIL: username tidak dinormalisasi saat insert';
  end if;
  if (select campus from public.prospects where display_name = 'Andi') <> 'Binus' then
    raise exception 'FAIL: kampus tidak tersimpan';
  end if;
end $$;

-- ---------- import ulang tidak menggandakan ----------
do $$
declare r record;
begin
  select * into r from public.import_prospects(
    '[{"ig_username":"andi.23"},{"ig_username":"siti_ok"}]'::jsonb,
    null, 'MANUAL_ENTRY', null
  );
  if r.inserted_count <> 0 or r.duplicate_existing <> 2 then
    raise exception 'FAIL: re-import harus 0 baru / 2 duplikat, dapat % / %',
      r.inserted_count, r.duplicate_existing;
  end if;
  if (select count(*) from public.prospects) <> 2 then
    raise exception 'FAIL: jumlah prospek berubah jadi %', (select count(*) from public.prospects);
  end if;
end $$;

-- ---------- tandai DNC ----------
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'andi.23';
  perform public.log_outreach(pid, null, 'DO_NOT_CONTACT', 'minta tidak dihubungi');

  if not (select do_not_contact from public.prospects where id = pid) then
    raise exception 'FAIL: DNC tidak tersimpan';
  end if;
  if (select status from public.prospects where id = pid) <> 'DO_NOT_CONTACT' then
    raise exception 'FAIL: status DNC tidak tersinkron';
  end if;
  if (select do_not_contact_at from public.prospects where id = pid) is null then
    raise exception 'FAIL: do_not_contact_at tidak diisi';
  end if;
end $$;

-- ---------- DNC tidak bisa dilepas update biasa ----------
do $$
begin
  update public.prospects set do_not_contact = false where ig_username = 'andi.23';
  raise exception 'FAIL: DNC berhasil dilepas tanpa override';
exception when sqlstate '42501' then null;
end $$;

-- ---------- re-import tetap tidak menghidupkan lagi ----------
do $$
declare r record;
begin
  select * into r from public.import_prospects(
    '[{"ig_username":"ANDI.23","campus":"Binus"}]'::jsonb,
    null, 'ADMIN_SHARED_LIST', null
  );
  if r.suppressed_count <> 1 then
    raise exception 'FAIL: suppressed_count harus 1, dapat %', r.suppressed_count;
  end if;
  if not (select do_not_contact from public.prospects where ig_username = 'andi.23') then
    raise exception 'FAIL: import ulang menghapus DNC';
  end if;
end $$;

-- ---------- queue tidak menampilkan DNC ----------
do $$
begin
  if exists (select 1 from public.prospects
             where do_not_contact
               and status in ('NEW','READY_TO_REVIEW')) then
    raise exception 'FAIL: prospek DNC muncul di queue';
  end if;
end $$;

-- ---------- tidak bisa kirim DM ke DNC ----------
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'andi.23';
  perform public.log_outreach(pid, null, 'SENT', null);
  raise exception 'FAIL: berhasil mencatat DM ke prospek DNC';
exception when sqlstate '42501' then null;
end $$;

-- ---------- log outreach normal ----------
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'siti_ok';
  perform public.log_outreach(pid, null, 'SENT', 'kirim perkenalan');
  if (select status from public.prospects where id = pid) <> 'CONTACTED' then
    raise exception 'FAIL: status tidak jadi CONTACTED';
  end if;
  if (select last_contacted_at from public.prospects where id = pid) is null then
    raise exception 'FAIL: last_contacted_at kosong';
  end if;
  if (select count(*) from public.outreach_logs where prospect_id = pid) <> 1 then
    raise exception 'FAIL: log outreach tidak tercatat';
  end if;
end $$;

-- ---------- DNC hanya bisa dilepas lewat RPC dengan alasan ----------
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'andi.23';
  begin
    perform public.clear_do_not_contact(pid, '  ');
    raise exception 'FAIL: DNC dilepas tanpa alasan';
  exception when sqlstate '22023' then null;
  end;

  perform public.clear_do_not_contact(pid, 'mahasiswa menghubungi lagi dan minta info');
  if (select do_not_contact from public.prospects where id = pid) then
    raise exception 'FAIL: DNC tidak terlepas lewat RPC';
  end if;
  if (select status from public.prospects where id = pid) <> 'NEW' then
    raise exception 'FAIL: status setelah lepas DNC harus NEW';
  end if;
  if not exists (select 1 from public.outreach_logs
                 where prospect_id = pid and note like '%DNC dilepas manual%') then
    raise exception 'FAIL: pelepasan DNC tidak teraudit';
  end if;

  -- kembalikan ke DNC untuk sisa test
  perform public.log_outreach(pid, null, 'DO_NOT_CONTACT', 'uji ulang');
end $$;

-- ---------- template tidak boleh menerima placeholder asing ----------
do $$
begin
  if (select body from public.dm_templates where category = 'WEBSITE_REPLY') !~ '\{website_url\}' then
    raise exception 'FAIL: seed template kehilangan placeholder';
  end if;
  if (select count(*) from public.dm_templates) < 5 then
    raise exception 'FAIL: seed template kurang';
  end if;
end $$;

reset role;
