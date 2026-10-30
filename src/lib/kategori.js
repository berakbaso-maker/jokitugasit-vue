/**
 * Kategori layanan — TANPA nominal apa pun.
 *
 * File ini sengaja hanya berisi daftar kategori yang sah, dipakai untuk
 * memvalidasi query ?category= dari halaman layanan. Nominal harga tidak
 * pernah disimpan di frontend: harga selalu hasil kesepakatan lewat chat,
 * supaya tidak ada angka yang bocor ke Google atau tertinggal di cache.
 */
export const KATEGORI_VALID = [
  'debug',
  'tugas_kuliah',
  'skripsi',
  'web',
  'mobile',
  'desktop',
  'database',
  'ai',
  'design',
  'lainnya',
]

/** Tingkat kesulitan per kategori — dipakai untuk memberi gambaran usaha, bukan biaya. */
export const TINGKAT_KESULITAN = {
  debug: 'Ringan',
  tugas_kuliah: 'Ringan',
  design: 'Sedang',
  web: 'Sedang',
  mobile: 'Sedang',
  desktop: 'Sedang',
  database: 'Sedang',
  ai: 'Berat',
  skripsi: 'Berat',
  lainnya: 'Sedang',
}

/** Estimasi waktu pengerjaan per kategori — komitmen waktu, bukan komitmen uang. */
export const ESTIMASI_WAKTU = {
  debug: '± 1 hari',
  tugas_kuliah: '± 1 hari',
  design: '1 – 2 hari',
  web: '1 – 3 hari',
  mobile: '2 – 4 hari',
  desktop: '2 – 4 hari',
  database: '1 – 3 hari',
  ai: '3 – 7 hari',
  skripsi: '1 – 2 minggu',
  lainnya: '1 – 3 hari',
}

export function kesulitanKategori(kategori) {
  return TINGKAT_KESULITAN[kategori] || 'Sedang'
}

export function waktuKategori(kategori) {
  return ESTIMASI_WAKTU[kategori] || '1 – 3 hari'
}
