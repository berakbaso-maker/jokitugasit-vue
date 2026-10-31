<script setup>
import { ref, watch } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import {
  createRequest, uploadAttachment, validateReferralCode, resolveCampaign,
  CATEGORY_LABELS, DEADLINE_LABELS,
} from '../lib/api'
import { KATEGORI_VALID } from '../lib/kategori'
import { bisaDiulang, detailGalat, pesanGalat } from '../lib/galat'
import KotakGalat from '../components/KotakGalat.vue'

const router = useRouter()
const route = useRoute()

function queryString(value) {
  if (Array.isArray(value)) return String(value[0] || '').trim()
  return typeof value === 'string' ? value.trim() : ''
}

// Atribusi campaign/UTM dibaca sekali saat halaman dibuka (first touch).
const attribution = {
  campaign_code: queryString(route.query.campaign),
  utm_source: queryString(route.query.utm_source),
  utm_medium: queryString(route.query.utm_medium),
  utm_campaign: queryString(route.query.utm_campaign),
  utm_content: queryString(route.query.utm_content),
  utm_term: queryString(route.query.utm_term),
}
const campaignName = ref('')
const campaignError = ref(false)

if (attribution.campaign_code) {
  resolveCampaign(attribution.campaign_code)
    .then((c) => { campaignName.value = c?.name || ''; campaignError.value = !c })
    .catch(() => { campaignError.value = true })
}

const categories = [
  { label: 'Website / Web App', value: 'web' },
  { label: 'Aplikasi Mobile', value: 'mobile' },
  { label: 'Aplikasi Desktop', value: 'desktop' },
  { label: 'Database', value: 'database' },
  { label: 'AI / Machine Learning', value: 'ai' },
  { label: 'Debug / Benerin Error', value: 'debug' },
  { label: 'Skripsi / Tugas Akhir', value: 'skripsi' },
  { label: 'Tugas Kuliah Dasar', value: 'tugas_kuliah' },
  { label: 'Desain UI/UX', value: 'design' },
  { label: 'Lainnya', value: 'lainnya' },
]

const deadlines = [
  { label: 'Hari Ini', sub: '(Mendesak)', icon: 'local_fire_department', value: 'hari_ini', fill: true },
  { label: 'Besok', sub: '(Normal)', icon: 'event', value: 'besok', fill: true },
  { label: 'Pilih Tanggal', sub: '(Fleksibel)', icon: 'calendar_month', value: 'fleksibel', fill: false },
]

// Kalkulator di /harga mengirim ?category=... ke halaman ini. Sebelumnya
// parameter itu diabaikan sehingga pilihan user hilang dan form balik ke 'web'.
const kategoriAwal = (() => {
  const dariQuery = queryString(route.query.category)
  return KATEGORI_VALID.includes(dariQuery) ? dariQuery : 'web'
})()

const DEADLINE_VALID = ['hari_ini', 'besok', 'fleksibel']
const deadlineAwal = (() => {
  const dariQuery = queryString(route.query.deadline)
  return DEADLINE_VALID.includes(dariQuery) ? dariQuery : 'besok'
})()

const form = ref({
  customer_name: '',
  email: '',
  whatsapp: '',
  category: kategoriAwal,
  description: '',
  deadline: deadlineAwal,
  deadline_date: '',
  link: '',
  referral_code: queryString(route.query.ref),
})

const file = ref(null)

const fileLabel = ref('ZIP, PNG, JPG maksimal 10MB')
const submitting = ref(false)
const errorMsg = ref('')
const errorDetail = ref('')
const errorBisaUlang = ref(false)

// Referral code validation
const referralStatus = ref('') // '' | 'checking' | 'valid' | 'invalid'
const referralPartnerName = ref('')
let referralDebounce = null

watch(() => form.value.referral_code, (val) => {
  clearTimeout(referralDebounce)
  const code = (val || '').trim().toUpperCase()
  if (!code || code.length < 5) {
    referralStatus.value = ''
    referralPartnerName.value = ''
    return
  }
  referralStatus.value = 'checking'
  referralDebounce = setTimeout(async () => {
    try {
      const partner = await validateReferralCode(code)
      if (partner) {
        referralStatus.value = 'valid'
        referralPartnerName.value = partner.display_name
      } else {
        referralStatus.value = 'invalid'
        referralPartnerName.value = ''
      }
    } catch (err) {
      console.error(err)
      referralStatus.value = ''
      referralPartnerName.value = ''
    }
  }, 600)
})

// Auto-clean WhatsApp number input (hilangkan awalan 0 atau 62 agar sinkron dengan +62)
watch(() => form.value.whatsapp, (val) => {
  if (!val) return
  let cleaned = String(val).replace(/[^0-9]/g, '')
  if (cleaned.startsWith('62')) {
    cleaned = cleaned.slice(2)
  }
  if (cleaned.startsWith('0')) {
    cleaned = cleaned.replace(/^0+/, '')
  }
  if (cleaned !== val) {
    form.value.whatsapp = cleaned
  }
})

function onFileChange(e) {
  const selected = e.target.files?.[0]
  file.value = selected || null
  fileLabel.value = selected ? selected.name : 'ZIP, PNG, JPG maksimal 10MB'
}

async function handleSubmit() {
  errorMsg.value = ''
  if (!form.value.customer_name.trim()) {
    errorMsg.value = 'Nama wajib diisi.'
    return
  }
  if (!form.value.whatsapp.trim()) {
    errorMsg.value = 'Nomor WhatsApp aktif wajib diisi.'
    return
  }
  if (!form.value.description.trim()) {
    errorMsg.value = 'Mohon jelaskan masalahnya.'
    return
  }
  if (form.value.deadline === 'fleksibel' && !form.value.deadline_date) {
    errorMsg.value = 'Pilih tanggal deadline untuk request fleksibel.'
    return
  }

  submitting.value = true
  try {
    let fileUrl = null
    if (file.value) {
      fileUrl = await uploadAttachment(file.value)
    }

    const cleanWa = '62' + form.value.whatsapp.replace(/^0+/, '')
    // Nomor order, status, dan harga dibuat server-side (RPC).
    const created = await createRequest({
      customer_name: form.value.customer_name.trim(),
      email: form.value.email.trim() || null,
      whatsapp: cleanWa,
      category: form.value.category,
      description: form.value.description.trim(),
      deadline: form.value.deadline,
      deadline_date: form.value.deadline === 'fleksibel' ? form.value.deadline_date : null,
      link: form.value.link.trim() || null,
      file_url: fileUrl,
      referral_code: referralStatus.value === 'valid' ? form.value.referral_code.trim().toUpperCase() : null,
      campaign_code: attribution.campaign_code || null,
      utm_source: attribution.utm_source || null,
      utm_medium: attribution.utm_medium || null,
      utm_campaign: attribution.utm_campaign || null,
      utm_content: attribution.utm_content || null,
      utm_term: attribution.utm_term || null,
    })

    // Kirim notifikasi instan ke Telegram Engineer via Vercel Serverless Function (non-blocking)
    try {
      // Server hanya butuh orderNo: isi pesan diambil dari database.
      fetch('/api/notify-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderNo: created.order_no }),
      }).catch((err) => console.warn('Telegram notification trigger warning:', err))
    } catch (notifyErr) {
      console.warn('Telegram notification error:', notifyErr)
    }

    // Kirim email booking (opsional) — tidak menggagalkan alur jika gagal
    if (form.value.email.trim()) {
      try {
        // Server hanya butuh orderNo: alamat & isi email diambil dari database.
        await fetch('/api/send-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ orderNo: created.order_no }),
        })
      } catch (err) {
        console.error('Email booking gagal:', err)
      }
    }

    router.push({ name: 'request-success', params: { orderNo: created.order_no } })
  } catch (err) {
    console.error(err)
    errorMsg.value = pesanGalat(err, 'Gagal mengirim request. Coba lagi.')
    errorDetail.value = detailGalat(err)
    errorBisaUlang.value = bisaDiulang(err)
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="bg-background text-on-background font-body-md flex flex-col min-h-screen antialiased">
    <TopAppBar />

    <!-- Mobile Header Bar (Sticky Top khusus tampilan mobile) -->
    <header class="md:hidden sticky top-0 z-40 bg-surface-white/95 backdrop-blur-md border-b border-border-subtle px-4 py-3 flex items-center justify-between">
      <RouterLink to="/" class="flex items-center gap-1.5 text-secondary hover:text-on-surface text-sm font-label-bold transition-colors">
        <span class="material-symbols-outlined text-[20px]">arrow_back</span>
        <span>Kembali</span>
      </RouterLink>
      <div class="flex items-center gap-1.5">
        <span class="material-symbols-outlined text-electric-blue text-[20px]" style="font-variation-settings: 'FILL' 1">terminal</span>
        <span class="font-extrabold text-sm text-primary tracking-tight">jokitugasit</span>
      </div>
      <div class="flex items-center gap-1 bg-surface-container-high px-2 py-1 rounded-full text-[11px] text-secondary font-medium">
        <span class="w-1.5 h-1.5 rounded-full bg-success-green animate-pulse"></span>
        <span>Online</span>
      </div>
    </header>

    <main id="konten-utama" tabindex="-1" class="flex-grow flex flex-col items-center justify-start pt-4 sm:pt-8 pb-32 sm:pb-section-gap-mobile md:pb-section-gap-desktop px-gutter w-full">
      <div class="w-full max-w-2xl">
        <div class="text-center mb-6 sm:mb-8">
          <h1 class="font-display-hero-mobile md:font-display-hero text-2xl sm:text-display-hero-mobile md:text-display-hero text-on-background mb-2">Ceritain Aja Masalahmu</h1>
          <p class="font-body-md sm:font-body-lg text-sm sm:text-body-lg text-secondary">Gak perlu daftar, gak perlu ribet. Langsung ke engineer.</p>
          <div class="inline-flex items-center gap-2 mt-3 bg-surface-white px-3 py-1.5 rounded-full shadow-sm border border-border-subtle">
            <span class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse"></span>
            <span class="font-label-sm text-label-sm text-on-surface-variant">Engineer siap bantu</span>
          </div>
        </div>

        <div v-if="campaignName" class="mb-4 flex items-center gap-2 rounded-xl bg-primary-fixed/30 border border-electric-blue/20 px-4 py-2.5 text-xs text-on-surface">
          <span class="material-symbols-outlined text-[16px] text-electric-blue">campaign</span>
          <span>Kamu datang dari kampanye <strong>{{ campaignName }}</strong> — terima kasih!</span>
        </div>
        <div v-else-if="campaignError" class="mb-4 rounded-xl bg-surface-container-low border border-border-subtle px-4 py-2.5 text-xs text-secondary">
          Kode kampanye tidak dikenali; form tetap bisa dikirim.
        </div>

        <div class="bg-surface-white rounded-2xl shadow-[0px_4px_20px_rgb(var(--shadow-color) / 0.08)] p-4 sm:p-6 md:p-8 border border-border-subtle/60">
          <form class="space-y-5 sm:space-y-6" @submit.prevent="handleSubmit">
            <!-- Name -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="customer_name">Nama kamu</label>
              <input
                id="customer_name"
                v-model="form.customer_name"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-base focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                placeholder="Contoh: Budi Santoso"
                type="text"
                required
              />
            </div>

            <!-- Email (opsional) -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="email">Email (opsional)</label>
              <input
                id="email"
                v-model="form.email"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-base focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                placeholder="biar dapat kode booking di email"
                type="email"
              />
              <p class="text-xs text-secondary mt-1.5">Kosongkan kalau nggak mau dapat email. Kode booking tetap muncul di layar.</p>
            </div>

            <!-- 1. Upload Field -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2">Upload File atau Link Project</label>
              <label class="mt-1 flex justify-center px-4 py-4 sm:px-6 sm:py-5 border-2 border-border-subtle border-dashed rounded-xl hover:border-electric-blue transition-colors bg-surface-container-lowest cursor-pointer group">
                <div class="space-y-1 text-center">
                  <span class="material-symbols-outlined text-muted group-hover:text-electric-blue text-3xl sm:text-4xl mb-1">cloud_upload</span>
                  <div class="flex text-sm text-on-surface-variant justify-center items-center">
                    <span class="relative rounded-md font-semibold text-electric-blue group-hover:text-primary">
                      <span>{{ file ? 'Ganti file terpilih' : 'Pilih file tugas' }}</span>
                      <input class="sr-only" id="file-upload" name="file-upload" type="file" accept=".zip,.png,.jpg,.jpeg,.pdf" @change="onFileChange" />
                    </span>
                    <span class="hidden sm:inline pl-1 text-secondary">atau seret file ke sini</span>
                  </div>
                  <p class="text-xs text-muted truncate max-w-[240px] sm:max-w-md mx-auto">{{ fileLabel }}</p>
                </div>
              </label>
              <div class="mt-2.5">
                <input
                  v-model="form.link"
                  class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-base focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                  placeholder="Atau tempel link repo / Google Drive / Figma..."
                  type="url" aria-label="Tautan referensi atau lampiran (opsional)"
                />
              </div>
            </div>

            <!-- 2. Category Selector -->
            <div>
              <div class="flex items-center justify-between mb-2">
                <label class="block font-label-bold text-label-bold text-on-background">Jenis Tugas</label>
                <span class="text-[11px] text-secondary">Pilih satu</span>
              </div>
              <div class="flex flex-wrap gap-2">
                <label v-for="c in categories" :key="c.value" class="cursor-pointer">
                  <input v-model="form.category" class="peer sr-only" name="category" type="radio" :value="c.value" />
                  <div
                    class="px-3.5 py-2 rounded-full border border-border-subtle bg-surface-white text-secondary font-label-sm text-label-sm peer-checked:bg-primary-container peer-checked:text-on-primary-container peer-checked:border-primary-container transition-all hover:border-electric-blue active:scale-95 text-center min-h-[38px] flex items-center justify-center select-none"
                  >
                    {{ c.label }}
                  </div>
                </label>
              </div>
            </div>

            <!-- 3. Description -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="description">Ceritakan yang bikin mentok</label>
              <textarea
                id="description"
                v-model="form.description"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-base focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant resize-none"
                placeholder="Jelaskan error, fitur yang ingin dibuat, atau instruksi tugas dari dosen..."
                rows="4"
                required
              ></textarea>
            </div>

            <!-- 4. Deadline Selector -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2">Deadline</label>
              <div class="grid grid-cols-3 gap-2 sm:gap-3">
                <label v-for="d in deadlines" :key="d.value" class="cursor-pointer relative">
                  <input v-model="form.deadline" class="peer sr-only" name="deadline" type="radio" :value="d.value" />
                  <div class="h-full min-h-[88px] flex flex-col justify-between items-center text-center p-2 sm:p-3 rounded-xl border border-border-subtle bg-surface-white text-secondary peer-checked:bg-primary-fixed peer-checked:text-on-primary-fixed peer-checked:border-electric-blue transition-all">
                    <span class="material-symbols-outlined text-2xl mb-1" :style="{ fontVariationSettings: d.fill ? `'FILL' 1` : `'FILL' 0` }">{{ d.icon }}</span>
                    <div class="flex flex-col items-center justify-center">
                      <span class="font-label-bold text-xs sm:text-sm leading-tight">{{ d.label }}</span>
                      <span class="text-[10px] sm:text-xs opacity-75 mt-0.5">{{ d.sub }}</span>
                    </div>
                  </div>
                </label>
              </div>
              <div v-if="form.deadline === 'fleksibel'" class="mt-4 rounded-xl border border-electric-blue/30 bg-primary-fixed/40 p-3 sm:p-4">
                <label class="block font-label-bold text-label-bold text-on-background mb-2" for="deadline_date">Pilih tanggal deadline</label>
                <input
                  id="deadline_date"
                  v-model="form.deadline_date"
                  type="date"
                  :min="new Date().toISOString().slice(0, 10)"
                  required
                  class="w-full rounded-lg border border-border-subtle bg-surface-white px-4 py-3 text-base text-on-surface focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none"
                />
                <p class="text-xs text-secondary mt-2">Tanggal ini membantu engineer menentukan prioritas pengerjaan.</p>
              </div>
            </div>

            <!-- 5. WhatsApp Number -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="whatsapp">Nomor WhatsApp aktif</label>
              <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-3.5 text-on-surface-variant font-medium text-base select-none">+62</span>
                <input
                  id="whatsapp"
                  v-model="form.whatsapp"
                  class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest pl-14 pr-4 py-3 text-base focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                  placeholder="81234567890"
                  type="tel"
                  inputmode="numeric"
                  required
                />
              </div>
              <p class="text-xs text-secondary mt-1.5">Engineer akan langsung menghubungi via WhatsApp untuk estimasi & deal.</p>
            </div>

            <!-- Referral Code (Opsional) -->
            <div class="border-t border-border-subtle pt-5">
              <label class="block font-label-bold text-label-bold text-on-background mb-1" for="referral_code">
                Kode Referral
                <span class="ml-1 font-normal text-on-surface-variant text-[11px]">(opsional — dari teman yang mereferensikan)</span>
              </label>
              <div class="relative">
                <input
                  id="referral_code"
                  v-model="form.referral_code"
                  class="w-full rounded-xl border bg-surface-container-lowest px-4 py-3 text-base outline-none transition-all placeholder:text-outline-variant font-mono uppercase tracking-widest"
                  :class="{
                    'border-border-subtle focus:border-electric-blue focus:ring-1 focus:ring-electric-blue': referralStatus === '' || referralStatus === 'checking',
                    'border-success-green ring-1 ring-success-green/40': referralStatus === 'valid',
                    'border-urgency-red ring-1 ring-urgency-red/40': referralStatus === 'invalid',
                  }"
                  placeholder="REF-XXXXX"
                  type="text"
                  maxlength="12"
                />
                <span v-if="referralStatus === 'checking'" class="absolute right-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant animate-spin text-[20px]">progress_activity</span>
                <span v-else-if="referralStatus === 'valid'" class="absolute right-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-success-green text-[20px]" style="font-variation-settings: 'FILL' 1">check_circle</span>
                <span v-else-if="referralStatus === 'invalid'" class="absolute right-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-urgency-red text-[20px]" style="font-variation-settings: 'FILL' 1">cancel</span>
              </div>
              <p v-if="referralStatus === 'valid'" class="text-xs text-success-green mt-1.5 flex items-center gap-1">
                <span class="material-symbols-outlined text-[14px]" style="font-variation-settings: 'FILL' 1">check_circle</span>
                Kode valid! Direferensikan oleh <strong>{{ referralPartnerName }}</strong>
              </p>
              <p v-else-if="referralStatus === 'invalid'" class="text-xs text-urgency-red mt-1.5">Kode tidak ditemukan. Periksa kembali.</p>
            </div>

            <!-- Penegasan: tidak ada angka di muka -->
            <div class="rounded-xl border border-electric-blue/30 bg-electric-blue/5 px-4 py-3.5">
              <div class="flex items-start gap-3">
                <span class="material-symbols-outlined text-electric-blue text-[20px] mt-0.5" aria-hidden="true">handshake</span>
                <div class="flex-1 min-w-0">
                  <p class="text-[11px] font-semibold uppercase tracking-wide text-on-surface-variant">Soal biaya</p>
                  <p class="mt-1 text-sm font-semibold text-on-background leading-snug">
                    Nggak ada biaya di awal, nggak ada tagihan kejutan.
                  </p>
                  <p class="mt-1 text-xs text-secondary leading-relaxed">
                    Engineer akan cek dulu kode dan kebutuhanmu, lalu kasih tahu nominalnya lewat WhatsApp.
                    Kamu bebas setuju atau nggak — konsultasi tetap gratis.
                  </p>
                  <RouterLink
                    to="/harga"
                    class="mt-2 inline-flex items-center gap-1 text-xs font-semibold text-electric-blue hover:underline"
                  >
                    Lihat cara kami menentukan harga
                    <span class="material-symbols-outlined text-[14px]" aria-hidden="true">arrow_forward</span>
                  </RouterLink>
                </div>
              </div>
            </div>

            <!-- Error -->
            <KotakGalat
              v-if="errorMsg"
              :pesan="errorMsg"
              :detail="errorDetail"
              :bisa-ulang="errorBisaUlang"
              aksi-label="Kirim ulang"
              @coba-lagi="handleSubmit"
            />

            <!-- Trust Badges (dekat CTA) -->
            <div class="flex justify-center items-center gap-4 pt-1">
              <div class="flex items-center gap-1 text-on-surface-variant">
                <span class="material-symbols-outlined text-[16px]">lock</span>
                <span class="text-[11px] font-medium">100% Privasi</span>
              </div>
              <div class="w-1 h-1 rounded-full bg-border-subtle"></div>
              <div class="flex items-center gap-1 text-on-surface-variant">
                <span class="material-symbols-outlined text-[16px]">person_off</span>
                <span class="text-[11px] font-medium">Tanpa Daftar</span>
              </div>
            </div>

            <!-- Apa yang terjadi setelah kirim: menutup keraguan di titik keputusan -->
            <div class="rounded-xl border border-border-subtle bg-surface-container-low p-4">
              <p class="flex items-center gap-1.5 text-xs font-bold text-on-surface">
                <span class="material-symbols-outlined text-[16px] text-primary">schedule</span>
                Setelah kamu kirim, ini yang terjadi
              </p>
              <ol class="mt-3 space-y-2 text-[12px] leading-relaxed text-secondary">
                <li class="flex gap-2">
                  <span class="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary-fixed/60 text-[10px] font-bold text-primary">1</span>
                  <span>Kami balas di WhatsApp pada jam kerja (08.00–22.00 WIB) untuk klarifikasi singkat.</span>
                </li>
                <li class="flex gap-2">
                  <span class="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary-fixed/60 text-[10px] font-bold text-primary">2</span>
                  <span>Nilai dan waktu pengerjaan disepakati dulu. Tidak ada biaya sebelum kamu setuju.</span>
                </li>
                <li class="flex gap-2">
                  <span class="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-primary-fixed/60 text-[10px] font-bold text-primary">3</span>
                  <span>Nomor order terbit, progres bisa kamu pantau sendiri dan dikabari lewat email.</span>
                </li>
              </ol>
            </div>

            <!-- CTA -->
            <div class="pt-1">
              <button
                class="w-full bg-accent-fill text-on-primary font-label-bold text-label-bold py-4 rounded-xl flex items-center justify-center gap-2 hover:opacity-90 active:scale-95 transition-all shadow-md min-h-[48px] disabled:opacity-60 disabled:active:scale-100"
                type="submit"
                :disabled="submitting"
              >
                <span v-if="submitting" class="material-symbols-outlined animate-spin">progress_activity</span>
                <span v-else class="material-symbols-outlined">send</span>
                {{ submitting ? 'Mengirim...' : 'Kirim & Konsultasi Gratis' }}
              </button>
              <p class="mt-2.5 text-center text-[11px] leading-relaxed text-secondary">
                Gratis · tidak wajib lanjut · dibalas pada jam kerja
              </p>
            </div>

          </form>
        </div>
      </div>
    </main>

    <FooterBar />
    <BottomNavBar />
  </div>
</template>