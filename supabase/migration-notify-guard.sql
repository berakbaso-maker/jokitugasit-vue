-- =============================================================
-- Notifikasi & email: klaim sekali pakai + data dari DB
-- =============================================================
-- Masalah yang ditutup:
--   1. /api/notify-order bisa dipanggil siapa pun dengan isi pesan bebas →
--      spam + phishing ke chat Telegram engineer.
--   2. /api/send-email menerima alamat tujuan + HTML bebas → domain email
--      dipakai orang lain untuk spam/phishing.
--
-- Pengganti: endpoint hanya menerima order_no. Order harus ada, berumur
-- < 30 menit, dan belum pernah diklaim. Klaim memakai UPDATE ... WHERE
-- sehingga dua pemanggilan paralel tidak bisa mengirim dua kali.
-- Fungsi hanya boleh dipanggil service_role (server), bukan anon.

alter table public.requests
  add column if not exists notified_at timestamptz,
  add column if not exists email_sent_at timestamptz,
  add column if not exists email_provider_id text;

-- ---------------------------------------------------------------
-- Klaim notifikasi Telegram
-- ---------------------------------------------------------------
create or replace function public.claim_order_notification(p_order_no text)
returns table (
  order_no      text,
  customer_name text,
  whatsapp      text,
  category      text,
  deadline      text,
  deadline_date date,
  description   text,
  link          text,
  file_url      text
)
language sql
security definer
set search_path = public
as $$
  update public.requests r
     set notified_at = now()
   where upper(r.order_no) = upper(trim(p_order_no))
     and r.notified_at is null
     and r.created_at > now() - interval '30 minutes'
  returning r.order_no, r.customer_name, r.whatsapp, r.category,
            r.deadline, r.deadline_date, r.description, r.link, r.file_url;
$$;

revoke all on function public.claim_order_notification(text) from public, anon, authenticated;
grant execute on function public.claim_order_notification(text) to service_role;

-- ---------------------------------------------------------------
-- Klaim email booking (butuh kolom email terisi)
-- ---------------------------------------------------------------
create or replace function public.claim_order_email(p_order_no text)
returns table (
  order_no      text,
  customer_name text,
  email         text,
  category      text,
  deadline      text,
  deadline_date date,
  description   text,
  quote_amount  numeric
)
language sql
security definer
set search_path = public
as $$
  update public.requests r
     set email_sent_at = now()
   where upper(r.order_no) = upper(trim(p_order_no))
     and r.email is not null
     and r.email_sent_at is null
     and r.created_at > now() - interval '30 minutes'
  returning r.order_no, r.customer_name, r.email, r.category,
            r.deadline, r.deadline_date, r.description, r.quote_amount;
$$;

revoke all on function public.claim_order_email(text) from public, anon, authenticated;
grant execute on function public.claim_order_email(text) to service_role;

-- ---------------------------------------------------------------
-- Lepas klaim kalau pengiriman gagal, supaya bisa dicoba ulang
-- ---------------------------------------------------------------
create or replace function public.release_order_claim(p_order_no text, p_kind text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_kind = 'email' then
    update public.requests set email_sent_at = null
     where upper(order_no) = upper(trim(p_order_no));
  else
    update public.requests set notified_at = null
     where upper(order_no) = upper(trim(p_order_no));
  end if;
end;
$$;

revoke all on function public.release_order_claim(text, text) from public, anon, authenticated;
grant execute on function public.release_order_claim(text, text) to service_role;

create index if not exists requests_notified_at_idx on public.requests (notified_at);
create index if not exists requests_email_sent_at_idx on public.requests (email_sent_at);
