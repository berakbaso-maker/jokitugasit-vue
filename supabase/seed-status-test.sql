-- jokitugasit.my.id — Dummy requests untuk pengujian seluruh status
-- Jalankan di Supabase SQL Editor setelah schema.sql
-- Aman dijalankan ulang: konflik order_no diabaikan.
insert into public.requests
  (order_no, customer_name, whatsapp, category, deadline, deadline_date, description, link, status, quote_amount)
values
  ('TEST-NEW', 'Dummy New', '81200000001', 'web', 'besok', null, 'Dummy request untuk menguji status New.', null, 'new', null),
  ('TEST-CONSULT', 'Dummy Consultation', '81200000002', 'ai', 'fleksibel', current_date + 7, 'Dummy request untuk menguji status Consultation.', null, 'consultation', 150000),
  ('TEST-WORKING', 'Dummy Working', '81200000003', 'mobile', 'hari_ini', null, 'Dummy request untuk menguji status Working.', 'https://github.com/example/mobile-project', 'working', 350000),
  ('TEST-REVIEW', 'Dummy Review', '81200000004', 'data', 'besok', null, 'Dummy request untuk menguji status Review.', null, 'review', 275000),
  ('TEST-DONE', 'Dummy Done', '81200000005', 'web', 'fleksibel', current_date + 14, 'Dummy request untuk menguji status Done.', null, 'done', 450000),
  ('TEST-PAID', 'Dummy Paid', '81200000006', 'lainnya', 'besok', null, 'Dummy request untuk menguji status Paid.', null, 'paid', 500000)
on conflict (order_no) do nothing;
select order_no, customer_name, status, deadline, deadline_date, quote_amount from public.requests where order_no like 'TEST-%' order by created_at;
-- Hapus: delete from public.requests where order_no like 'TEST-%';
