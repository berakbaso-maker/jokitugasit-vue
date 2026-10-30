-- =============================================================
-- SEED DUMMY: testimoni contoh untuk halaman /testimoni
-- Jalankan SETELAH supabase/migration-testimonials.sql
--
-- Catatan: ini data contoh (dummy) supaya bintang rating dan kartu
-- testimoni ada isinya saat pengembangan. Ganti dengan testimoni asli
-- sebelum dipakai sebagai bukti sosial di produksi.
--
-- Hanya mengisi kalau tabel masih kosong, jadi aman dijalankan ulang.
-- =============================================================

insert into public.testimonials (name, role, rating, message, project_type, is_published)
select * from (values
  ('Rina A.', 'Mahasiswa Informatika, Semester 5', 5,
   'Aplikasi kasir laundry saya error terus di bagian stok. Dijelaskan pelan-pelan kenapa bisa terjadi, bukan cuma dikasih kode jadi. Sekarang jalan normal.',
   'Project Web', true),
  ('Bagas P.', 'Mahasiswa Sistem Informasi', 5,
   'Skripsi saya mentok di bab implementasi. Dibantu rapikan alur database dan bikin diagramnya jelas, jadi lebih gampang saya pertanggungjawabkan ke dosen.',
   'Skripsi', true),
  ('Nadia S.', 'Mahasiswa Teknik Komputer', 4,
   'Tugas mobile app kelompok kami kacau karena tidak ada yang paham Android. Hasilnya rapi dan ada penjelasan tiap file, walau revisi pertama butuh sedikit waktu tambahan.',
   'Mobile App', true),
  ('Fajar R.', 'Mahasiswa Ilmu Komputer', 5,
   'Error yang saya kirim cuma screenshot tanpa penjelasan. Ternyata bisa dilacak sampai ke memory leak. Yang saya suka: dikasih tahu cara menemukan masalah serupa sendiri.',
   'Perbaiki Error', true),
  ('Sinta M.', 'Mahasiswa Data Science', 5,
   'Dataset tugas akhir saya berantakan dan penuh nilai kosong. Dibantu bersihkan dan dijelaskan kenapa tiap langkah perlu, jadi saya bisa menjawab saat sidang.',
   'Data Science', true),
  ('Yoga H.', 'Mahasiswa Teknik Informatika', 4,
   'Dashboard analitiknya jalan sesuai permintaan dan enak dipakai. Komunikasi lewat WhatsApp responsif, cuma estimasi awal sempat mundur sehari dari perkiraan saya sendiri.',
   'Project Web', true),
  ('Dewi K.', 'Mahasiswa Manajemen Informatika', 5,
   'Awalnya ragu karena tugas kuliah biasanya cuma dikasih jadi. Di sini malah diajak ngobrol dulu soal batasannya, jadi hasilnya benar-benar sesuai tugas saya.',
   'Tugas Kuliah', true),
  ('Arif N.', 'Mahasiswa Sistem Informasi', 5,
   'API yang saya butuhkan harus nyambung ke sistem kampus yang dokumentasinya minim. Bisa diakali dan dikasih catatan cara pakainya. Sangat membantu.',
   'Database dan API', true),
  ('Putri L.', 'Mahasiswa Desain Komunikasi Visual', 4,
   'Tampilan aplikasi saya jadi jauh lebih enak dilihat dan dipakai. Ada beberapa pilihan warna yang saya minta ubah, dan semuanya dituruti tanpa ribet.',
   'Desain UI UX', true)
) as v(name, role, rating, message, project_type, is_published)
where not exists (select 1 from public.testimonials);
