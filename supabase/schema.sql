-- =============================================================
-- JokiTugasIT.id — Supabase Schema (PostgreSQL)
-- Jalankan di: Supabase Dashboard > SQL Editor > New query
-- Urutan: taruh isi file ini, lalu seed.sql di kueri yang sama
-- (blok di bawah tabel bisa dijalankan berurutan dalam satu script).
-- =============================================================

create extension if not exists "pgcrypto";

-- ---------- TABLES ----------

-- profiles: dipakai untuk engineer (role), terhubung ke auth.users
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'customer' check (role in ('customer','engineer')),
  whatsapp text,
  created_at timestamptz not null default now()
);

-- requests: permintaan project dari client (tanpa login)
-- deadline_date dipakai saat deadline = 'fleksibel'

create table if not exists public.requests (
  id uuid primary key default gen_random_uuid(),
  order_no text unique not null,
  customer_name text not null,
  whatsapp text,
  category text default 'web',
  deadline text not null default 'besok' check (deadline in ('hari_ini','besok','fleksibel')),
  deadline_date date,
  description text not null,
  link text,
  file_url text,
  budget_estimate numeric,
  status text not null default 'new' check (status in ('new','consultation','working','review','done','paid')),
  quote_amount numeric,
  internal_notes text,
  created_at timestamptz not null default now()
);

-- transactions: earning engineer
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  transaction_no text unique not null,
  request_id uuid references public.requests (id) on delete set null,
  engineer_id uuid references public.profiles (id) on delete set null,
  customer_name text,
  project_label text,
  amount numeric not null default 0,
  status text not null default 'pending' check (status in ('pending','paid')),
  created_at timestamptz not null default now()
);

-- ---------- TRIGGER: auto create profile on user signup ----------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    case when new.raw_user_meta_data->>'role' = 'engineer' then 'engineer' else 'customer' end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- ROW LEVEL SECURITY ----------

alter table public.profiles enable row level security;
alter table public.requests enable row level security;
alter table public.transactions enable row level security;

-- REQUESTS: anon boleh INSERT (client kirim request) & SELECT by order_no
--           engineer login boleh SELECT semua & UPDATE
create policy "requests_anon_insert"
  on public.requests for insert
  to anon
  with check (true);

create policy "requests_anon_select_status"
  on public.requests for select
  to anon
  using (true);

create policy "requests_engineer_update"
  on public.requests for update
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'engineer'));

create policy "requests_engineer_select"
  on public.requests for select
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'engineer'));

-- PROFILES: engineer hanya bisa lihat dirinya (untuk login/dl), anon tidak akses
create policy "profiles_self_select"
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

-- TRANSACTIONS: hanya engineer
create policy "transactions_engineer_select"
  on public.transactions for select
  to authenticated
  using (true);

-- ADMIN punya akses penuh via service role (default), cukup untuk tahap awal.
-- Untuk produksi, pertegas policy per-engineer sesuai kebutuhan.

-- ---------- STORAGE ----------
-- Buat bucket "attachments" secara manual:
--   Supabase Dashboard > Storage > New bucket
--   Name: attachments, Public: true (agar file jad paten bisa dibuka anon)
-- Policy (Storage → New policy → SQL editor):
--   create policy "attachments_anon_upload"
--     on storage.objects for insert
--     to anon
--     with check (bucket_id = 'attachments');
--   create policy "attachments_public_read"
--     on storage.objects for select
--     to anon
--     using (bucket_id = 'attachments');
-- =============================================================