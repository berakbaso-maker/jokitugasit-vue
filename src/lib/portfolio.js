/**
 * Data portofolio engineer.
 *
 * PENTING soal kejujuran:
 * Seluruh entri di bawah ini adalah STUDI KASUS CONTOH (demo) untuk
 * memperlihatkan bentuk dan kedalaman halaman portofolio. Bukan klaim
 * proyek klien nyata. Halaman /portofolio menampilkan catatan ini di footer.
 *
 * Cara mengganti dengan proyek asli:
 *   1. Ganti isi array `proyek` di bawah (atau tambah entri baru).
 *   2. Set `contoh: false` pada entri yang benar-benar sudah dikerjakan.
 *   3. `slug` harus unik dan URL-safe (huruf kecil, tanda hubung).
 *   4. `mockup.gradient` pakai dua warna hex; dipakai untuk ilustrasi kartu.
 *
 * Kategori (`category`) HARUS salah satu dari KATEGORI_VALID di
 * src/lib/pricing.js supaya konsisten dengan layanan yang dijual.
 */

import { KATEGORI_VALID } from './pricing'

/** Label tampilan untuk tiap kategori. */
export const LABEL_KATEGORI = {
  web: 'Website',
  mobile: 'Mobile App',
  desktop: 'Desktop App',
  database: 'Database & API',
  ai: 'Data Science & AI',
  skripsi: 'Skripsi',
  debug: 'Debug & Fix',
  design: 'UI/UX',
  tugas_kuliah: 'Tugas Kuliah',
  lainnya: 'Lainnya',
}

/** Ikon material untuk tiap kategori. */
const IKON_KATEGORI = {
  web: 'language',
  mobile: 'smartphone',
  desktop: 'desktop_windows',
  database: 'database',
  ai: 'psychology',
  skripsi: 'school',
  debug: 'bug_report',
  design: 'palette',
  tugas_kuliah: 'menu_book',
  lainnya: 'widgets',
}

/**
 * Palet gradien per kategori. Dipakai untuk ilustrasi mockup supaya
 * tiap kategori punya "warna" yang mudah dikenali saat memindai grid.
 */
const GRADIEN_KATEGORI = {
  web: ['#2563EB', '#1E3A8A'],
  mobile: ['#0EA5E9', '#0C4A6E'],
  desktop: ['#475569', '#1E293B'],
  database: ['#0D9488', '#134E4A'],
  ai: ['#7C3AED', '#4C1D95'],
  skripsi: ['#D97706', '#78350F'],
  debug: ['#DC2626', '#7F1D1D'],
  design: ['#DB2777', '#831843'],
  tugas_kuliah: ['#059669', '#064E3B'],
  lainnya: ['#52627A', '#1E293B'],
}

/**
 * 16 studi kasus contoh. Sebaran kategori sengaja mengikuti layanan
 * yang dijual: web 3, mobile 2, desktop 1, database 2, ai 2, skripsi 2,
 * debug 2, design 1, tugas_kuliah 1.
 */
export const proyek = [
  {
    slug: 'sistem-kasir-laundry',
    title: 'Sistem Kasir & Stok Laundry',
    tagline: 'POS multi-outlet dengan sinkronisasi stok real-time',
    category: 'web',
    stack: ['Vue 3', 'Supabase', 'Tailwind', 'Midtrans'],
    year: 2024,
    duration: '6 minggu',
    role: 'Full-stack',
    featured: true,
    problem:
      'Pemilik tiga outlet laundry mencatat transaksi di buku tulis. Stok deterjen dan setrika sering habis tanpa diketahui, dan laporan harian baru direkap seminggu sekali sehingga selisih kas tidak terlacak.',
    solution:
      'Membangun aplikasi kasir berbasis web yang bisa dipakai dari tablet di tiap outlet. Setiap transaksi langsung memotong stok bahan baku, dan pemilik melihat rekap gabungan semua outlet dari satu dashboard.',
    features: [
      'Kasir cepat dengan pencarian produk dan shortcut keyboard',
      'Stok bahan baku terpotong otomatis per transaksi',
      'Pembayaran tunai, transfer, dan QRIS lewat Midtrans',
      'Rekap omzet harian per outlet dan gabungan',
      'Cetak struk thermal 58mm lewat browser',
      'Role terpisah: kasir hanya lihat outletnya sendiri',
    ],
    result: {
      metrics: [
        { label: 'Waktu rekap harian', value: '3 jam → 2 menit' },
        { label: 'Selisih kas', value: 'turun 92%' },
        { label: 'Transaksi/bulan', value: '4.100+' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.web, icon: IKON_KATEGORI.web },
    contoh: true,
  },
  {
    slug: 'dashboard-analitik-sekolah',
    title: 'Dashboard Analitik Sekolah',
    tagline: 'Memantau kehadiran dan nilai 1.200 siswa dalam satu layar',
    category: 'web',
    stack: ['Vue 3', 'Chart.js', 'PostgreSQL', 'Node.js'],
    year: 2024,
    duration: '8 minggu',
    role: 'Full-stack',
    featured: true,
    problem:
      'Wali kelas mengumpulkan absensi dan nilai dari empat file Excel berbeda. Kepala sekolah butuh angka kehadiran per kelas, tapi harus menunggu staf merekap manual selama dua hari.',
    solution:
      'Satu dashboard yang menarik data dari database sekolah, menghitung agregat per kelas dan per semester, lalu menampilkannya sebagai grafik tren dan tabel yang bisa diekspor.',
    features: [
      'Grafik tren kehadiran per kelas dan per bulan',
      'Peringkat nilai dengan filter semester',
      'Deteksi siswa dengan absensi di bawah ambang',
      'Ekspor rekap ke Excel dan PDF',
      'Hak akses berjenjang: guru, wali kelas, kepala sekolah',
      'Cache query agregat agar tetap ringan saat jam sibuk',
    ],
    result: {
      metrics: [
        { label: 'Waktu rekap', value: '2 hari → instan' },
        { label: 'Siswa terpantau', value: '1.200' },
        { label: 'Waktu muat dashboard', value: '< 1,4 detik' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.web, icon: IKON_KATEGORI.web },
    contoh: true,
  },
  {
    slug: 'platform-kursus-online',
    title: 'Platform Kursus Online',
    tagline: 'Kelas video dengan progres belajar dan sertifikat otomatis',
    category: 'web',
    stack: ['Vue 3', 'Supabase', 'Cloudinary', 'Stripe'],
    year: 2023,
    duration: '10 minggu',
    role: 'Full-stack',
    problem:
      'Pengajar lepas menjual kelas lewat grup WhatsApp. Materi tersebar di Google Drive, pembayaran dicatat manual, dan tidak ada cara mengetahui siapa yang benar-benar menonton sampai habis.',
    solution:
      'Platform kursus dengan katalog kelas, pemutar video yang menandai progres tiap bab, kuis di akhir modul, dan sertifikat PDF yang terbit otomatis setelah syarat lulus terpenuhi.',
    features: [
      'Pemutar video dengan pelacakan progres per bab',
      'Kuis pilihan ganda dengan penilaian otomatis',
      'Sertifikat PDF terbit otomatis saat lulus',
      'Pembayaran sekali beli atau langganan bulanan',
      'Diskusi per kelas dengan moderasi pengajar',
      'Panel pengajar untuk unggah materi dan lihat statistik',
    ],
    result: {
      metrics: [
        { label: 'Tingkat penyelesaian', value: 'naik 2,3x' },
        { label: 'Sertifikat terbit', value: '870' },
        { label: 'Waktu unggah materi', value: 'turun 70%' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.web, icon: IKON_KATEGORI.web },
    contoh: true,
  },
  {
    slug: 'aplikasi-kasir-keliling',
    title: 'Aplikasi Kasir Keliling',
    tagline: 'Tetap jalan tanpa internet, sinkron saat sinyal kembali',
    category: 'mobile',
    stack: ['Flutter', 'SQLite', 'Supabase', 'Riverpod'],
    year: 2024,
    duration: '7 minggu',
    role: 'Mobile Developer',
    featured: true,
    problem:
      'Penjual keliling berjualan di area pasar yang sinyalnya sering hilang. Aplikasi kasir berbasis web yang lama tidak bisa dipakai sama sekali saat offline, jadi transaksi kembali dicatat di kertas.',
    solution:
      'Aplikasi Android dengan database lokal. Semua transaksi disimpan di perangkat lebih dulu, lalu disinkronkan otomatis ke server begitu ada koneksi. Konflik data diselesaikan dengan urutan waktu transaksi.',
    features: [
      'Mode offline penuh dengan SQLite lokal',
      'Sinkronisasi otomatis saat online, antrean tahan putus',
      'Cetak struk lewat printer bluetooth',
      'Laporan harian tetap bisa dibuka tanpa internet',
      'Peringatan stok menipis saat membuka aplikasi',
      'Ukuran APK di bawah 18 MB',
    ],
    result: {
      metrics: [
        { label: 'Transaksi saat offline', value: 'tetap tercatat 100%' },
        { label: 'Waktu sinkron', value: '< 6 detik' },
        { label: 'Ukuran aplikasi', value: '17,4 MB' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.mobile, icon: IKON_KATEGORI.mobile },
    contoh: true,
  },
  {
    slug: 'aplikasi-absensi-gps',
    title: 'Aplikasi Absensi Berbasis GPS',
    tagline: 'Cegah titip absen dengan geofence dan selfie',
    category: 'mobile',
    stack: ['React Native', 'Expo', 'PostGIS', 'Firebase'],
    year: 2023,
    duration: '5 minggu',
    role: 'Mobile Developer',
    problem:
      'Absensi karyawan lapangan masih lewat pesan WhatsApp. Tidak ada bukti karyawan benar-benar berada di lokasi, sehingga titip absen sulit dibuktikan dan rekap gaji sering jadi sengketa.',
    solution:
      'Aplikasi absensi yang memvalidasi posisi karyawan terhadap radius lokasi kerja, dilengkapi foto selfie dan cap waktu server. Rekap otomatis masuk ke laporan bulanan yang dipakai bagian gaji.',
    features: [
      'Validasi geofence radius per lokasi kerja',
      'Foto selfie dengan cap waktu dari server',
      'Deteksi mock location pada perangkat Android',
      'Rekap kehadiran dan keterlambatan per bulan',
      'Pengajuan izin dan cuti langsung dari aplikasi',
      'Ekspor rekap untuk bagian penggajian',
    ],
    result: {
      metrics: [
        { label: 'Kasus titip absen', value: 'turun 100%' },
        { label: 'Waktu rekap gaji', value: '4 hari → 3 jam' },
        { label: 'Karyawan aktif', value: '240' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.mobile, icon: IKON_KATEGORI.mobile },
    contoh: true,
  },
  {
    slug: 'aplikasi-inventaris-desktop',
    title: 'Aplikasi Inventaris Gudang',
    tagline: 'Desktop app untuk gudang dengan stok 12.000 SKU',
    category: 'desktop',
    stack: ['Electron', 'Vue 3', 'SQLite', 'SheetJS'],
    year: 2023,
    duration: '9 minggu',
    role: 'Desktop Developer',
    problem:
      'Gudang dengan 12.000 SKU mencatat keluar-masuk barang di Excel yang dibagi lewat flashdisk. Sering terjadi dua orang mengedit file sama sehingga stok akhirnya tidak cocok dengan fisik.',
    solution:
      'Aplikasi desktop yang memasang database lokal di komputer gudang. Semua operator terhubung ke satu sumber data, dengan pencatatan stok masuk, keluar, dan penyesuaian yang tercatat siapa pelakunya.',
    features: [
      'Pencarian SKU cepat dengan barcode scanner',
      'Stok masuk, keluar, dan penyesuaian dengan jejak audit',
      'Impor massal dari Excel dengan validasi baris',
      'Peringatan stok minimum per kategori',
      'Cetak label barcode langsung dari aplikasi',
      'Backup otomatis harian ke folder jaringan',
    ],
    result: {
      metrics: [
        { label: 'Selisih stok opname', value: 'turun 88%' },
        { label: 'SKU terkelola', value: '12.000' },
        { label: 'Waktu input barang masuk', value: 'turun 65%' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.desktop, icon: IKON_KATEGORI.desktop },
    contoh: true,
  },
  {
    slug: 'api-gateway-multitenant',
    title: 'API Gateway Multi-Tenant',
    tagline: 'Satu backend melayani 40 klien dengan isolasi data ketat',
    category: 'database',
    stack: ['Node.js', 'PostgreSQL', 'Redis', 'Docker'],
    year: 2024,
    duration: '11 minggu',
    role: 'Backend',
    problem:
      'Setiap klien baru butuh server sendiri karena takut data antar perusahaan tercampur. Biaya infrastruktur membengkak dan proses onboarding memakan waktu berhari-hari.',
    solution:
      'Membangun satu API multi-tenant dengan isolasi berbasis row-level security di PostgreSQL. Satu deployment melayani banyak klien, dan pemisahan data dijamin di level database, bukan hanya di kode aplikasi.',
    features: [
      'Isolasi data per tenant lewat row-level security',
      'Rate limit per tenant dengan Redis',
      'Onboarding klien baru dalam hitungan menit',
      'Audit log setiap akses lintas tenant',
      'Migrasi skema tanpa downtime',
      'Dokumentasi API otomatis dengan OpenAPI',
    ],
    result: {
      metrics: [
        { label: 'Biaya server', value: 'turun 74%' },
        { label: 'Waktu onboarding', value: '3 hari → 8 menit' },
        { label: 'Tenant aktif', value: '40' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.database, icon: IKON_KATEGORI.database },
    contoh: true,
  },
  {
    slug: 'migrasi-database-legacy',
    title: 'Migrasi Database Legacy',
    tagline: 'Pindah 8 tahun data tanpa kehilangan satu baris pun',
    category: 'database',
    stack: ['MySQL', 'PostgreSQL', 'Python', 'Airflow'],
    year: 2023,
    duration: '7 minggu',
    role: 'Data Engineer',
    problem:
      'Sistem lama menyimpan data di MySQL dengan skema yang sudah diubah puluhan kali tanpa dokumentasi. Ada kolom yang isinya campur antara tanggal dan teks bebas, sehingga laporan bulanan sering error.',
    solution:
      'Memetakan skema lama, menulis aturan pembersihan per kolom, lalu memindahkan data secara bertahap dengan verifikasi jumlah baris dan checksum. Migrasi dijalankan berulang sampai hasilnya identik sebelum cutover.',
    features: [
      'Pemetaan 68 tabel lama ke skema baru',
      'Aturan pembersihan untuk kolom campur tipe',
      'Verifikasi checksum per tabel sebelum cutover',
      'Migrasi bertahap dengan mode dry-run',
      'Rollback plan yang sudah diuji',
      'Dokumentasi skema baru untuk tim internal',
    ],
    result: {
      metrics: [
        { label: 'Baris dipindahkan', value: '4,2 juta' },
        { label: 'Data hilang', value: '0' },
        { label: 'Downtime cutover', value: '23 menit' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.database, icon: IKON_KATEGORI.database },
    contoh: true,
  },
  {
    slug: 'deteksi-berita-palsu',
    title: 'Deteksi Berita Palsu Bahasa Indonesia',
    tagline: 'Model klasifikasi teks dengan akurasi 91% pada data uji',
    category: 'ai',
    stack: ['Python', 'PyTorch', 'IndoBERT', 'FastAPI'],
    year: 2024,
    duration: '12 minggu',
    role: 'ML Engineer',
    problem:
      'Berita palsu berbahasa Indonesia menyebar cepat lewat grup chat, sementara verifikasi manual butuh waktu lama. Model yang sudah ada kebanyakan dilatih untuk bahasa Inggris dan akurasinya jatuh saat dipakai di teks Indonesia.',
    solution:
      'Melatih ulang model bahasa Indonesia pada korpus berita terverifikasi, lalu membungkusnya jadi API yang bisa memeriksa teks dan mengembalikan skor beserta kata yang paling memengaruhi keputusan.',
    features: [
      'Fine-tuning IndoBERT pada 24.000 artikel',
      'Penjelasan kata kunci yang memengaruhi prediksi',
      'API prediksi dengan latensi di bawah 300ms',
      'Antarmuka unggah teks dan tautan berita',
      'Penyimpanan riwayat pemeriksaan',
      'Evaluasi berkala dengan data baru',
    ],
    result: {
      metrics: [
        { label: 'Akurasi uji', value: '91,2%' },
        { label: 'Latensi prediksi', value: '280 ms' },
        { label: 'Data latih', value: '24.000 artikel' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.ai, icon: IKON_KATEGORI.ai },
    contoh: true,
  },
  {
    slug: 'prediksi-penjualan-ritel',
    title: 'Prediksi Penjualan Ritel',
    tagline: 'Peramalan stok mingguan untuk 180 cabang',
    category: 'ai',
    stack: ['Python', 'Prophet', 'Pandas', 'Streamlit'],
    year: 2023,
    duration: '8 minggu',
    role: 'Data Scientist',
    problem:
      'Bagian pembelian menentukan jumlah stok berdasarkan feeling. Akibatnya sebagian cabang kehabisan barang saat ramai, sementara cabang lain menumpuk stok yang akhirnya kedaluwarsa.',
    solution:
      'Membangun model peramalan per cabang per produk yang memperhitungkan tren, musim, dan hari libur. Hasilnya disajikan sebagai rekomendasi jumlah pesanan yang bisa langsung dipakai tim pembelian.',
    features: [
      'Peramalan per cabang dan per produk',
      'Deteksi musim dan efek hari libur',
      'Rekomendasi jumlah pesanan otomatis',
      'Perbandingan prediksi vs realisasi',
      'Dashboard pemantauan akurasi model',
      'Ekspor rekomendasi ke format pembelian',
    ],
    result: {
      metrics: [
        { label: 'Barang kedaluwarsa', value: 'turun 41%' },
        { label: 'Kehabisan stok', value: 'turun 33%' },
        { label: 'Cabang tercakup', value: '180' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.ai, icon: IKON_KATEGORI.ai },
    contoh: true,
  },
  {
    slug: 'sistem-informasi-skripsi',
    title: 'Sistem Informasi Perpustakaan',
    tagline: 'Skripsi dengan pengujian black-box lengkap dan dokumentasi',
    category: 'skripsi',
    stack: ['Laravel', 'MySQL', 'Bootstrap', 'PHPUnit'],
    year: 2024,
    duration: '10 minggu',
    role: 'Full-stack',
    problem:
      'Perpustakaan kampus masih memakai buku besar untuk peminjaman. Sulit mengetahui siapa meminjam apa, dan denda keterlambatan dihitung manual sehingga sering salah.',
    solution:
      'Membangun sistem informasi peminjaman dengan pencatatan otomatis, perhitungan denda berdasarkan tanggal, dan laporan yang siap dilampirkan ke naskah skripsi beserta dokumentasi pengujiannya.',
    features: [
      'Katalog buku dengan pencarian dan filter',
      'Peminjaman dan pengembalian dengan barcode',
      'Perhitungan denda otomatis sesuai lama keterlambatan',
      'Laporan bulanan siap cetak',
      'Manajemen anggota dan hak akses petugas',
      'Dokumentasi pengujian black-box per fitur',
    ],
    result: {
      metrics: [
        { label: 'Kasus uji', value: '48 skenario' },
        { label: 'Bug saat sidang', value: '0' },
        { label: 'Nilai skripsi', value: 'A' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.skripsi, icon: IKON_KATEGORI.skripsi },
    contoh: true,
  },
  {
    slug: 'aplikasi-deteksi-daun-skripsi',
    title: 'Klasifikasi Penyakit Daun Padi',
    tagline: 'Capstone berbasis CNN dengan akurasi 94%',
    category: 'skripsi',
    stack: ['Python', 'TensorFlow', 'OpenCV', 'Flask'],
    year: 2023,
    duration: '14 minggu',
    role: 'ML Engineer',
    problem:
      'Petani kesulitan membedakan jenis penyakit pada daun padi. Salah identifikasi berakibat pada penggunaan pestisida yang tidak tepat dan menambah biaya.',
    solution:
      'Melatih model CNN untuk mengklasifikasi gambar daun ke dalam empat jenis penyakit, lalu membungkusnya dalam aplikasi web sederhana yang bisa dipakai dari ponsel petani.',
    features: [
      'Klasifikasi empat jenis penyakit daun',
      'Unggah foto langsung dari kamera ponsel',
      'Saran penanganan per jenis penyakit',
      'Confusion matrix dan laporan evaluasi model',
      'Augmentasi data untuk memperkuat model',
      'Aplikasi web responsif untuk ponsel',
    ],
    result: {
      metrics: [
        { label: 'Akurasi model', value: '94,3%' },
        { label: 'Gambar latih', value: '6.800' },
        { label: 'Waktu inferensi', value: '0,4 detik' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.skripsi, icon: IKON_KATEGORI.skripsi },
    contoh: true,
  },
  {
    slug: 'perbaikan-memory-leak',
    title: 'Perbaikan Memory Leak Produksi',
    tagline: 'Server yang restart tiap 6 jam jadi stabil berminggu-minggu',
    category: 'debug',
    stack: ['Node.js', 'Clinic.js', 'Docker', 'Grafana'],
    year: 2024,
    duration: '4 hari',
    role: 'Debugger',
    problem:
      'Server API restart sendiri setiap enam jam. Log hanya menampilkan proses keluar tanpa pesan error, dan tim sudah mencoba menaikkan batas memori tanpa hasil.',
    solution:
      'Memasang profiling untuk melacak pertumbuhan memori per fungsi. Penyebabnya adalah cache yang menyimpan koneksi database tanpa pernah dibersihkan, sehingga jumlahnya naik terus seiring waktu.',
    features: [
      'Profiling memori dengan Clinic.js',
      'Identifikasi kebocoran pada cache koneksi',
      'Perbaikan dengan batas ukuran dan TTL cache',
      'Pemantauan memori berkelanjutan di Grafana',
      'Uji beban untuk memastikan perbaikan bertahan',
      'Dokumentasi akar masalah untuk tim',
    ],
    result: {
      metrics: [
        { label: 'Restart server', value: 'tiap 6 jam → 0' },
        { label: 'Pemakaian memori', value: 'turun 68%' },
        { label: 'Waktu perbaikan', value: '4 hari' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.debug, icon: IKON_KATEGORI.debug },
    contoh: true,
  },
  {
    slug: 'perbaikan-query-lambat',
    title: 'Optimasi Query Laporan',
    tagline: 'Laporan yang butuh 47 detik jadi 0,8 detik',
    category: 'debug',
    stack: ['PostgreSQL', 'EXPLAIN', 'Redis', 'Laravel'],
    year: 2023,
    duration: '3 hari',
    role: 'Debugger',
    problem:
      'Halaman laporan bulanan butuh 47 detik untuk terbuka dan sering timeout. Pengguna mengira aplikasi rusak, padahal query-nya hanya belum dioptimalkan.',
    solution:
      'Menganalisis rencana eksekusi query, menambahkan indeks yang tepat, dan memecah satu query besar menjadi beberapa agregat yang di-cache. Hasil akhirnya sama, waktunya jauh lebih singkat.',
    features: [
      'Analisis rencana eksekusi dengan EXPLAIN ANALYZE',
      'Penambahan indeks komposit yang sesuai pola filter',
      'Pemecahan query agregat besar',
      'Cache hasil laporan dengan invalidasi terjadwal',
      'Uji hasil sebelum dan sesudah untuk memastikan data sama',
      'Pemantauan query lambat berkelanjutan',
    ],
    result: {
      metrics: [
        { label: 'Waktu muat laporan', value: '47s → 0,8s' },
        { label: 'Timeout', value: 'hilang total' },
        { label: 'Beban CPU database', value: 'turun 55%' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.debug, icon: IKON_KATEGORI.debug },
    contoh: true,
  },
  {
    slug: 'redesign-aplikasi-kesehatan',
    title: 'Redesign Aplikasi Kesehatan',
    tagline: 'Alur janji temu dipangkas dari 9 langkah jadi 3',
    category: 'design',
    stack: ['Figma', 'Design System', 'Prototyping', 'User Testing'],
    year: 2024,
    duration: '6 minggu',
    role: 'UI/UX Designer',
    problem:
      'Aplikasi lama meminta pengguna mengisi sembilan langkah untuk membuat janji temu dokter. Tingkat pembatalan di tengah jalan mencapai 62%, dan pengguna lansia paling banyak menyerah.',
    solution:
      'Merancang ulang alur menjadi tiga langkah dengan pilihan dokter yang sudah tersaring otomatis. Ukuran teks diperbesar dan kontras dinaikkan agar tetap terbaca oleh pengguna lanjut usia.',
    features: [
      'Alur janji temu dipangkas jadi tiga langkah',
      'Design system dengan 42 komponen konsisten',
      'Ukuran teks dan kontras sesuai WCAG AA',
      'Prototipe interaktif untuk pengujian',
      'Uji kegunaan dengan 12 responden',
      'Panduan implementasi untuk tim developer',
    ],
    result: {
      metrics: [
        { label: 'Pembatalan di tengah alur', value: '62% → 19%' },
        { label: 'Langkah pembuatan janji', value: '9 → 3' },
        { label: 'Skor SUS', value: '84/100' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.design, icon: IKON_KATEGORI.design },
    contoh: true,
  },
  {
    slug: 'tugas-besar-struktur-data',
    title: 'Visualisasi Algoritma Sorting',
    tagline: 'Tugas besar struktur data dengan animasi langkah per langkah',
    category: 'tugas_kuliah',
    stack: ['JavaScript', 'Canvas API', 'HTML', 'CSS'],
    year: 2023,
    duration: '2 minggu',
    role: 'Frontend',
    problem:
      'Tugas besar meminta penjelasan cara kerja lima algoritma pengurutan, tapi penjelasan di buku sulit dibayangkan. Dosen meminta ada demonstrasi yang bisa dilihat langsung saat presentasi.',
    solution:
      'Membuat halaman yang menganimasikan setiap perbandingan dan pertukaran nilai, dengan kontrol kecepatan dan penghitung langkah agar perbedaan efisiensi tiap algoritma terlihat jelas.',
    features: [
      'Animasi lima algoritma pengurutan',
      'Kontrol kecepatan dan langkah per langkah',
      'Penghitung perbandingan dan pertukaran',
      'Perbandingan waktu antar algoritma',
      'Penjelasan kompleksitas di samping animasi',
      'Berjalan langsung di browser tanpa instalasi',
    ],
    result: {
      metrics: [
        { label: 'Algoritma divisualkan', value: '5' },
        { label: 'Nilai tugas', value: 'A' },
        { label: 'Waktu pengerjaan', value: '2 minggu' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.tugas_kuliah, icon: IKON_KATEGORI.tugas_kuliah },
    contoh: true,
  },
]

/** Semua kategori yang benar-benar dipakai (untuk chip filter). */
export const kategoriTerpakai = () => {
  const set = new Set(proyek.map((p) => p.category))
  return Object.keys(LABEL_KATEGORI).filter((k) => set.has(k))
}

/** Jumlah proyek per kategori, untuk badge di chip filter. */
export const hitungPerKategori = () => {
  const map = {}
  for (const p of proyek) map[p.category] = (map[p.category] || 0) + 1
  return map
}

/** Proyek unggulan, maksimal `n`. */
export const proyekUnggulan = (n = 3) => proyek.filter((p) => p.featured).slice(0, n)

/** Cari proyek berdasarkan slug. */
export const cariSlug = (slug) => proyek.find((p) => p.slug === slug) || null

/**
 * Filter + pencarian.
 * `q` dicocokkan ke judul, tagline, stack, dan kategori.
 */
export const filterProyek = ({ kategori = 'semua', q = '' } = {}) => {
  const kata = q.trim().toLowerCase()
  return proyek.filter((p) => {
    if (kategori !== 'semua' && p.category !== kategori) return false
    if (!kata) return true
    const kolam = [p.title, p.tagline, p.category, LABEL_KATEGORI[p.category], ...p.stack]
      .join(' ')
      .toLowerCase()
    return kolam.includes(kata)
  })
}

/** Proyek lain di kategori sama, maksimal `n`. */
export const proyekTerkait = (slug, n = 3) => {
  const ini = cariSlug(slug)
  if (!ini) return []
  return proyek.filter((p) => p.slug !== slug && p.category === ini.category).slice(0, n)
}

/** Statistik agregat untuk hero. */
export const statistik = () => ({
  jumlahProyek: proyek.length,
  jumlahKategori: kategoriTerpakai().length,
  jumlahStack: new Set(proyek.flatMap((p) => p.stack)).size,
  tahunAwal: Math.min(...proyek.map((p) => p.year)),
  tahunAkhir: Math.max(...proyek.map((p) => p.year)),
})

// Jaga konsistensi: kategori portofolio harus ada di pricing.js.
if (import.meta.env?.DEV) {
  const asing = [...new Set(proyek.map((p) => p.category))].filter(
    (k) => !KATEGORI_VALID.includes(k),
  )
  if (asing.length) {
    console.warn('[portfolio] kategori tidak dikenal di pricing.js:', asing.join(', '))
  }
}
