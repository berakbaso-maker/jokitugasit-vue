-- =============================================================
-- Tabel testimonials + kebijakan RLS
-- Jalankan di: Supabase Dashboard > SQL Editor > New query
-- Aman dijalankan berulang (idempotent).
-- =============================================================

create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text,
  rating smallint not null default 5 check (rating between 1 and 5),
  message text not null,
  project_type text,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists testimonials_published_idx
  on public.testimonials (is_published, created_at desc);

alter table public.testimonials enable row level security;

-- Publik hanya boleh membaca testimoni yang sudah direview.
drop policy if exists "testimonials_public_read" on public.testimonials;
create policy "testimonials_public_read"
  on public.testimonials for select
  to anon, authenticated
  using (is_published = true);

-- Pengunjung boleh mengirim testimoni baru, tapi tidak boleh
-- menerbitkannya sendiri (is_published wajib false).
drop policy if exists "testimonials_anon_insert" on public.testimonials;
create policy "testimonials_anon_insert"
  on public.testimonials for insert
  to anon, authenticated
  with check (is_published = false);

-- Engineer (via service role / dashboard) mengelola sisanya.
