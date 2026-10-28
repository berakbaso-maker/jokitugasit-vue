-- =============================================================
-- jokitugasit.my.id — Seed Data (contoh)
-- Jalankan SETELAH schema.sql (dalam kueri yang sama).
-- =============================================================

-- Pastikan request contoh dibuat dulu lalu insert transaction yang merujuk ke beberapa id.
-- Karena request punya id acak, gunakan subquery agar robust.

delete from public.transactions;

-- Dummy request contoh (bisa langsung dibaca di dashboard engineer)
insert into public.requests (order_no, customer_name, whatsapp, category, deadline, description, status, quote_amount, budget_estimate)
values
  ('JT1024', 'Raka', '81234567890', 'mobile', 'hari_ini', 'API data tidak tampil di Flutter, tolong diperbaiki.', 'review', null, null),
  ('JT1025', 'Bima', '81234567891', 'web', 'besok', 'Error 500 saat checkout di Laravel.', 'working', 350000, 300000),
  ('JT1026', 'Siti', '81234567892', 'web', 'fleksibel', 'Perlu setup routing awal untuk project React.', 'new', null, null),
  ('JT1027', 'Andi', '81234567893', 'ai', 'hari_ini', 'Auth flow dari hasil ChatGPT tidak jalan, mau demo besok pagi.', 'consultation', 150000, 150000);

-- Transaction contoh (refer ke request JT1024 & JT1025)
insert into public.transactions (transaction_no, request_id, customer_name, project_label, amount, status, created_at)
select
  'TRX-' || lpad(row_number() over ()::text, 3, '0'),
  req.id,
  req.customer_name,
  req.category || ' Project',
  amounts.amount,
  amounts.status,
  now() - (amounts.days_ago * interval '1 day')
from public.requests req
join (
  values
    ('JT1024', 500000::numeric, 'paid', 2),
    ('JT1025', 350000::numeric, 'pending', 1),
    ('JT1027', 150000::numeric, 'paid', 4)
) as amounts(order_no, amount, status, days_ago) on req.order_no = amounts.order_no;

-- =============================================================
-- Catatan membuat akun engineer demo:
-- Buat user lewat Supabase Auth > Add user (email + password),
-- misal engineer@jokitugasit.my.id / password kuat.
-- Trigger handle_new_user akan otomatis membuat row di profiles
-- dengan role 'engineer'.
-- =============================================================