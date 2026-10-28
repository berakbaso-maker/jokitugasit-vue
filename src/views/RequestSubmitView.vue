<script setup>
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { createRequest, uploadAttachment, getPartnerByCode, CATEGORY_LABELS, DEADLINE_LABELS } from '../lib/api'

const router = useRouter()

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
  { label: 'Bisa Pilih Tanggal', sub: '(Sesuka Kamu)', icon: 'calendar_month', value: 'fleksibel', fill: false },
]

const form = ref({
  customer_name: '',
  email: '',
  whatsapp: '',
  category: 'web',
  description: '',
  deadline: 'besok',
  deadline_date: '',
  link: '',
  referral_code: '',
})

const file = ref(null)
const fileLabel = ref('ZIP, PNG, JPG maksimal 10MB')
const submitting = ref(false)
const errorMsg = ref('')

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
    const partner = await getPartnerByCode(code)
    if (partner) {
      referralStatus.value = 'valid'
      referralPartnerName.value = partner.full_name
    } else {
      referralStatus.value = 'invalid'
      referralPartnerName.value = ''
    }
  }, 600)
})

function onFileChange(e) {
  const selected = e.target.files?.[0]
  file.value = selected || null
  fileLabel.value = selected ? selected.name : 'ZIP, PNG, JPG maksimal 10MB'
}

function generateOrderNo() {
  return 'JT' + String(Math.floor(1000 + Math.random() * 9000))
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

    const orderNo = generateOrderNo()
    const payload = {
      order_no: orderNo,
      customer_name: form.value.customer_name.trim(),
      email: form.value.email.trim() || null,
      whatsapp: form.value.whatsapp.trim(),
      category: form.value.category,
      description: form.value.description.trim(),
      deadline: form.value.deadline,
      deadline_date: form.value.deadline === 'fleksibel' ? form.value.deadline_date : null,
      link: form.value.link.trim() || null,
      file_url: fileUrl,
      referral_code: referralStatus.value === 'valid' ? form.value.referral_code.trim().toUpperCase() : null,
      status: 'new',
    }
    const created = await createRequest(payload)

    // Kirim notifikasi instan ke Telegram Engineer via Vercel Serverless Function (non-blocking)
    try {
      fetch('/api/notify-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          orderNo: created.order_no,
          customerName: form.value.customer_name.trim(),
          whatsapp: form.value.whatsapp.trim(),
          category: form.value.category,
          deadline: form.value.deadline,
          deadlineDate: form.value.deadline === 'fleksibel' ? form.value.deadline_date : null,
          description: form.value.description.trim(),
          link: form.value.link.trim() || null,
          fileUrl: fileUrl,
        }),
      }).catch((err) => console.warn('Telegram notification trigger warning:', err))
    } catch (notifyErr) {
      console.warn('Telegram notification error:', notifyErr)
    }

    // Kirim email booking (opsional) — tidak menggagalkan alur jika gagal
    if (form.value.email.trim()) {
      try {
        await fetch('/api/send-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: form.value.email.trim(),
            orderNo: created.order_no,
            customerName: form.value.customer_name.trim(),
            category: CATEGORY_LABELS[form.value.category] || form.value.category,
            deadline: DEADLINE_LABELS[form.value.deadline] || form.value.deadline,
            description: form.value.description.trim(),
            quoteAmount: null,
          }),
        })
      } catch (err) {
        console.error('Email booking gagal:', err)
      }
    }

    router.push({ name: 'request-success', params: { orderNo: created.order_no } })
  } catch (err) {
    console.error(err)
    errorMsg.value = err.message || 'Gagal mengirim request. Coba lagi.'
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div class="bg-background text-on-background font-body-md flex flex-col min-h-screen antialiased">
    <TopAppBar />

    <main class="flex-grow flex flex-col items-center justify-start pt-8 pb-section-gap-mobile md:pb-section-gap-desktop px-4 sm:px-gutter w-full">
      <div class="w-full max-w-2xl">
        <div class="text-center mb-8">
          <h1 class="font-display-hero-mobile md:font-display-hero text-display-hero-mobile md:text-display-hero text-on-background mb-2">Ceritain Aja Masalahmu</h1>
          <p class="font-body-lg text-body-lg text-secondary">Gak perlu daftar, gak perlu ribet. Langsung ke engineer.</p>
          <div class="inline-flex items-center gap-2 mt-4 bg-surface-white px-3 py-1.5 rounded-full shadow-sm border border-border-subtle">
            <span class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse"></span>
            <span class="font-label-sm text-label-sm text-on-surface-variant">Engineer siap bantu</span>
          </div>
        </div>

        <div class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6 md:p-8">
          <form class="space-y-6" @submit.prevent="handleSubmit">
            <!-- Name -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="customer_name">Nama kamu</label>
              <input
                id="customer_name"
                v-model="form.customer_name"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                placeholder="Contoh: Budi Santoso"
                type="text"
              />
            </div>

            <!-- Email (opsional) -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="email">Email (opsional)</label>
              <input
                id="email"
                v-model="form.email"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                placeholder="biar dapat kode booking di email"
                type="email"
              />
              <p class="text-xs text-secondary mt-1.5">Kosongkan kalau nggak mau dapat email. Kode booking tetap muncul di layar.</p>
            </div>

            <!-- 1. Upload Field -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2">Upload File (Screenshot/ZIP) atau Link</label>
              <label class="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-border-subtle border-dashed rounded-xl hover:border-electric-blue transition-colors bg-surface-container-lowest cursor-pointer group">
                <div class="space-y-1 text-center">
                  <span class="material-symbols-outlined text-outline group-hover:text-electric-blue text-4xl mb-2">cloud_upload</span>
                  <div class="flex text-sm text-on-surface-variant justify-center">
                    <span class="relative cursor-pointer rounded-md font-medium text-electric-blue hover:text-primary focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-electric-blue">
                      <span>{{ file ? 'Pilih file lain' : 'Pilih file' }}</span>
                      <input class="sr-only" id="file-upload" name="file-upload" type="file" accept=".zip,.png,.jpg,.jpeg,.pdf" @change="onFileChange" />
                    </span>
                    <p class="pl-1">atau seret file ke sini</p>
                  </div>
                  <p class="text-xs text-outline">{{ fileLabel }}</p>
                </div>
              </label>
              <div class="mt-2">
                <input
                  v-model="form.link"
                  class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                  placeholder="Atau tempel link repo / Drive di sini..."
                  type="url"
                />
              </div>
            </div>

            <!-- 2. Category Selector -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2">Jenis Tugas</label>
              <div class="flex overflow-x-auto no-scrollbar gap-2 pb-2">
                <label v-for="c in categories" :key="c.value" class="cursor-pointer">
                  <input v-model="form.category" class="peer sr-only" name="category" type="radio" :value="c.value" />
                  <div
                    class="px-4 py-2 rounded-full border border-border-subtle bg-surface-white text-secondary font-label-sm text-label-sm peer-checked:bg-primary-container peer-checked:text-on-primary-container peer-checked:border-primary-container transition-colors whitespace-nowrap"
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
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant resize-none"
                placeholder="Jelaskan error, fitur yang ingin dibuat, atau instruksi tugas dari dosen..."
                rows="4"
              ></textarea>
            </div>

            <!-- 4. Deadline Selector -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2">Deadline</label>
              <div class="grid grid-cols-3 gap-3">
                <label v-for="d in deadlines" :key="d.value" class="cursor-pointer relative">
                  <input v-model="form.deadline" class="peer sr-only" name="deadline" type="radio" :value="d.value" />
                  <div class="h-full flex flex-col items-center justify-center p-3 rounded-xl border border-border-subtle bg-surface-white text-secondary peer-checked:bg-primary-fixed peer-checked:text-on-primary-fixed peer-checked:border-electric-blue transition-all">
                    <span class="material-symbols-outlined mb-1" :style="{ fontVariationSettings: d.fill ? `'FILL' 1` : `'FILL' 0` }">{{ d.icon }}</span>
                    <span class="font-label-sm text-label-sm text-center">{{ d.label }}<br /><span class="text-[10px] opacity-70">{{ d.sub }}</span></span>
                  </div>
                </label>
              </div>
              <div v-if="form.deadline === 'fleksibel'" class="mt-4 rounded-xl border border-electric-blue/30 bg-primary-fixed/40 p-4">
                <label class="block font-label-bold text-label-bold text-on-background mb-2" for="deadline_date">Pilih tanggal deadline</label>
                <input
                  id="deadline_date"
                  v-model="form.deadline_date"
                  type="date"
                  :min="new Date().toISOString().slice(0, 10)"
                  required
                  class="w-full rounded-lg border border-border-subtle bg-surface-white px-4 py-3 text-body-md text-on-surface focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none"
                />
                <p class="text-xs text-secondary mt-2">Tanggal ini membantu engineer menentukan prioritas pengerjaan.</p>
              </div>
            </div>

            <!-- 5. WhatsApp Number -->
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-2" for="whatsapp">Nomor WhatsApp aktif</label>
              <div class="relative">
                <span class="absolute inset-y-0 left-0 flex items-center pl-4 text-on-surface-variant font-body-md">+62</span>
                <input
                  id="whatsapp"
                  v-model="form.whatsapp"
                  class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest pl-12 pr-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none transition-shadow placeholder:text-outline-variant"
                  placeholder="81234567890"
                  type="tel"
                />
              </div>
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
                  class="w-full rounded-xl border bg-surface-container-lowest px-4 py-3 text-body-md outline-none transition-all placeholder:text-outline-variant font-mono uppercase tracking-widest"
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

            <!-- Error -->
            <div v-if="errorMsg" class="bg-error-container text-on-error-container rounded-lg px-4 py-3 font-body-md text-body-md">
              {{ errorMsg }}
            </div>

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

            <!-- CTA -->
            <div class="pt-1">
              <button
                class="w-full bg-electric-blue text-surface-white font-label-bold text-label-bold py-4 rounded-xl flex items-center justify-center gap-2 hover:opacity-90 active:scale-95 transition-all shadow-md min-h-[44px] disabled:opacity-60 disabled:active:scale-100"
                type="submit"
                :disabled="submitting"
              >
                <span v-if="submitting" class="material-symbols-outlined animate-spin">progress_activity</span>
                <span v-else class="material-symbols-outlined">send</span>
                {{ submitting ? 'Mengirim...' : 'Kirim & Konsultasi Gratis' }}
              </button>
            </div>

          </form>
        </div>
      </div>
    </main>

    <FooterBar />
    <BottomNavBar />
  </div>
</template>