-- =============================================================
-- jokitugasit.my.id — Referral Partner Migration
-- Jalankan di: Supabase Dashboard > SQL Editor > New query
-- =============================================================

-- Tabel partner referral
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

-- RLS: hanya engineer yang bisa baca/tulis partners
alter table public.partners enable row level security;

create policy "partners_engineer_all"
  on public.partners for all
  to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'engineer'));

-- Tambah kolom di tabel requests
alter table public.requests
  add column if not exists referral_code text,
  add column if not exists email text,
  add column if not exists commission_paid boolean default false;

-- Index untuk lookup kode referral
create index if not exists idx_requests_referral_code on public.requests (referral_code);
create index if not exists idx_partners_referral_code on public.partners (referral_code);

-- Anon bisa select partners untuk validasi kode referral di form
create policy "partners_anon_validate_code"
  on public.partners for select
  to anon
  using (status = 'active');
