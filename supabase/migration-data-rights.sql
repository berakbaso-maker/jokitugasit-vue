-- =============================================================
-- jokitugasit.my.id — Data rights (hapus prospek + suppression)
-- Jalankan SETELAH migration-referral-integrity.sql.
--
-- Kenapa ada tabel suppression terpisah:
--   Menghapus baris prospek saja akan menghilangkan status
--   do-not-contact. Import berikutnya bisa memunculkan lagi orang yang
--   sudah minta dihapus. Jadi username disimpan minimal (tanpa nama,
--   kampus, atau nomor) di `prospect_suppressions`.
--
-- Additive & idempoten.
-- =============================================================

-- ---------------------------------------------------------------
-- 1. Daftar suppression (data minimal: username saja)
-- ---------------------------------------------------------------
create table if not exists public.prospect_suppressions (
  ig_username citext primary key
              check (ig_username ~ '^[a-z0-9._]{1,30}$'),
  reason      text,
  created_at  timestamptz not null default now(),
  created_by  uuid
);

alter table public.prospect_suppressions enable row level security;

drop policy if exists prospect_suppressions_engineer_all on public.prospect_suppressions;
create policy prospect_suppressions_engineer_all on public.prospect_suppressions
  for all to authenticated using (public.is_engineer()) with check (public.is_engineer());

-- ---------------------------------------------------------------
-- 2. Hapus prospek, opsional masukkan ke suppression
-- ---------------------------------------------------------------
create or replace function public.delete_prospect(
  p_prospect_id uuid,
  p_reason      text,
  p_suppress    boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if coalesce(btrim(p_reason), '') = '' then
    raise exception 'ALASAN_WAJIB' using errcode = '22023';
  end if;

  select * into v_row from public.prospects where id = p_prospect_id for update;
  if not found then
    raise exception 'PROSPEK_TIDAK_DITEMUKAN' using errcode = 'P0002';
  end if;

  -- Prospek DNC selalu disimpan di suppression: menghapusnya tidak boleh
  -- membuat orang yang menolak bisa diimpor ulang.
  if p_suppress or v_row.do_not_contact then
    insert into public.prospect_suppressions (ig_username, reason, created_by)
    values (v_row.ig_username, btrim(p_reason), auth.uid())
    on conflict (ig_username) do nothing;
  end if;

  -- outreach_logs ikut terhapus (on delete cascade);
  -- requests.prospect_id menjadi null (on delete set null).
  delete from public.prospects where id = p_prospect_id;
end;
$$;

revoke all on function public.delete_prospect(uuid, text, boolean) from public;
grant execute on function public.delete_prospect(uuid, text, boolean) to authenticated;

-- ---------------------------------------------------------------
-- 3. import_prospects: lewati username yang ada di suppression
--    (fungsi lama diganti; perilaku lain tidak berubah)
-- ---------------------------------------------------------------
create or replace function public.import_prospects(
  p_rows         jsonb,
  p_source_account uuid default null,
  p_permission_basis text default 'MANUAL_ENTRY',
  p_batch_id     uuid default null
)
returns table (
  inserted_count        int,
  duplicate_in_file     int,
  duplicate_existing    int,
  invalid_count         int,
  suppressed_count      int,
  invalid_samples       text[]
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row        jsonb;
  v_username   text;
  v_seen       text[] := '{}';
  v_invalid    text[] := '{}';
  v_ins        int := 0;
  v_dup_file   int := 0;
  v_dup_exist  int := 0;
  v_suppressed int := 0;
  v_existing   public.prospects%rowtype;
begin
  if not public.is_engineer() then
    raise exception 'AKSES_DITOLAK' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'FORMAT_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_permission_basis not in ('MANUAL_ENTRY','ADMIN_SHARED_LIST','INBOUND_OPT_IN') then
    raise exception 'BASIS_IZIN_TIDAK_VALID' using errcode = '22023';
  end if;

  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_username := public.normalize_ig_username(v_row ->> 'ig_username');

    if v_username !~ '^[a-z0-9._]{1,30}$' then
      v_invalid := v_invalid || coalesce(v_row ->> 'ig_username', '');
      continue;
    end if;

    if v_username = any (v_seen) then
      v_dup_file := v_dup_file + 1;
      continue;
    end if;
    v_seen := v_seen || v_username;

    -- Pernah dihapus atas permintaan pemilik data: jangan dibuat lagi.
    if exists (select 1 from public.prospect_suppressions where ig_username = v_username) then
      v_suppressed := v_suppressed + 1;
      continue;
    end if;

    select * into v_existing from public.prospects where ig_username = v_username;

    if found then
      v_dup_exist := v_dup_exist + 1;

      if v_existing.do_not_contact then
        v_suppressed := v_suppressed + 1;
        -- sengaja tidak mengubah apa pun: DNC harus tetap berlaku
        continue;
      end if;

      update public.prospects set
        display_name      = coalesce(display_name, nullif(btrim(coalesce(v_row ->> 'display_name', '')), '')),
        campus            = coalesce(campus, nullif(btrim(coalesce(v_row ->> 'campus', '')), '')),
        cohort_year       = coalesce(cohort_year, nullif(v_row ->> 'cohort_year', '')::int),
        source_account_id = coalesce(source_account_id, p_source_account)
      where id = v_existing.id;
      continue;
    end if;

    insert into public.prospects (
      ig_username, display_name, campus, cohort_year, permission_basis,
      source_account_id, import_batch_id, collected_at
    ) values (
      v_username,
      nullif(btrim(coalesce(v_row ->> 'display_name', '')), ''),
      nullif(btrim(coalesce(v_row ->> 'campus', '')), ''),
      nullif(v_row ->> 'cohort_year', '')::int,
      p_permission_basis,
      p_source_account,
      p_batch_id,
      now()
    );
    v_ins := v_ins + 1;
  end loop;

  return query select v_ins, v_dup_file, v_dup_exist, coalesce(array_length(v_invalid, 1), 0),
                      v_suppressed, v_invalid;
end;
$$;

revoke all on function public.import_prospects(jsonb, uuid, text, uuid) from public;
grant execute on function public.import_prospects(jsonb, uuid, text, uuid) to authenticated;
