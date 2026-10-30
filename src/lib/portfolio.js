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
 * src/lib/kategori.js supaya konsisten dengan layanan yang dijual.
 */

import { KATEGORI_VALID } from './kategori'

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
 * 29 studi kasus contoh, membentang dari 2023 sampai 2026. Sebaran
 * kategori mengikuti layanan yang dijual: web 5, mobile 4, desktop 2,
 * database 4, ai 4, skripsi 3, debug 3, design 2, tugas_kuliah 2.
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
  {
    slug: 'marketplace-jasa-lokal',
    title: 'Marketplace Jasa Lokal',
    tagline: 'Pemesanan jasa rumahan dengan jadwal dan pembayaran terpadu',
    category: 'web',
    stack: ['Vue 3', 'Vite', 'Supabase', 'Midtrans', 'Tailwind'],
    year: 2026,
    duration: '10 minggu',
    role: 'Fullstack Developer',
    featured: true,
    problem:
      'Penyedia jasa rumahan seperti tukang servis dan penjahit menerima pesanan lewat pesan pribadi. Jadwal bentrok, harga tidak seragam, dan tidak ada catatan pesanan yang bisa ditelusuri saat pelanggan mengeluh.',
    solution:
      'Satu tempat untuk menampilkan jasa, memilih slot jadwal yang benar-benar kosong, dan membayar di muka. Slot dikunci saat pembayaran dimulai dan dilepas otomatis kalau tidak diselesaikan, jadi dua pelanggan tidak bisa memesan waktu yang sama.',
    features: [
      'Kalender slot dengan penguncian sementara saat checkout',
      'Pelepasan slot otomatis kalau pembayaran kedaluwarsa',
      'Halaman toko per penyedia jasa dengan ulasan terverifikasi',
      'Pembayaran terpadu dan riwayat transaksi',
      'Panel penyedia untuk mengatur harga dan ketersediaan',
      'Pencarian berdasarkan lokasi dan jenis jasa',
    ],
    result: {
      metrics: [
        { label: 'Pesanan bentrok', value: 'tidak lagi terjadi' },
        { label: 'Waktu konfirmasi', value: 'manual → otomatis' },
        { label: 'Status pesanan', value: 'bisa dilacak pelanggan' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.web, icon: IKON_KATEGORI.web },
    contoh: true,
  },
  {
    slug: 'asisten-tanya-jawab-dokumen',
    title: 'Asisten Tanya-Jawab Dokumen Internal',
    tagline: 'Menjawab pertanyaan SOP dengan rujukan halaman aslinya',
    category: 'ai',
    stack: ['Python', 'FastAPI', 'pgvector', 'LangChain', 'Vue 3'],
    year: 2026,
    duration: '9 minggu',
    role: 'AI Engineer',
    featured: true,
    problem:
      'SOP dan panduan kerja tersebar di puluhan berkas PDF. Karyawan baru menghabiskan berjam-jam bertanya ke senior hanya untuk menemukan satu prosedur, dan jawaban lisan mudah berbeda antar orang.',
    solution:
      'Dokumen dipecah menjadi potongan kecil lalu diubah menjadi vektor dan disimpan di pgvector. Pertanyaan dicari ke potongan paling relevan, dan jawaban disusun hanya dari potongan itu dengan menyertakan berkas serta halaman asalnya. Kalau konteks tidak cukup, sistem menolak menjawab alih-alih menebak.',
    features: [
      'Pemecahan dokumen dengan tumpang tindih antar potongan',
      'Pencarian gabungan vektor dan kata kunci',
      'Setiap jawaban menyertakan rujukan berkas dan halaman',
      'Penolakan eksplisit saat konteks tidak mencukupi',
      'Penjadwalan ulang indeks saat dokumen diperbarui',
      'Panel uji berisi daftar pertanyaan dan jawaban acuan',
    ],
    result: {
      metrics: [
        { label: 'Jawaban tanpa rujukan', value: 'tidak ada' },
        { label: 'Waktu mencari SOP', value: 'menit → detik' },
        { label: 'Perilaku saat ragu', value: 'menolak, bukan menebak' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.ai, icon: IKON_KATEGORI.ai },
    contoh: true,
  },
  {
    slug: 'monitoring-plts-desktop',
    title: 'Aplikasi Monitoring Panel Surya',
    tagline: 'Melihat panel mana yang produksinya menurun, saat itu juga',
    category: 'desktop',
    stack: ['Electron', 'TypeScript', 'MQTT', 'SQLite', 'Chart.js'],
    year: 2026,
    duration: '8 minggu',
    role: 'Desktop Developer',
    problem:
      'Data inverter dicatat manual setiap pagi dengan membaca layar perangkat satu per satu. Kalau satu panel berhenti berproduksi karena kabel longgar, gangguannya baru ketahuan setelah berhari-hari.',
    solution:
      'Aplikasi desktop berlangganan topik MQTT dari logger, menyimpan riwayat ke database lokal, dan membandingkan produksi tiap panel dengan panel tetangganya. Penyimpangan yang menetap ditandai sebagai peringatan.',
    features: [
      'Grafik produksi per panel dan total harian',
      'Perbandingan panel dengan tetangga sekitarnya',
      'Ambang peringatan yang bisa diatur per lokasi',
      'Riwayat tetap terbaca walau jaringan putus',
      'Ekspor CSV untuk laporan bulanan',
      'Mode layar penuh untuk dipasang di ruang kontrol',
    ],
    result: {
      metrics: [
        { label: 'Pencatatan harian', value: 'manual → otomatis' },
        { label: 'Deteksi panel bermasalah', value: 'hari → jam' },
        { label: 'Data saat offline', value: 'tetap tersimpan lokal' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.desktop, icon: IKON_KATEGORI.desktop },
    contoh: true,
  },
  {
    slug: 'aplikasi-bank-sampah',
    title: 'Aplikasi Bank Sampah Warga',
    tagline: 'Setoran sampah tercatat rapi dan saldo warga transparan',
    category: 'mobile',
    stack: ['Flutter', 'Supabase', 'Riverpod', 'Camera'],
    year: 2026,
    duration: '7 minggu',
    role: 'Mobile Developer',
    problem:
      'Pencatatan setoran sampah dilakukan di buku tulis yang dipegang satu petugas. Warga tidak tahu saldonya, buku mudah hilang, dan rekap akhir bulan harus dihitung ulang dari nol.',
    solution:
      'Petugas menimbang dan mencatat lewat aplikasi, warga melihat saldo serta riwayat setorannya sendiri. Setiap setoran menyimpan foto timbangan sebagai bukti, dan rekap bulanan terbentuk otomatis dari data yang sama.',
    features: [
      'Pencatatan setoran per jenis sampah dan beratnya',
      'Foto timbangan sebagai bukti setoran',
      'Saldo dan riwayat yang bisa dilihat warga',
      'Rekap bulanan otomatis per rumah',
      'Pencarian riwayat berdasarkan tanggal',
      'Mode hemat data untuk jaringan lambat',
    ],
    result: {
      metrics: [
        { label: 'Buku catatan manual', value: 'digantikan aplikasi' },
        { label: 'Rekap bulanan', value: 'hitung ulang → otomatis' },
        { label: 'Sengketa saldo', value: 'ada bukti foto timbangan' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.mobile, icon: IKON_KATEGORI.mobile },
    contoh: true,
  },
  {
    slug: 'optimasi-laporan-keuangan',
    title: 'Optimasi Laporan Keuangan yang Lambat',
    tagline: 'Dari query berjalan semenit menjadi hitungan detik',
    category: 'debug',
    stack: ['PostgreSQL', 'EXPLAIN ANALYZE', 'Redis', 'Laravel'],
    year: 2026,
    duration: '3 minggu',
    role: 'Backend Engineer',
    problem:
      'Laporan bulanan memanggil satu query yang menggabungkan beberapa tabel besar tanpa indeks yang tepat. Halaman sering berputar lama, dan saat beberapa orang membukanya bersamaan, seluruh aplikasi ikut melambat.',
    solution:
      'Query diurai dengan EXPLAIN ANALYZE untuk melihat bagian mana yang paling mahal. Indeks ditambahkan pada kolom yang dipakai untuk menyaring dan mengurutkan, agregat berat dipindahkan ke tabel ringkasan yang diperbarui berkala, dan hasil laporan disimpan sementara.',
    features: [
      'Profil query dengan EXPLAIN ANALYZE',
      'Indeks gabungan sesuai pola penyaringan',
      'Tabel ringkasan untuk agregat bulanan',
      'Cache hasil laporan dengan masa berlaku jelas',
      'Pembatalan query yang berjalan terlalu lama',
      'Pemantauan query lambat setelah perbaikan',
    ],
    result: {
      metrics: [
        { label: 'Waktu laporan', value: 'puluhan detik → di bawah 2 detik' },
        { label: 'Beban saat ramai', value: 'tidak lagi saling mengunci' },
        { label: 'Regresi', value: 'dijaga pemantauan query lambat' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.debug, icon: IKON_KATEGORI.debug },
    contoh: true,
  },
  {
    slug: 'redesign-portal-desa',
    title: 'Perancangan Ulang Portal Informasi Desa',
    tagline: 'Informasi publik yang terbaca di layar kecil dan sinyal lemah',
    category: 'design',
    stack: ['Figma', 'Design Token', 'Tailwind', 'WCAG 2.2'],
    year: 2026,
    duration: '5 minggu',
    role: 'UI/UX Designer',
    problem:
      'Portal desa penuh tabel panjang dan teks kecil. Di ponsel hampir tidak terbaca, dan warga yang ingin melihat jadwal posyandu atau syarat surat harus menggulir jauh sambil memperbesar layar.',
    solution:
      'Isi portal disusun ulang berdasarkan pertanyaan yang paling sering ditanyakan warga. Navigasi dibuat sederhana, tabel diganti daftar yang bisa dibaca di layar sempit, dan seluruh warna diuji kontrasnya sebelum diserahkan ke pengembang.',
    features: [
      'Kartu informasi prioritas di halaman depan',
      'Tabel panjang diubah menjadi daftar yang bisa dipindai',
      'Ukuran sentuh minimal 44 piksel',
      'Kontras teks diuji terhadap standar aksesibilitas',
      'Mode gelap memakai nilai token, bukan timpaan warna',
      'Panduan komponen untuk pengembang',
    ],
    result: {
      metrics: [
        { label: 'Keterbacaan di ponsel', value: 'tanpa perlu memperbesar' },
        { label: 'Kontras teks', value: 'memenuhi ambang aksesibilitas' },
        { label: 'Serah terima', value: 'disertai token dan panduan' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.design, icon: IKON_KATEGORI.design },
    contoh: true,
  },
  {
    slug: 'pipeline-data-akademik',
    title: 'Pipeline Data Akademik Terjadwal',
    tagline: 'Menyatukan data dari beberapa sistem jadi satu sumber',
    category: 'database',
    stack: ['Python', 'dbt', 'PostgreSQL', 'Airflow', 'Great Expectations'],
    year: 2026,
    duration: '8 minggu',
    role: 'Data Engineer',
    problem:
      'Data mahasiswa, nilai, dan kehadiran tinggal di tiga sistem berbeda dengan format tanggal dan kode yang tidak seragam. Setiap kali pimpinan minta rekap, staf harus menggabungkannya manual di spreadsheet.',
    solution:
      'Data ditarik terjadwal, dibersihkan dan diseragamkan lewat model transformasi berlapis, lalu digabung menjadi satu tabel fakta. Setiap tahap punya pemeriksaan kualitas data yang menghentikan proses kalau ada yang aneh, supaya angka salah tidak menyebar diam-diam.',
    features: [
      'Penarikan terjadwal dari tiga sumber berbeda',
      'Penyeragaman format tanggal dan kode program studi',
      'Pemeriksaan kualitas data di setiap tahap',
      'Proses berhenti dan memberi peringatan bila data menyimpang',
      'Tabel fakta tunggal untuk pelaporan',
      'Riwayat perubahan data untuk penelusuran',
    ],
    result: {
      metrics: [
        { label: 'Penggabungan manual', value: 'digantikan pipeline' },
        { label: 'Data menyimpang', value: 'tertahan di tahap pemeriksaan' },
        { label: 'Sumber angka', value: 'satu tabel fakta' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.database, icon: IKON_KATEGORI.database },
    contoh: true,
  },
  {
    slug: 'sistem-pengaduan-warga',
    title: 'Sistem Pengaduan Warga',
    tagline: 'Laporan masuk, ditindaklanjuti, dan bisa dipantau pelapornya',
    category: 'web',
    stack: ['Vue 3', 'Supabase', 'PostGIS', 'Tailwind'],
    year: 2025,
    duration: '6 minggu',
    role: 'Fullstack Developer',
    problem:
      'Pengaduan warga masuk lewat banyak saluran tanpa nomor tiket. Laporan yang sama dikirim berulang kali, dan pelapor tidak pernah tahu apakah laporannya sudah ditangani.',
    solution:
      'Setiap laporan mendapat nomor tiket dan titik lokasi. Petugas memperbarui status, dan pelapor bisa memeriksa perkembangan laporannya dengan nomor tiket tanpa perlu membuat akun.',
    features: [
      'Nomor tiket untuk setiap laporan',
      'Penandaan lokasi kejadian pada peta',
      'Pengelompokan laporan serupa di area berdekatan',
      'Pembaruan status yang terlihat oleh pelapor',
      'Pencarian status cukup dengan nomor tiket',
      'Rekap laporan per wilayah dan kategori',
    ],
    result: {
      metrics: [
        { label: 'Laporan ganda', value: 'dikelompokkan, bukan diduplikasi' },
        { label: 'Pelapor memeriksa status', value: 'mandiri lewat nomor tiket' },
        { label: 'Penelusuran', value: 'setiap perubahan status tercatat' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.web, icon: IKON_KATEGORI.web },
    contoh: true,
  },
  {
    slug: 'presensi-wajah-karyawan',
    title: 'Presensi Wajah untuk Karyawan Pabrik',
    tagline: 'Absensi tanpa kartu, tetap akurat saat wajah memakai pelindung',
    category: 'ai',
    stack: ['Python', 'ONNX Runtime', 'OpenCV', 'FastAPI', 'PostgreSQL'],
    year: 2025,
    duration: '10 minggu',
    role: 'Machine Learning Engineer',
    problem:
      'Karyawan memakai masker dan pelindung kepala, sehingga mesin presensi berbasis kartu sering dipinjamkan dan absensi berbasis wajah biasa gagal mengenali. Antrean di pintu masuk jadi panjang setiap pergantian shift.',
    solution:
      'Model pengenalan wajah dijalankan lokal di perangkat pintu masuk agar tidak bergantung jaringan, dengan ambang kemiripan yang dikalibrasi ulang memakai foto karyawan bermasker. Wajah yang ragu dikenali diarahkan ke verifikasi kedua, bukan langsung ditolak.',
    features: [
      'Pengenalan berjalan lokal di perangkat pintu masuk',
      'Kalibrasi memakai foto karyawan bermasker',
      'Verifikasi kedua saat tingkat kemiripan meragukan',
      'Pencatatan waktu dari jam server, bukan perangkat',
      'Antrean lokal saat jaringan terputus',
      'Laporan kehadiran per shift dan per bagian',
    ],
    result: {
      metrics: [
        { label: 'Ketergantungan jaringan', value: 'tidak ada saat presensi' },
        { label: 'Kasus ragu', value: 'diverifikasi ulang, bukan ditolak' },
        { label: 'Antrean shift', value: 'berkurang karena pengenalan lokal' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.ai, icon: IKON_KATEGORI.ai },
    contoh: true,
  },
  {
    slug: 'aplikasi-kurir-harian',
    title: 'Aplikasi Kurir Harian',
    tagline: 'Rute, bukti kirim, dan setoran tunai dalam satu alur',
    category: 'mobile',
    stack: ['Kotlin', 'Jetpack Compose', 'Room', 'Google Maps SDK'],
    year: 2025,
    duration: '6 minggu',
    role: 'Mobile Developer',
    problem:
      'Kurir harian mengatur rutenya sendiri di kertas, bukti pengiriman berupa foto di galeri ponsel, dan uang setoran dicatat terpisah. Rekonsiliasi akhir hari sering tidak cocok dan sulit ditelusuri.',
    solution:
      'Aplikasi menyusun urutan antar berdasarkan jarak, meminta bukti foto dan tanda tangan di lokasi, lalu menutup hari dengan rekap uang yang harus disetor. Data tersimpan lokal lebih dulu sehingga tetap jalan di area tanpa sinyal.',
    features: [
      'Urutan antar berdasarkan jarak tempuh',
      'Bukti foto dan tanda tangan di lokasi tujuan',
      'Pencatatan penerimaan tunai per antar',
      'Rekap setoran akhir hari yang harus cocok',
      'Penyimpanan lokal saat sinyal hilang',
      'Navigasi langsung ke alamat tujuan',
    ],
    result: {
      metrics: [
        { label: 'Rekonsiliasi setoran', value: 'cocok otomatis di akhir hari' },
        { label: 'Bukti pengiriman', value: 'melekat pada tiap pesanan' },
        { label: 'Area tanpa sinyal', value: 'tetap bisa mencatat' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.mobile, icon: IKON_KATEGORI.mobile },
    contoh: true,
  },
  {
    slug: 'layanan-notifikasi-terpusat',
    title: 'Layanan Notifikasi Terpusat',
    tagline: 'Satu pintu kirim untuk email, WhatsApp, dan notifikasi aplikasi',
    category: 'database',
    stack: ['Node.js', 'PostgreSQL', 'Redis', 'BullMQ', 'Docker'],
    year: 2025,
    duration: '7 minggu',
    role: 'Backend Engineer',
    problem:
      'Setiap fitur mengirim notifikasi dengan caranya sendiri. Kredensial tersebar di banyak tempat, pengiriman ulang tidak terkendali, dan saat penyedia sedang gangguan, pesan hilang tanpa jejak.',
    solution:
      'Semua pengiriman lewat satu layanan dengan antrean. Setiap pesan punya status yang jelas, percobaan ulang memakai jeda yang makin panjang, dan pesan yang tetap gagal masuk ke daftar periksa manual alih-alih hilang.',
    features: [
      'Satu antarmuka untuk email, WhatsApp, dan push',
      'Antrean dengan percobaan ulang berjeda',
      'Status pesan yang bisa dilacak per penerima',
      'Pencegahan pengiriman ganda dengan kunci idempoten',
      'Daftar pesan gagal untuk ditangani manual',
      'Kredensial tersimpan di satu tempat',
    ],
    result: {
      metrics: [
        { label: 'Pesan hilang diam-diam', value: 'tidak ada, semua berstatus' },
        { label: 'Kiriman ganda', value: 'dicegah kunci idempoten' },
        { label: 'Kredensial', value: 'terpusat di satu layanan' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.database, icon: IKON_KATEGORI.database },
    contoh: true,
  },
  {
    slug: 'skripsi-analisis-emosi-teks',
    title: 'Analisis Emosi Ulasan Produk',
    tagline: 'Membandingkan model klasik dan transformer pada teks berbahasa Indonesia',
    category: 'skripsi',
    stack: ['Python', 'scikit-learn', 'PyTorch', 'IndoBERT', 'Pandas'],
    year: 2025,
    duration: '14 minggu',
    role: 'Peneliti',
    problem:
      'Ulasan produk berbahasa Indonesia bercampur bahasa gaul, singkatan, dan salah tulis. Model yang dilatih pada teks formal turun tajam ketepatannya saat diuji pada ulasan seperti ini.',
    solution:
      'Data dibersihkan bertahap dengan normalisasi kamus singkatan, lalu tiga pendekatan dibandingkan memakai pembagian data yang sama dan metrik yang sama. Kesalahan model dianalisis per kelas agar penurunan performa bisa dijelaskan, bukan hanya dilaporkan.',
    features: [
      'Normalisasi singkatan dan bahasa gaul',
      'Perbandingan model klasik dan transformer',
      'Pembagian data dan metrik yang seragam',
      'Analisis kesalahan per kelas emosi',
      'Pembahasan keterbatasan dan bias data',
      'Naskah dan kode siap diperiksa ulang',
    ],
    result: {
      metrics: [
        { label: 'Perbandingan model', value: 'kondisi uji disamakan' },
        { label: 'Analisis kesalahan', value: 'dibahas per kelas' },
        { label: 'Keterbatasan', value: 'ditulis terbuka' },
      ],
    },
    mockup: { gradient: GRADIEN_KATEGORI.skripsi, icon: IKON_KATEGORI.skripsi },
    contoh: true,
  },
  {
    slug: 'tugas-besar-basis-data',
    title: 'Perancangan Basis Data Perpustakaan',
    tagline: 'Dari skema kertas menjadi basis data ternormalisasi dengan uji query',
    category: 'tugas_kuliah',
    stack: ['PostgreSQL', 'ERD', 'SQL', 'dbdiagram'],
    year: 2025,
    duration: '4 minggu',
    role: 'Mahasiswa',
    problem:
      'Tugas meminta perancangan basis data perpustakaan, tetapi studi kasus di soal masih berupa daftar kolom yang saling tumpang tindih sehingga sulit menentukan kunci dan relasi antar tabel.',
    solution:
      'Kebutuhan dipetakan dulu menjadi entitas dan aturan bisnis, lalu skema dinormalisasi bertahap sampai bentuk ketiga. Setiap tabel diuji dengan query nyata seperti peminjaman terlambat dan ketersediaan buku.',
    features: [
      'Diagram relasi entitas lengkap dengan kardinalitas',
      'Normalisasi sampai bentuk ketiga disertai alasannya',
      'Batas dan kunci asing pada setiap relasi',
      'Query uji untuk peminjaman dan keterlambatan',
      'Data contoh untuk membuktikan query berjalan',
      'Catatan asumsi dan keputusan perancangan',
    ],
    result: {
      metrics: [
        { label: 'Normalisasi', value: 'sampai bentuk ketiga' },
        { label: 'Query uji', value: 'dijalankan pada data contoh' },
        { label: 'Asumsi', value: 'ditulis dan dijelaskan' },
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

/**
 * Proyek unggulan, maksimal `n`.
 * Diurutkan dari tahun terbaru supaya blok unggulan tidak terus menampilkan
 * proyek lama hanya karena posisinya lebih awal di array.
 */
export const proyekUnggulan = (n = 3) =>
  proyek
    .filter((p) => p.featured)
    .sort((a, b) => b.year - a.year)
    .slice(0, n)

/** Cari proyek berdasarkan slug. */
export const cariSlug = (slug) => proyek.find((p) => p.slug === slug) || null

/**
 * Filter + pencarian + pengurutan.
 * `q` dicocokkan ke judul, tagline, stack, dan kategori.
 * `urut`: 'default' | 'terbaru' | 'terlama' | 'judul'.
 * Mengembalikan array baru supaya urutan asli `proyek` tidak berubah.
 */
export const URUTAN = [
  { nilai: 'default', label: 'Urutan bawaan' },
  { nilai: 'terbaru', label: 'Tahun terbaru' },
  { nilai: 'terlama', label: 'Tahun terlama' },
  { nilai: 'judul', label: 'Judul A–Z' },
]

export const filterProyek = ({ kategori = 'semua', q = '', urut = 'default' } = {}) => {
  const kata = q.trim().toLowerCase()
  const hasil = proyek.filter((p) => {
    if (kategori !== 'semua' && p.category !== kategori) return false
    if (!kata) return true
    const kolam = [p.title, p.tagline, p.category, LABEL_KATEGORI[p.category], ...p.stack]
      .join(' ')
      .toLowerCase()
    return kolam.includes(kata)
  })

  if (urut === 'terbaru') return hasil.sort((a, b) => b.year - a.year)
  if (urut === 'terlama') return hasil.sort((a, b) => a.year - b.year)
  if (urut === 'judul') return hasil.sort((a, b) => a.title.localeCompare(b.title, 'id'))
  return hasil
}

/** Proyek lain di kategori sama, maksimal `n`. */
export const proyekTerkait = (slug, n = 3) => {
  const ini = cariSlug(slug)
  if (!ini) return []
  // Tahun terbaru lebih dulu, supaya proyek terkait tidak selalu yang paling lama.
  return proyek
    .filter((p) => p.slug !== slug && p.category === ini.category)
    .sort((a, b) => b.year - a.year)
    .slice(0, n)
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
