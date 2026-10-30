/**
 * Data testimoni contoh (dummy) untuk pengembangan.
 *
 * Dipakai sebagai cadangan HANYA ketika tabel `testimonials` masih kosong
 * atau gagal dimuat, supaya bintang rating dan tata letak kartu bisa
 * diperiksa tanpa database. Begitu ada testimoni asli di Supabase,
 * data ini otomatis tidak dipakai lagi.
 *
 * Jangan dianggap bukti sosial: nama dan isi di bawah ini fiktif.
 */
export const testimoniContoh = [
  {
    id: 'contoh-1',
    name: 'Rina A.',
    role: 'Mahasiswa Informatika, Semester 5',
    rating: 5,
    message:
      'Aplikasi kasir laundry saya error terus di bagian stok. Dijelaskan pelan-pelan kenapa bisa terjadi, bukan cuma dikasih kode jadi. Sekarang jalan normal.',
    project_type: 'Project Web',
  },
  {
    id: 'contoh-2',
    name: 'Bagas P.',
    role: 'Mahasiswa Sistem Informasi',
    rating: 5,
    message:
      'Skripsi saya mentok di bab implementasi. Dibantu rapikan alur database dan bikin diagramnya jelas, jadi lebih gampang saya pertanggungjawabkan ke dosen.',
    project_type: 'Skripsi',
  },
  {
    id: 'contoh-3',
    name: 'Nadia S.',
    role: 'Mahasiswa Teknik Komputer',
    rating: 4,
    message:
      'Tugas mobile app kelompok kami kacau karena tidak ada yang paham Android. Hasilnya rapi dan ada penjelasan tiap file, walau revisi pertama butuh sedikit waktu tambahan.',
    project_type: 'Mobile App',
  },
  {
    id: 'contoh-4',
    name: 'Fajar R.',
    role: 'Mahasiswa Ilmu Komputer',
    rating: 5,
    message:
      'Error yang saya kirim cuma screenshot tanpa penjelasan. Ternyata bisa dilacak sampai ke memory leak. Yang saya suka: dikasih tahu cara menemukan masalah serupa sendiri.',
    project_type: 'Perbaiki Error',
  },
  {
    id: 'contoh-5',
    name: 'Sinta M.',
    role: 'Mahasiswa Data Science',
    rating: 5,
    message:
      'Dataset tugas akhir saya berantakan dan penuh nilai kosong. Dibantu bersihkan dan dijelaskan kenapa tiap langkah perlu, jadi saya bisa menjawab saat sidang.',
    project_type: 'Data Science',
  },
  {
    id: 'contoh-6',
    name: 'Yoga H.',
    role: 'Mahasiswa Teknik Informatika',
    rating: 4,
    message:
      'Dashboard analitiknya jalan sesuai permintaan dan enak dipakai. Komunikasi lewat WhatsApp responsif, cuma estimasi awal sempat mundur sehari dari perkiraan saya sendiri.',
    project_type: 'Project Web',
  },
  {
    id: 'contoh-7',
    name: 'Dewi K.',
    role: 'Mahasiswa Manajemen Informatika',
    rating: 5,
    message:
      'Awalnya ragu karena tugas kuliah biasanya cuma dikasih jadi. Di sini malah diajak ngobrol dulu soal batasannya, jadi hasilnya benar-benar sesuai tugas saya.',
    project_type: 'Tugas Kuliah',
  },
  {
    id: 'contoh-8',
    name: 'Arif N.',
    role: 'Mahasiswa Sistem Informasi',
    rating: 5,
    message:
      'API yang saya butuhkan harus nyambung ke sistem kampus yang dokumentasinya minim. Bisa diakali dan dikasih catatan cara pakainya. Sangat membantu.',
    project_type: 'Database dan API',
  },
  {
    id: 'contoh-9',
    name: 'Putri L.',
    role: 'Mahasiswa Desain Komunikasi Visual',
    rating: 4,
    message:
      'Tampilan aplikasi saya jadi jauh lebih enak dilihat dan dipakai. Ada beberapa pilihan warna yang saya minta ubah, dan semuanya dituruti tanpa ribet.',
    project_type: 'Desain UI UX',
  },
]
