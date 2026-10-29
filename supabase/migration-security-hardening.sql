-- =============================================================
-- jokitugasit.my.id — Security hardening
-- Urutan: jalankan SETELAH schema.sql, migration-referral-partner.sql,
-- dan migration-delivery-walkthrough.sql.
--
-- Menutup empat masalah pada policy lama:
--   1. requests_anon_select_status (using true)  -> anon bisa dump semua
--      nama, whatsapp, deskripsi, internal_notes, quote_amount.
--   2. requests_anon_insert (with check true)    -> anon bisa menulis
--      quote_amount/internal_notes/status bebas.
--   3. partners_anon_validate_code (using status='active') -> anon bisa
--      membaca full_name, whatsapp, ewallet_info milik semua partner.
--   4. transactions_engineer_select (using true untuk role authenticated)
--      -> siapa pun yang punya akun bisa membaca semua transaksi.
--
-- Pengganti: RPC dengan kolom terbatas (security definer).
-- =============================================================

-- ---------------------------------------------------------------
-- 0. Helper dipakai oleh policy di bawah
-- ---------------------------------------------------------------
create or replace function public.is_engineer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'engineer'
  );
$$;

revoke all on function public.is_engineer() from public;
grant execute on function public.is_engineer() to authenticated;

-- ---------------------------------------------------------------
-- 0b. Kolom yang dipakai RPC di bawah (defensif)
-- ---------------------------------------------------------------
alter table public.requests
  add column if not exists referral_code text,
  add column if not exists email text;

-- ---------------------------------------------------------------
-- 1. requests: buang policy seleksi + insert publik yang terlalu luas
-- ---------------------------------------------------------------
drop policy if exists "requests_anon_select_status" on public.requests;
drop policy if exists "requests_anon_insert" on public.requests;

-- Engineer tetap memakai policy "requests_engineer_select".
-- Customer tidak lagi menyentuh tabel; gunakan RPC di bawah.

-- ---------------------------------------------------------------
-- 2. RPC publik: kirim request tanpa bisa memalsukan kolom internal
-- ---------------------------------------------------------------
create or replace function public.create_public_request(
  p_customer_name text,
  p_whatsapp      text,
  p_description   text,
  p_category      text default 'web',
  p_deadline      text default 'besok',
  p_deadline_date date default null,
  p_link          text default null,
  p_file_url      text default null,
  p_email         text default null,
  p_referral_code text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_no text;
  v_ref      text;
  v_attempt  int := 0;
begin
  if coalesce(trim(p_customer_name), '') = '' then
    raise exception 'NAMA_WAJIB' using errcode = '22023';
  end if;
  if coalesce(trim(p_whatsapp), '') = '' then
    raise exception 'WHATSAPP_WAJIB' using errcode = '22023';
  end if;
  if coalesce(trim(p_description), '') = '' then
    raise exception 'DESKRIPSI_WAJIB' using errcode = '22023';
  end if;
  if p_category not in ('web','mobile','desktop','database','ai','debug',
                        'skripsi','tugas_kuliah','design','lainnya') then
    raise exception 'KATEGORI_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_deadline not in ('hari_ini','besok','fleksibel') then
    raise exception 'DEADLINE_TIDAK_VALID' using errcode = '22023';
  end if;
  if p_deadline = 'fleksibel' and p_deadline_date is null then
    raise exception 'TANGGAL_WAJIB' using errcode = '22023';
  end if;

  -- Hanya terima kode referral yang benar-benar aktif.
  select upper(trim(p_referral_code)) into v_ref
  from public.partners
  where referral_code = upper(trim(coalesce(p_referral_code, '')))
    and status = 'active';
  if not found then v_ref := null; end if;

  -- Order number dibuat server-side: 6 digit, bukan 4, supaya tidak
  -- bisa dienumerasi berurutan.
  loop
    v_attempt := v_attempt + 1;
    v_order_no := 'JT' || lpad((floor(random() * 900000) + 100000)::int::text, 6, '0');
    begin
      insert into public.requests (
        order_no, customer_name, whatsapp, email, category, description,
        deadline, deadline_date, link, file_url, referral_code,
        status, quote_amount, internal_notes
      ) values (
        v_order_no,
        trim(p_customer_name),
        trim(p_whatsapp),
        nullif(trim(coalesce(p_email, '')), ''),
        p_category,
        trim(p_description),
        p_deadline,
        case when p_deadline = 'fleksibel' then p_deadline_date end,
        nullif(trim(coalesce(p_link, '')), ''),
        nullif(trim(coalesce(p_file_url, '')), ''),
        v_ref,
        'new',
        null,
        null
      );
      return v_order_no;
    exception when unique_violation then
      if v_attempt >= 8 then
        raise exception 'GAGAL_MEMBUAT_ORDER' using errcode = '23505';
      end if;
    end;
  end loop;
end;
$$;

revoke all on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text
) from public;
grant execute on function public.create_public_request(
  text, text, text, text, text, date, text, text, text, text
) to anon, authenticated;

-- ---------------------------------------------------------------
-- 3. RPC publik: lacak order tanpa membocorkan kolom internal
-- ---------------------------------------------------------------
create or replace function public.track_request(p_order_no text)
returns table (
  order_no      text,
  customer_name text,
  category      text,
  deadline      text,
  deadline_date date,
  description   text,
  status        text,
  quote_amount  numeric,
  created_at    timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select r.order_no, r.customer_name, r.category, r.deadline, r.deadline_date,
         r.description, r.status, r.quote_amount, r.created_at
  from public.requests r
  where upper(r.order_no) = upper(trim(p_order_no))
  limit 1;
$$;

revoke all on function public.track_request(text) from public;
grant execute on function public.track_request(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 4. partners: hentikan kebocoran data partner, ganti dengan RPC
-- ---------------------------------------------------------------
-- Pastikan tabel partners ada (isi sama dengan migration-referral-partner.sql)
-- supaya urutan migration tidak bisa membuat deploy gagal separuh jalan.
create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  whatsapp text not null,
  campus text,
  referral_code text unique not null,
  ewallet_info text,
  total_referrals int default 0,
  total_commission numeric default 0,
  status text default 'active' check (status in ('active','inactive')),
  notes text,
  created_at timestamptz default now()
);

alter table public.partners enable row level security;

drop policy if exists "partners_engineer_all" on public.partners;
create policy "partners_engineer_all"
  on public.partners for all
  to authenticated
  using (public.is_engineer())
  with check (public.is_engineer());

drop policy if exists "partners_anon_validate_code" on public.partners;

create index if not exists idx_partners_referral_code on public.partners (referral_code);

create or replace function public.validate_referral_code(p_code text)
returns table (
  valid        boolean,
  display_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select true,
         coalesce(nullif(split_part(p.full_name, ' ', 1), ''), 'Partner')
  from public.partners p
  where p.referral_code = upper(trim(p_code))
    and p.status = 'active'
  limit 1;
$$;

revoke all on function public.validate_referral_code(text) from public;
grant execute on function public.validate_referral_code(text) to anon, authenticated;

-- ---------------------------------------------------------------
-- 5. transactions: hanya engineer
-- ---------------------------------------------------------------
drop policy if exists "transactions_engineer_select" on public.transactions;

create policy "transactions_engineer_select"
  on public.transactions for select
  to authenticated
  using (public.is_engineer());

-- ---------------------------------------------------------------
-- 6. Jaring pengaman: apa pun yang lolos ke anon tidak boleh
--    menyentuh kolom finansial/internal.
-- ---------------------------------------------------------------
create or replace function public.requests_guard_anon()
returns trigger
language plpgsql
as $$
begin
  -- PostgREST menjalankan request anonim sebagai role database "anon".
  -- Memakai current_user (bukan JWT claim) supaya sesi administratif
  -- seperti SQL Editor / migration tidak ikut terblokir.
  if current_user = 'anon' then
    new.quote_amount   := null;
    new.internal_notes := null;
    new.status         := 'new';
    if tg_op = 'UPDATE' then
      raise exception 'AKSES_DITOLAK' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists requests_guard_anon_trg on public.requests;
create trigger requests_guard_anon_trg
  before insert or update on public.requests
  for each row execute function public.requests_guard_anon();
