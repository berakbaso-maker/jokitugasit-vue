// Artikel blog JokiTugasIT.id - konten SEO long-tail
// Posisi: bantuan belajar, debugging, review, konsultasi - bukan jaminan nilai/kelulusan
export const posts = [
  {
    slug: 'kenapa-kode-chatgpt-sering-error',
    title: 'Kenapa Kode dari ChatGPT Sering Error? Ini Cara Memperbaikinya',
    date: '2026-09-01',
    excerpt: 'Kode hasil ChatGPT yang error bikin pusing? Ini 5 penyebab paling umum kenapa kode AI sering nggak jalan, plus cara memperbaikinya.',
    keywords: ['kode chatgpt error', 'debug kode ai', 'error chatgpt coding'],
    readTime: 4,
    sections: [
      { h: 'Pernah Ngalamin Kode ChatGPT Error?', p: [
        'Ceritanya selalu sama: kamu minta ChatGPT bikin fungsi, copy-paste ke editor, terus muncul error merah. Padahal di chat-nya keliatan bener. Tenang, kamu nggak sendirian — ini masalah paling umum yang ditanyain mahasiswa IT.',
        'Masalahnya bukan kamu yang salah copy. Ada beberapa alasan teknis kenapa kode hasil AI sering error pas dijalankan di lingkungan asli.',
      ]},
      { h: '1. Versi Library Berbeda', p: [
        'ChatGPT dilatih dari banyak versi library. Kadang dia kasih kode buat versi lama (atau versi baru) yang beda dari yang terpasang di komputer kamu. Contoh paling sering: React, Laravel, dan Flutter yang update-nya cepat banget.',
        'Cek dulu versi library kamu dengan perintah seperti `pip show`, `npm list`, atau `flutter --version`. Cocokkan dengan versi yang diminta kode itu.',
      ]},
      { h: '2. Konteks Project Nggak Lengkap', p: [
        'AI cuma ngeliat potongan kode yang kamu kasih. Dia nggak tahu struktur folder, nama variabel lain, atau konfigurasi project kamu. Makanya kode yang dia kasih sering nyebut fungsi yang nggak ada di project kamu.',
        'Solusi: kasih konteks lebih lengkap ke AI — struktur folder, file yang terkait, dan error message persisnya.',
      ]},
      { h: '3. Dependency yang Kurang atau Bentrok', p: [
        'Kode baru butuh package yang belum diinstall, atau package yang udah ada versinya bentrok. Ini biasanya muncul sebagai error "Module not found" atau "Cannot find package".',
        'Jalankan `npm install` atau install dependency yang diminta kode, lalu cek package.json kamu.',
      ]},
      { h: '4. Environment & Path Berbeda', p: [
        'Kode yang jalan di server AI nggak selalu jalan di laptop kamu. Beda OS, beda Python version, beda environment variable — semua bisa bikin error yang susah ditebak.',
        'Pastikan environment kamu sesuai: Python 3.x, Node versi terbaru, atau path file yang benar.',
      ]},
      { h: '5. Logic yang Keliatan Bener tapi Hasil Salah', p: [
        'Ini yang paling nyebelin: nggak ada error merah, tapi hasilnya salah. Bisa jadi logikanya muter-muter, index out of range, atau kondisi yang nggak pernah kepenuhan.',
        'Coba tambahkan `print()` atau `console.log()` di beberapa titik buat lihat nilai variabel — ini cara paling efektif nemuin logic error.',
      ]},
      { h: 'Masih Mentok? Bantuan Engineer Siap', p: [
        'Kalau udah coba semua cara di atas tapi kode masih error dan deadline makin deket, nggak perlu panik. Engineer JokiTugasIT.id bisa bantu cari akar masalahnya, perbaiki, sampai kode kamu bener-bener jalan.',
        'Kamu tinggal ceritain masalahnya — screenshot error, kode yang bermasalah, atau brief tugas. Gratis dicek dulu, baru kita bahas solusinya.',
      ]},
    ],
  },
  {
    slug: 'cara-pilih-jasa-bantu-tugas-it-yang-aman',
    title: 'Cara Pilih Jasa Bantu Tugas IT yang Aman (Anti Zonk)',
    date: '2026-09-01',
    excerpt: 'Banyak jasa joki tugas IT, tapi nggak semua aman. Ini 5 hal yang wajib dicek sebelum kirim tugas ke jasa bantuan coding mana pun.',
    keywords: ['jasa bantu tugas it aman', 'cara pilih joki tugas', 'joki tugas terpercaya'],
    readTime: 5,
    sections: [
      { h: 'Jasa Bantu Tugas IT: Banyak, tapi Hati-hati', p: [
        'Semakin banyak mahasiswa yang butuh bantuan coding, semakin banyak juga jasa yang muncul. Tapi nggak semua jasa itu aman — ada yang abal-abal, ghosting, atau bahkan ngerjain asal-asalan.',
        'Biar tugas kamu aman dan nggak zonk, ada beberapa hal yang wajib kamu cek dulu sebelum kirim project.',
      ]},
      { h: '1. Cek Transparansi Proses', p: [
        'Jasa yang aman selalu transparan: ada alur jelas, ada nomor tiket/order, dan kamu bisa cek status pengerjaan kapan aja. Kalau cuma "kirim dulu, nanti kabarin", waspada.',
        'Di JokiTugasIT.id, setiap request dapat nomor referensi (contoh: JT1234) yang bisa dicek statusnya di halaman Cek Status.',
      ]},
      { h: '2. Komunikasi Langsung ke Engineer', p: [
        'Jasa yang aman ngasih kamu akses langsung ke orang yang ngerjain — bukan cuma CS yang muter-muter. Kamu bisa tanya progress, diskusi detail, dan minta revisi langsung.',
        'Kalau bisa chat WhatsApp langsung ke engineer-nya, itu tanda bagus.',
      ]},
      { h: '3. Ada Bukti Project Sebelumnya', p: [
        'Lihat portofolio atau contoh project yang pernah dikerjain. Jasa yang punya track record biasanya nggak segan nunjukin hasil kerjanya.',
        'Hati-hati sama jasa yang cuma janji manis tanpa bukti.',
      ]},
      { h: '4. Pembayaran Bertahap', p: [
        'Jasa yang aman nggak minta bayar lunas di awal. Pola yang sehat: DP dulu, pelunasan setelah project selesai dan kamu review hasilnya.',
        'Kalau diminta bayar full di muka dengan nominal gede, itu red flag.',
      ]},
      { h: '5. Posisi Layanan yang Jelas', p: [
        'Jasa yang bener-bener bantu itu posisinya sebagai pendamping teknis: bantu debug, review kode, konsultasi, dan pendampingan — bukan "garansi nilai A" atau ngerjain ujian buat kamu.',
        'Hindari jasa yang menjanjikan nilai/kelulusan. Itu selain nggak etis, juga nggak realistis.',
      ]},
      { h: 'Kesimpulan', p: [
        'Intinya: pilih jasa yang transparan, bisa diajak komunikasi langsung, ada bukti kerja, dan pembayarannya wajar. Dengan begitu tugas kamu beres dan kamu juga belajar dari prosesnya.',
        'Kalau kamu lagi cari bantuan yang aman buat tugas IT, JokiTugasIT.id siap bantu — konsultasi gratis, cek project gratis, dan kamu bisa pantau statusnya sendiri.',
      ]},
    ],
  },
  {
    slug: 'cara-membuat-crud-php-mysql-untuk-tugas-kuliah',
    title: 'Cara Membuat CRUD PHP MySQL untuk Tugas Kuliah (Lengkap)',
    date: '2026-09-02',
    excerpt: 'Tugas bikin CRUD PHP MySQL gampang pusing? Ini panduan step-by-step bikin Create, Read, Update, Delete sederhana yang rapi dan bisa langsung dikumpulin.',
    keywords: ['tutorial crud php', 'crud php mysql tugas', 'bikin crud tugas kuliah'],
    readTime: 6,
    sections: [
      { h: 'CRUD Itu Nggak Seseram Kelihatannya', p: [
        'CRUD (Create, Read, Update, Delete) adalah dasar hampir semua aplikasi. Kalau kamu paham pola ini, kamu bisa bikin aplikasi apa pun — dari data mahasiswa, inventori, sampai sistem kasir.',
        'Buat tugas kuliah, dosen biasanya cuma butuh CRUD yang jalan, rapi, dan ada validasi dasar. Nggak perlu over-engineering.',
      ]},
      { h: '1. Siapkan Database & Koneksi', p: [
        'Buat database di phpMyAdmin, misalnya `db_tugas`. Lalu buat satu tabel sederhana, contohnya tabel `mahasiswa` dengan kolom id, nama, nim, jurusan.',
        'Buat file `koneksi.php` untuk koneksi ke MySQL: buat variabel host, user, password, dan nama database, lalu pakai `mysqli_connect` atau PDO.',
      ]},
      { h: '2. Halaman Create (Tambah Data)', p: [
        'Buat form HTML dengan input sesuai kolom tabel. Saat form di-submit, tangkap data dengan `$_POST`, lalu jalankan query INSERT.',
        'Jangan lupa validasi dasar: pastikan field nggak kosong sebelum insert. Ini nilai plus di mata dosen.',
      ]},
      { h: '3. Halaman Read (Tampilkan Data)', p: [
        'Pakai query SELECT untuk ambil semua data, lalu loop dengan `while` dan tampilkan dalam tabel HTML.',
        'Buat juga tombol Edit dan Hapus di tiap baris — ini yang bikin CRUD-mu keliatan lengkap.',
      ]},
      { h: '4. Halaman Update (Edit Data)', p: [
        'Halaman edit biasanya butuh ID dari data yang diklik. Ambil ID lewat URL (`$_GET`), tampilkan data lama di form, lalu UPDATE pas di-submit.',
        'Pastikan query UPDATE-nya pakai WHERE id, biar cuma data yang dipilih yang berubah.',
      ]},
      { h: '5. Halaman Delete (Hapus Data)', p: [
        'Cukup query DELETE dengan WHERE id. Tambahkan konfirmasi JavaScript (`confirm()`) biar nggak kehapus nggak sengaja.',
        'Selesai! Kamu udah punya CRUD lengkap yang siap dikumpulin.',
      ]},
      { h: 'Error Umum & Solusinya', p: [
        'Error paling sering: koneksi gagal (cek nama database & password), query salah (cek nama kolom), dan data nggak masuk (cek apakah form pakai method POST dan name-nya sesuai).',
        'Kalau masih mentok setelah coba semua ini, engineer JokiTugasIT.id bisa bantu review dan perbaiki CRUD-mu — gratis dicek dulu.',
      ]},
    ],
  },
  {
    slug: 'cara-debug-error-react-js-pemula',
    title: 'Cara Debug Error React JS untuk Pemula (Tanpa Panik)',
    date: '2026-09-02',
    excerpt: 'React error merah bikin panik? Tenang — ini cara membaca error React, memperbaikinya, dan tools yang bikin debugging jadi cepat.',
    keywords: ['debug react js', 'error react js pemula', 'cara fix error react'],
    readTime: 5,
    sections: [
      { h: 'Error React Bukan Akhir Dunia', p: [
        'Setiap developer React — termasuk yang udah bertahun-tahun — pernah lihat layar merah. Error itu sebenarnya petunjuk, bukan hukuman. Kamu cuma perlu tahu cara membacanya.',
      ]},
      { h: '1. Baca Error dari Atas', p: [
        'Error React biasanya punya 3 bagian: pesan utama (jelas, misal "Cannot read properties of undefined"), lokasi file & baris, dan stack trace.',
        'Mulai dari pesan utama dulu — 90% kasus, pesan itu sudah bilang apa masalahnya.',
      ]},
      { h: '2. Error Paling Umum: "Cannot read properties of undefined"', p: [
        'Ini artinya kamu akses properti dari data yang masih `undefined` atau `null`. Contoh: `user.name` padahal `user` belum diisi.',
        'Solusi: pastikan data sudah ada sebelum di-render. Pakai optional chaining (`user?.name`) atau kondisi `if (user)`.',
      ]},
      { h: '3. Error "Element type is invalid"', p: [
        'Biasanya karena import komponen yang salah — nama beda, atau lupa export default. Cek import & export komponen kamu.',
      ]},
      { h: '4. Pakai React DevTools', p: [
        'Install React DevTools di browser. Ini ngasih kamu panel Components & Profiler yang super membantu buat lihat state dan props tiap komponen secara live.',
        'Dengan DevTools, kamu bisa lihat data apa yang masuk ke komponen dan kenapa render-nya salah.',
      ]},
      { h: '5. Tips: Console.log Strategis', p: [
        'Jangan takut pakai `console.log()`. Log data yang masuk, log hasil fungsi, log state — ini cara tercepat nemuin titik error.',
        'Bandingkan apa yang kamu harapkan vs apa yang keluar di console. Bedanya itu sumber masalahnya.',
      ]},
      { h: 'Masih Mentok? Bantuan Siap', p: [
        'Kalau error React-mu makin rumit (state management, hooks, atau integrasi API) dan deadline mepet, engineer JokiTugasIT.id bisa bantu debug sampai beres.',
        'Kirim screenshot error + kode kamu, gratis dicek dulu.',
      ]},
    ],
  },
  {
    slug: 'contoh-program-java-tugas-kuliah',
    title: 'Contoh Program Java untuk Tugas Kuliah + Cara Menjalankannya',
    date: '2026-09-02',
    excerpt: 'Bingung mulai program Java buat tugas? Ini contoh program sederhana (input-output, percabangan, perulangan, array) lengkap dengan cara menjalankannya.',
    keywords: ['contoh program java', 'program java tugas kuliah', 'belajar java dasar'],
    readTime: 5,
    sections: [
      { h: 'Java Buat Tugas Kuliah: Mulai dari Mana?', p: [
        'Java sering jadi bahasa pertama di kampus — dan sering bikin pusing pertama kali. Padahal pola dasarnya simpel: input, proses, output.',
      ]},
      { h: '1. Struktur Dasar Program Java', p: [
        'Setiap program Java punya class utama dengan method `main`. File harus dinamai sama dengan nama class-nya.',
        'Contoh: class `HaloDunia` harus disimpan di file `HaloDunia.java`, lalu di-compile dengan `javac` dan dijalankan dengan `java`.',
      ]},
      { h: '2. Input & Output Dasar', p: [
        'Pakai `Scanner` untuk input dari keyboard dan `System.out.println()` untuk output. Ini dua hal paling dasar yang pasti dipakai di tugas.',
      ]},
      { h: '3. Percabangan (If-Else) & Perulangan (Loop)', p: [
        'If-else buat pengambilan keputusan (contoh: nilai >= 60 = lulus). For/while buat perulangan (contoh: tampilkan angka 1-100).',
        'Kombinasi keduanya udah bisa nyelesain mayoritas tugas Java semester awal.',
      ]},
      { h: '4. Array & Manipulasi Data', p: [
        'Array buat nyimpan banyak data sekaligus. Contoh tugas umum: cari nilai tertinggi, rata-rata, atau urutkan data.',
        'Coba pahami dulu cara akses index array — dari situ semua tugas data jadi lebih gampang.',
      ]},
      { h: '5. Cara Menjalankan di Eclipse / NetBeans / Terminal', p: [
        'Di IDE (Eclipse/NetBeans): buat project baru, tambah class, tulis kode, klik Run. Di terminal: `javac NamaFile.java` lalu `java NamaFile`.',
        'Error paling umum pemula: lupa titik koma, nama file beda sama class, atau salah import Scanner.',
      ]},
      { h: 'Butuh Bantuan Lebih?', p: [
        'Kalau tugas Java-mu lebih kompleks (OOP, GUI Swing, atau koneksi database) dan kamu mentok, JokiTugasIT.id bisa bantu — dari review kode, perbaiki error, sampai pendampingan.',
        'Ceritain aja masalahmu, gratis dicek dulu.',
      ]},
    ],
  },
]

export function getPost(slug) {
  return posts.find((p) => p.slug === slug)
}
