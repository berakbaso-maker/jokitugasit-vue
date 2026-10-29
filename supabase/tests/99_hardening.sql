-- =============================================================
-- Test: hardening (kode referral, rotasi, registrasi publik, chunk import)
-- =============================================================
set client_min_messages to warning;

-- ---------- format kode & registrasi publik (anon) ----------
set role anon;
set request.jwt.claim.role = 'anon';
set request.jwt.claim.sub = '';

do $$
declare r record;
begin
  r := public.register_partner('Partner Publik', '08999000111', 'Kampus Publik', 'DANA 08999000111');

  if r.referral_code !~ '^REF-[A-HJ-NP-Z2-9]{8}$' then
    raise exception 'FAIL: format kode baru salah: %', r.referral_code;
  end if;

  perform set_config('test.public_partner_id', r.partner_id::text, false);

  -- nomor yang sama tidak boleh mendaftar dua kali
  begin
    perform public.register_partner('Partner Publik 2', '08999000111');
    raise exception 'FAIL: nomor ganda diterima';
  exception when sqlstate '23505' then null;
  end;

  -- validasi nomor
  begin
    perform public.register_partner('X', '123');
    raise exception 'FAIL: nomor tidak valid diterima';
  exception when sqlstate '22023' then null;
  end;
end $$;

reset role;

-- ---------- rotasi kode (engineer) ----------
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
declare
  pid uuid := current_setting('test.public_partner_id')::uuid;
  old_code text;
  new_code text;
  still_valid boolean;
  i int;
  c text;
begin
  if not exists (
    select 1 from public.partners
    where id = pid and status = 'active' and whatsapp = '628999000111'
  ) then
    raise exception 'FAIL: partner publik tidak tersimpan benar';
  end if;

  -- kode yang dihasilkan berbeda-beda dan sesuai format
  for i in 1..5 loop
    c := public.generate_referral_code();
    if c !~ '^REF-[A-HJ-NP-Z2-9]{8}$' then
      raise exception 'FAIL: generate_referral_code menghasilkan %', c;
    end if;
  end loop;

  select referral_code into old_code from public.partners where id = pid;
  new_code := public.rotate_partner_code(pid);

  if new_code = old_code then
    raise exception 'FAIL: rotasi tidak mengubah kode';
  end if;
  if new_code !~ '^REF-[A-HJ-NP-Z2-9]{8}$' then
    raise exception 'FAIL: kode hasil rotasi tidak valid: %', new_code;
  end if;

  select exists (select 1 from public.validate_referral_code(old_code)) into still_valid;
  if still_valid then
    raise exception 'FAIL: kode lama masih valid setelah rotasi';
  end if;
  if (select referral_code from public.partners where id = pid) <> new_code then
    raise exception 'FAIL: kode baru tidak tersimpan';
  end if;

  perform set_config('test.partner_id', pid::text, false);
end $$;

-- ---------- chunk import memakai satu batch ----------
do $$
declare b uuid := gen_random_uuid(); r1 record; r2 record; row record;
begin
  select * into r1 from public.import_prospects_batch(
    'chunk.csv',
    '[{"ig_username":"chunk.a"},{"ig_username":"chunk.b"}]'::jsonb,
    null, 'MANUAL_ENTRY', b
  );

  select * into r2 from public.import_prospects_batch(
    'chunk.csv',
    '[{"ig_username":"chunk.a"},{"ig_username":"chunk.c"}]'::jsonb,
    null, 'MANUAL_ENTRY', b
  );

  if r1.inserted_count <> 2 then
    raise exception 'FAIL: chunk pertama harus insert 2, dapat %', r1.inserted_count;
  end if;
  if r2.inserted_count <> 1 or r2.duplicate_existing <> 1 then
    raise exception 'FAIL: chunk kedua salah (% baru, % duplikat)', r2.inserted_count, r2.duplicate_existing;
  end if;

  select * into row from public.import_batches where id = b;
  if row.total_rows <> 4 then
    raise exception 'FAIL: total_rows batch harus 4, dapat %', row.total_rows;
  end if;
  if row.inserted_count <> 3 or row.duplicate_existing <> 1 then
    raise exception 'FAIL: akumulasi batch salah (% / %)', row.inserted_count, row.duplicate_existing;
  end if;
  if (select count(*) from public.import_batches where id = b) <> 1 then
    raise exception 'FAIL: chunk membuat baris batch ganda';
  end if;
end $$;

-- ---------- non-engineer tidak bisa rotasi ----------
reset role;
set role authenticated;
set request.jwt.claim.role = 'authenticated';
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare pid uuid;
begin
  pid := current_setting('test.partner_id')::uuid;

  begin
    perform public.rotate_partner_code(pid);
    raise exception 'FAIL: customer bisa merotasi kode partner';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
