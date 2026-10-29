-- =============================================================
-- Test: import batch audit, statistik, dan konversi prospek.
-- =============================================================
set client_min_messages to warning;

set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- ---------- import batch tercatat ----------
do $$
declare r record; b record;
begin
  select * into r from public.import_prospects_batch(
    'angkatan-2026.csv',
    '[{"ig_username":"batch.baru","campus":"Binus"},
      {"ig_username":"@SITI_OK","campus":"Telkom"},
      {"ig_username":"andi.23"},
      {"ig_username":"bukan username!"}]'::jsonb,
    null,
    'ADMIN_SHARED_LIST'
  );

  if r.inserted_count <> 1 then
    raise exception 'FAIL: harus 1 baris baru, dapat %', r.inserted_count;
  end if;
  if r.duplicate_existing < 2 then
    raise exception 'FAIL: duplikat existing harus >= 2, dapat %', r.duplicate_existing;
  end if;
  if r.invalid_count <> 1 then
    raise exception 'FAIL: harus 1 invalid, dapat %', r.invalid_count;
  end if;
  if r.suppressed_count < 1 then
    raise exception 'FAIL: prospek DNC harus terhitung suppressed, dapat %', r.suppressed_count;
  end if;

  select * into b from public.import_batches where id = r.batch_id;
  if not found then
    raise exception 'FAIL: batch tidak tersimpan';
  end if;
  if b.file_name <> 'angkatan-2026.csv' or b.permission_basis <> 'ADMIN_SHARED_LIST' then
    raise exception 'FAIL: metadata batch salah';
  end if;
  if b.total_rows <> 4 or b.inserted_count <> r.inserted_count then
    raise exception 'FAIL: ringkasan batch tidak cocok (% / %)', b.total_rows, b.inserted_count;
  end if;

  -- DNC lama tidak berubah karena import
  if not (select do_not_contact from public.prospects where ig_username = 'andi.23') then
    raise exception 'FAIL: import ulang melepas DNC';
  end if;
end $$;

-- ---------- statistik prospek dari database ----------
do $$
declare s record;
begin
  select * into s from public.prospect_stats();
  if s.total < 3 then
    raise exception 'FAIL: total prospek terlalu kecil: %', s.total;
  end if;
  if s.dnc < 1 then
    raise exception 'FAIL: jumlah DNC harus >= 1';
  end if;
  if s.total <> (
    select count(*) from public.prospects
  ) then
    raise exception 'FAIL: statistik total tidak sama dengan tabel';
  end if;
end $$;

-- ---------- konversi prospek -> proyek ----------
do $$
declare pid uuid; r public.requests; st text;
begin
  select id into pid from public.prospects where ig_username = 'batch.baru';

  r := public.create_request_from_prospect(
    pid, 'web', 'bikin landing page tugas', 350000);
  if r.prospect_id <> pid then
    raise exception 'FAIL: request tidak terhubung ke prospek';
  end if;
  if r.source <> 'DIRECT_DM' then
    raise exception 'FAIL: sumber hasil konversi harus DIRECT_DM, dapat %', r.source;
  end if;
  if r.quote_amount <> 350000 then
    raise exception 'FAIL: quote tidak tersimpan';
  end if;

  select status into st from public.prospects where id = pid;
  if st <> 'CONVERTED' then
    raise exception 'FAIL: prospek harus CONVERTED, dapat %', st;
  end if;
end $$;

-- ---------- konversi ganda ditolak ----------
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'batch.baru';
  begin
    perform public.create_request_from_prospect(pid, 'web', 'lagi', 100000);
    raise exception 'FAIL: prospek yang sama bisa dikonversi dua kali';
  exception when unique_violation then null;
  end;
end $$;

-- ---------- prospek DNC tidak bisa dikonversi ----------
do $$
declare pid uuid;
begin
  select id into pid from public.prospects where ig_username = 'andi.23';
  begin
    perform public.create_request_from_prospect(pid, 'web', 'paksa', 100000);
    raise exception 'FAIL: prospek DNC bisa dikonversi';
  exception when sqlstate '42501' then null;
  end;
end $$;

-- ---------- non-engineer ditolak ----------
reset role;
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
begin
  begin
    perform public.import_prospects_batch('x.csv', '[{"ig_username":"hacker.batch"}]'::jsonb, null, 'MANUAL_ENTRY');
    raise exception 'FAIL: customer bisa import batch';
  exception when sqlstate '42501' then null;
  end;

  begin
    perform public.prospect_stats();
    raise exception 'FAIL: customer bisa membaca statistik prospek';
  exception when sqlstate '42501' then null;
  end;

  begin
    perform public.create_request_from_prospect(gen_random_uuid(), 'web', 'x', 1);
    raise exception 'FAIL: customer bisa konversi prospek';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
