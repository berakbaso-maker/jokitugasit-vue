/**
 * Sumber tunggal rumus estimasi biaya.
 *
 * Dipakai dua tempat:
 *  - PriceEstimator.vue (/harga)  → kalkulator lengkap
 *  - RequestSubmitView.vue (/request) → estimasi ringkas di dalam form
 *
 * PENTING: angka di sini hanya ESTIMASI untuk membantu user, bukan
 * harga final. Harga yang mengikat tetap ditetapkan server/engineer.
 */

export const SERVICE_TYPES = [
  {
    id: 'quick_fix',
    name: 'Quick Fix / Debug Error',
    badge: 'Tercepat',
    desc: 'Benerin bug error spesifik, runtime exception, query macet, atau kode mentok ChatGPT.',
    baseMin: 150000,
    baseMax: 300000,
    eta: '1 – 3 Jam',
    icon: 'bug_report',
  },
  {
    id: 'feature',
    name: 'Feature Sprint / CRUD / API',
    badge: 'Populer',
    desc: 'Pembuatan modul fitur baru, integrasi database relasional, payment gateway, atau REST API.',
    baseMin: 500000,
    baseMax: 1200000,
    eta: '1 – 3 Hari',
    icon: 'code',
  },
  {
    id: 'capstone',
    name: 'Skripsi / Capstone / Full App',
    badge: 'Lengkap',
    desc: 'Pendampingan pembuatan aplikasi utuh web/mobile, sistem cerdas AI/ML, sampai siap demo dosen.',
    baseMin: 1500000,
    baseMax: 3500000,
    eta: '1 – 2 Minggu',
    icon: 'school',
  },
]

export const TECH_STACKS = [
  { id: 'web', name: 'Web (Laravel / React / Vue / PHP)', multiplier: 1.0 },
  { id: 'mobile', name: 'Mobile (Flutter / React Native)', multiplier: 1.15 },
  { id: 'ai', name: 'Python (AI / Machine Learning / Data)', multiplier: 1.2 },
  { id: 'backend', name: 'Backend API & Database (Node / Go / SQL)', multiplier: 1.05 },
  { id: 'desktop', name: 'Desktop (Java / C++ / Python)', multiplier: 1.0 },
]

export const URGENCIES = [
  { id: 'santai', name: 'Santai (> 1 Minggu)', multiplier: 0.95, sub: 'Diskon santai' },
  { id: 'normal', name: 'Normal (3 – 5 Hari)', multiplier: 1.0, sub: 'Jadwal reguler' },
  { id: 'mendesak', name: 'Mendesak (Hari Ini / < 48 Jam)', multiplier: 1.25, sub: 'Prioritas utama' },
]

export const ADDONS = [
  {
    id: 'video_walkthrough',
    name: 'Video Walkthrough Kode',
    price: 50000,
    desc: 'Rekaman video penjelasan logika fungsi agar kamu paham saat ditanya dosen.',
    icon: 'smart_display',
  },
  {
    id: 'demo_cheatsheet',
    name: 'Cheatsheet Sidang / Tanya Dosen',
    price: 100000,
    desc: 'Catatan ringkas konsep teknis & prediksi pertanyaan dosen penguji saat demo.',
    icon: 'description',
  },
  {
    id: 'meet_setup',
    name: '1-on-1 Setup via Google Meet',
    price: 75000,
    desc: 'Panduan langsung setup database & run localhost di laptopmu sampai jalan.',
    icon: 'video_camera_front',
  },
]

/** Pembulatan ke atas per 10rb: estimasi tidak boleh tampak lebih murah dari hitungan asli. */
function roundTo10k(value) {
  return Math.ceil(value / 10000) * 10000
}

export function formatRupiah(num) {
  return 'Rp ' + Number(num).toLocaleString('id-ID')
}

/**
 * Hitung estimasi.
 * @param {{serviceId?: string, stackId?: string, urgencyId?: string, addonIds?: string[]}} opts
 */
export function hitungEstimasi({ serviceId = 'feature', stackId = 'web', urgencyId = 'normal', addonIds = [] } = {}) {
  const service = SERVICE_TYPES.find((s) => s.id === serviceId) || SERVICE_TYPES[1]
  const stack = TECH_STACKS.find((t) => t.id === stackId) || TECH_STACKS[0]
  const urgency = URGENCIES.find((u) => u.id === urgencyId) || URGENCIES[1]

  const addonTotal = addonIds.reduce((sum, id) => {
    const item = ADDONS.find((a) => a.id === id)
    return sum + (item ? item.price : 0)
  }, 0)

  const faktor = stack.multiplier * urgency.multiplier
  const min = roundTo10k(service.baseMin * faktor + addonTotal)

  return {
    min,
    max: roundTo10k(service.baseMax * faktor + addonTotal),
    // DP = 50% dari batas bawah yang sudah dibulatkan, supaya konsisten dengan angka yang tampil.
    dp: roundTo10k(min / 2),
    service,
    stack,
    urgency,
    addonTotal,
  }
}

/** Petakan kategori form order → tier layanan. */
export const KATEGORI_KE_LAYANAN = {
  debug: 'quick_fix',
  tugas_kuliah: 'quick_fix',
  skripsi: 'capstone',
  web: 'feature',
  mobile: 'feature',
  desktop: 'feature',
  database: 'feature',
  ai: 'feature',
  design: 'feature',
  lainnya: 'feature',
}

/** Petakan kategori → tech stack (untuk multiplier). */
export const KATEGORI_KE_STACK = {
  mobile: 'mobile',
  ai: 'ai',
  database: 'backend',
  desktop: 'desktop',
}

/** Petakan deadline form → urgensi. */
export const DEADLINE_KE_URGENSI = {
  hari_ini: 'mendesak',
  besok: 'normal',
  fleksibel: 'santai',
}

/** Kategori valid — untuk memvalidasi query ?category= dari luar. */
export const KATEGORI_VALID = Object.keys(KATEGORI_KE_LAYANAN)

export function estimasiDariForm({ category, deadline, addonIds = [] }) {
  return hitungEstimasi({
    serviceId: KATEGORI_KE_LAYANAN[category] || 'feature',
    stackId: KATEGORI_KE_STACK[category] || 'web',
    urgencyId: DEADLINE_KE_URGENSI[deadline] || 'normal',
    addonIds,
  })
}
