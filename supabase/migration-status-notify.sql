-- ==========================================================================
-- Notifikasi perubahan status ke klien (email)
--
-- Masalah: engineer mengubah status di dashboard, tapi klien tidak diberi tahu
-- sama sekali. Klien harus membuka /track sendiri, sehingga pertanyaan
-- "progresnya gimana?" tetap masuk lewat WhatsApp.
--
-- Desain:
--   - requests.status_notified menyimpan status terakhir yang SUDAH dikabarkan.
--     Klaim = UPDATE bersyarat, jadi atomik dan anti-dobel (dua klik beruntun
--     tidak mengirim dua email).
--   - Kalau status kembali ke nilai sebelumnya (mis. working -> review ->
--     working), klien tetap dikabari karena yang dibandingkan adalah nilai
--     terakhir, bukan riwayat unik.
--   - Tabel log hanya untuk audit (provider_id Resend), tanpa policy RLS:
--     hanya service_role yang menyentuh.
-- ==========================================================================

alter table public.requests
  add column if not exists status_notified text;

create table if not exists public.request_status_notifications (
  id bigserial primary key,
  order_no text not null,
  status text not null,
  provider_id text,
  created_at timestamptz not null default now()
);

create index if not exists idx_status_notif_order on public.request_status_notifications (order_no);

alter table public.request_status_notifications enable row level security;
revoke all on public.request_status_notifications from public, anon, authenticated;

-- Klaim: tandai status ini sedang dikabarkan, kembalikan data yang dibutuhkan
-- untuk menyusun email. Tidak mengembalikan baris kalau:
--   order tidak ada / status tidak cocok / klien tanpa email / sudah dikabarkan.
create or replace function public.claim_status_notification(p_order_no text, p_status text)
returns table (
  order_no text,
  customer_name text,
  email text,
  status text,
  category text,
  deadline text,
  deadline_date date,
  quote_amount numeric
)
language sql
security definer
set search_path = public
as $$
  update public.requests r
     set status_notified = r.status
   where r.order_no = upper(trim(p_order_no))
     and r.status = p_status
     and r.email is not null
     and length(trim(r.email)) > 0
     and coalesce(r.status_notified, '') <> r.status
  returning r.order_no, r.customer_name, r.email, r.status, r.category,
            r.deadline, r.deadline_date, r.quote_amount;
$$;

-- Lepas klaim kalau pengiriman gagal, supaya bisa dicoba lagi.
create or replace function public.release_status_notification(p_order_no text, p_status text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.requests
     set status_notified = null
   where order_no = upper(trim(p_order_no))
     and status = p_status
     and status_notified = p_status;
$$;

revoke all on function public.claim_status_notification(text, text) from public, anon, authenticated;
revoke all on function public.release_status_notification(text, text) from public, anon, authenticated;
grant execute on function public.claim_status_notification(text, text) to service_role;
grant execute on function public.release_status_notification(text, text) to service_role;
