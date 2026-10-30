// src/lib/galat.js — penerjemah error ke bahasa manusia.
// Helper murni: JANGAN import @supabase/supabase-js di sini, supaya SDK tidak
// ikut ke chunk awal (lihat aturan bundle di skill jokitugasit-vue).
//
// Prinsip: user tidak boleh pernah melihat teks teknis ("Failed to fetch",
// PGRST202, "relation does not exist"). Detail asli tetap disimpan pemanggil
// untuk log dan untuk <details> di mode dev.

const PESAN_BISNIS = {
  NAMA_WAJIB: 'Nama wajib diisi.',
  WHATSAPP_WAJIB: 'Nomor WhatsApp wajib diisi.',
  DESKRIPSI_WAJIB: 'Ceritakan dulu masalah atau tugasmu.',
  KATEGORI_TIDAK_VALID: 'Kategori tugas tidak dikenali.',
  DEADLINE_TIDAK_VALID: 'Pilihan deadline tidak dikenali.',
  TANGGAL_WAJIB: 'Isi tanggal deadline karena kamu memilih fleksibel.',
  GAGAL_MEMBUAT_ORDER: 'Gagal membuat nomor order. Coba lagi sebentar lagi.',
  KODE_SUDAH_DIPAKAI: 'Kode itu sudah dipakai partner lain. Pakai kode berbeda.',
  KODE_TIDAK_VALID: 'Format kode belum benar. Contoh yang benar: REF-BUDI.',
  AKSES_DITOLAK: 'Akses ditolak. Hubungi engineer kalau ini tidak seharusnya terjadi.',
}

const PESAN_KODE = {
  PGRST301: 'Sesi kamu sudah berakhir. Silakan masuk lagi.',
  PGRST116: 'Data yang kamu cari tidak ditemukan.',
  '42501': 'Akses ditolak.',
  '23505': 'Data ini sudah ada.',
  '22023': 'Data yang dikirim tidak valid.',
  '429': 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
}

const POLA_JARINGAN =
  /failed to fetch|networkerror|load failed|fetch failed|err_network|network request failed|net::err/i

const POLA_TEKNIS =
  /PGRST|relation .* does not exist|column .* does not exist|violates|syntax error|TypeError|is not a function|duplicate key value/i

export const PESAN_KONEKSI =
  'Tidak bisa terhubung ke server. Periksa koneksi internetmu, lalu coba lagi.'

/** True kalau error berasal dari jaringan/DNS, bukan dari data user. */
export function adalahGalatJaringan(error) {
  if (!error) return false
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return true
  const pesan = String(error.message || error)
  return error instanceof TypeError || POLA_JARINGAN.test(pesan)
}

/** True kalau aksi yang sama masuk akal untuk dicoba ulang. */
export function bisaDiulang(error) {
  if (!error) return false
  if (adalahGalatJaringan(error)) return true
  if (error.name === 'AbortError') return true
  const status = Number(error.status || error.statusCode || 0)
  return status >= 500 || status === 429
}

/** Ubah error apa pun menjadi satu kalimat Indonesia yang bisa ditindaklanjuti. */
export function pesanGalat(error, fallback = 'Terjadi kesalahan. Coba lagi ya.') {
  if (!error) return fallback
  const mentah = String(error.message || error.error_description || error)

  for (const [kode, pesan] of Object.entries(PESAN_BISNIS)) {
    if (new RegExp('\\b' + kode + '\\b').test(mentah)) return pesan
  }
  if (adalahGalatJaringan(error)) return PESAN_KONEKSI
  if (error.name === 'AbortError') return 'Server terlalu lama menjawab. Coba lagi.'
  if (error.code && PESAN_KODE[error.code]) return PESAN_KODE[error.code]
  if (error.status && PESAN_KODE[String(error.status)]) return PESAN_KODE[String(error.status)]
  if (mentah && !POLA_TEKNIS.test(mentah)) return mentah
  return fallback
}

/** Detail teknis untuk log / <details> dev. Jangan dirender di produksi. */
export function detailGalat(error) {
  if (!error) return ''
  const bagian = [
    error.name,
    error.code ? 'code=' + error.code : '',
    error.status ? 'status=' + error.status : '',
    error.message || String(error),
  ].filter(Boolean)
  return bagian.join(' · ')
}

/**
 * Diagnostik: apakah backend Supabase terjangkau?
 * Dipakai untuk membedakan "server mati" dari "order tidak ada".
 * Tidak dipanggil otomatis pada setiap render.
 */
export async function cekKoneksi(timeoutMs = 4000) {
  const base = String(import.meta.env.VITE_SUPABASE_URL || '').replace(/\/$/, '')
  if (!base) return { ok: false, alasan: 'konfigurasi' }
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  try {
    const res = await fetch(base + '/auth/v1/health', { signal: ctrl.signal })
    return { ok: res.ok, status: res.status }
  } catch {
    return { ok: false, alasan: 'jaringan' }
  } finally {
    clearTimeout(timer)
  }
}
