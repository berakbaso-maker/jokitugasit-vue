<script setup>
import { ref, watch } from 'vue'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import {
  createPartner,
  getPartnerByCode,
  generateReferralCode,
  getPartnerOverview,
  formatRupiah,
  CATEGORY_LABELS,
  STATUS_LABELS,
  waLink,
} from '../lib/api'

const WA_ENGINEER = '6285166337257'

// Tab: 'register' | 'check'
const activeActionTab = ref('register')

// Check commission portal state
const checkInput = ref('')
const checkLoading = ref(false)
const checkError = ref('')
const partnerData = ref(null)
const copyPromoSuccess = ref(false)

async function handleCheckPartner() {
  checkError.value = ''
  partnerData.value = null
  const query = checkInput.value.trim().toUpperCase()
  if (!query) {
    checkError.value = 'Masukkan kode referral kamu terlebih dahulu.'
    return
  }
  checkLoading.value = true
  try {
    const data = await getPartnerOverview(query)
    if (!data) {
      checkError.value = 'Kode referral tidak ditemukan atau belum aktif. Periksa kembali penulisannya.'
      return
    }
    partnerData.value = data
  } catch (err) {
    checkError.value = err.message || 'Gagal memeriksa komisi. Coba lagi.'
  } finally {
    checkLoading.value = false
  }
}

function copyPromoText() {
  if (!partnerData.value) return
  const code = partnerData.value.partner.referral_code
  const text = `Halo temen-temen! Kalau kalian lagi mentok ngoding tugas kuliah, skripsi, error runtime, atau integrasi API, aku rekomendasiin pake jasa engineer di jokitugasit.my.id.

Pake kode referralku "${code}" pas konsul biar diprioritasin sama engineernya. Hasilnya rapi, ada video penjelasan kode & bebas tanya jawab pas demo dosen! 👍
Link: https://jokitugasit.my.id/request`
  navigator.clipboard.writeText(text)
  copyPromoSuccess.value = true
  setTimeout(() => (copyPromoSuccess.value = false), 2500)
}

const form = ref({
  full_name: '',
  whatsapp: '',
  campus: '',
  ewallet_info: '',
})

const submitting = ref(false)
const errorMsg = ref('')
const success = ref(false)
const generatedCode = ref('')

const steps = [
  { icon: 'person_add', num: '01', title: 'Daftar Gratis', desc: 'Isi form di bawah. Tidak perlu keahlian ngoding, tidak ada modal.' },
  { icon: 'share', num: '02', title: 'Share Kode Unik', desc: 'Bagikan kode referralmu ke teman-teman yang sedang stuck ngoding atau mengerjakan skripsi.' },
  { icon: 'payments', num: '03', title: 'Terima Komisi 10%', desc: 'Setiap kali temanmu deal project, kamu dapat komisi 10% langsung ke e-wallet/rekening.' },
]

const benefits = [
  { icon: 'attach_money', title: 'Komisi 10% Bersih', desc: 'Dari setiap transaksi yang berhasil via kode kamu. Project Rp1jt = Rp100rb buat kamu.' },
  { icon: 'schedule', title: 'Tanpa Batas Waktu', desc: 'Kode aktif sepanjang semester. Semakin banyak teman, semakin besar komisi yang terkumpul.' },
  { icon: 'code_off', title: 'Zero Skill Teknis', desc: 'Kamu tidak perlu bisa ngoding. Cukup rekomendasikan ke teman yang butuh bantuan.' },
  { icon: 'security', title: 'Pembayaran Terjamin', desc: 'Komisi dibayar maksimal 24 jam setelah client lunas. Via GoPay, OVO, Dana, atau Transfer Bank.' },
]

const faqs = [
  { q: 'Kapan komisi saya dibayar?', a: 'Komisi dibayar maksimal 1×24 jam setelah client melunasi 100% pembayaran project.' },
  { q: 'Berapa minimal transaksi untuk dapat komisi?', a: 'Tidak ada minimal. Transaksi Rp150.000 pun, komisi 10% (Rp15.000) langsung cair.' },
  { q: 'Bagaimana cara tahu teman saya sudah deal?', a: 'Engineer akan langsung menghubungi kamu via WhatsApp setiap kali ada deal dari kode referralmu.' },
  { q: 'Apakah saya bisa pakai kode untuk diri sendiri?', a: 'Kode referral tidak berlaku untuk diri sendiri (self-referral). Namun, kamu bisa manfaatkan promo client baru jika sedang ada.' },
  { q: 'Berapa banyak teman yang bisa saya referensikan?', a: 'Tidak ada batas! Semakin banyak teman yang kamu bantu, semakin besar penghasilan pasifmu.' },
]

const openFaq = ref(null)
function toggleFaq(i) { openFaq.value = openFaq.value === i ? null : i }

async function handleSubmit() {
  errorMsg.value = ''
  if (!form.value.full_name.trim()) return (errorMsg.value = 'Nama lengkap wajib diisi.')
  if (!form.value.whatsapp.trim()) return (errorMsg.value = 'Nomor WhatsApp wajib diisi.')
  const wa = form.value.whatsapp.replace(/[^0-9]/g, '')
  if (wa.length < 9) return (errorMsg.value = 'Nomor WhatsApp tidak valid.')

  submitting.value = true
  try {
    // Generate kode unik, pastikan tidak duplikat
    let code = generateReferralCode(form.value.full_name)
    // Cek duplikat (simple check)
    const existing = await getPartnerByCode(code)
    if (existing) code = generateReferralCode(form.value.full_name + Math.random())

    const waNum = wa.startsWith('0') ? '62' + wa.slice(1) : wa.startsWith('62') ? wa : '62' + wa
    await createPartner({
      full_name: form.value.full_name.trim(),
      whatsapp: waNum,
      campus: form.value.campus.trim() || null,
      ewallet_info: form.value.ewallet_info.trim() || null,
      referral_code: code,
    })
    generatedCode.value = code
    success.value = true
  } catch (err) {
    errorMsg.value = 'Terjadi kesalahan. Coba lagi atau hubungi engineer via WhatsApp.'
    console.error(err)
  } finally {
    submitting.value = false
  }
}

function copyCode() {
  navigator.clipboard?.writeText(generatedCode.value)
}
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />

    <main class="flex-1">

      <!-- Hero Section -->
      <section class="relative overflow-hidden bg-gradient-to-br from-electric-blue via-primary to-tertiary text-white py-20 md:py-28 px-gutter">
        <div class="absolute inset-0 opacity-10" style="background-image: radial-gradient(circle at 20% 50%, #fff 0.5px, transparent 0.5px), radial-gradient(circle at 80% 20%, #fff 0.5px, transparent 0.5px); background-size: 40px 40px;"></div>
        <div class="relative max-w-container-max-width mx-auto text-center">
          <div class="inline-flex items-center gap-2 bg-white/15 border border-white/25 rounded-full px-4 py-1.5 mb-6 backdrop-blur-sm">
            <span class="material-symbols-outlined text-[16px]" style="font-variation-settings: 'FILL' 1">monetization_on</span>
            <span class="text-label-sm font-label-sm">Program Partner Referral Terbuka</span>
          </div>
          <h1 class="font-bold text-3xl md:text-5xl leading-tight mb-5">
            Hasilkan Uang dari<br>
            <span class="text-tertiary-fixed">Teman yang Mentok Ngoding</span>
          </h1>
          <p class="text-white/80 text-body-lg font-body-lg max-w-2xl mx-auto mb-8">
            Rekomendasikan jasa bantuan IT ke teman-temanmu yang lagi deadline,
            dan dapat <strong class="text-white">komisi 10%</strong> setiap kali deal — tanpa modal, tanpa keahlian ngoding.
          </p>
          <div class="flex flex-col sm:flex-row gap-3 justify-center">
            <a href="#daftar" class="inline-flex items-center justify-center gap-2 bg-white text-electric-blue font-label-bold text-label-bold px-8 py-4 rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-0.5 transition-all">
              <span class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1">how_to_reg</span>
              Daftar Sekarang — Gratis
            </a>
            <a :href="waLink(WA_ENGINEER, 'Halo, saya mau tanya soal program Partner Referral jokitugasit.my.id')" target="_blank" rel="noopener" class="inline-flex items-center justify-center gap-2 bg-white/15 border border-white/30 text-white font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-white/25 transition-all">
              <span class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1">chat</span>
              Tanya via WhatsApp
            </a>
          </div>

          <!-- Quick Stats -->
          <div class="grid grid-cols-3 gap-6 max-w-lg mx-auto mt-14 border-t border-white/20 pt-10">
            <div>
              <div class="text-2xl md:text-3xl font-bold">10%</div>
              <div class="text-white/70 text-[13px] mt-0.5">Komisi per deal</div>
            </div>
            <div>
              <div class="text-2xl md:text-3xl font-bold">24 jam</div>
              <div class="text-white/70 text-[13px] mt-0.5">Bayar komisi</div>
            </div>
            <div>
              <div class="text-2xl md:text-3xl font-bold">Rp0</div>
              <div class="text-white/70 text-[13px] mt-0.5">Modal awal</div>
            </div>
          </div>
        </div>
      </section>

      <!-- How it works -->
      <section class="py-16 md:py-24 px-gutter bg-surface-white">
        <div class="max-w-container-max-width mx-auto">
          <div class="text-center mb-12">
            <h2 class="text-headline-lg font-headline-lg font-bold text-on-surface mb-3">Cara Kerjanya Simpel Banget</h2>
            <p class="text-on-surface-variant font-body-md text-body-md max-w-xl mx-auto">Cukup 3 langkah, langsung bisa mulai hasilkan uang dari jaringanmu.</p>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div v-for="(step, i) in steps" :key="i" class="relative text-center group">
              <div v-if="i < steps.length - 1" class="hidden md:block absolute top-10 left-[60%] w-[80%] h-px bg-gradient-to-r from-electric-blue/30 to-transparent z-0"></div>
              <div class="relative z-10">
                <div class="w-20 h-20 rounded-2xl bg-gradient-to-br from-electric-blue to-primary flex items-center justify-center mx-auto mb-5 shadow-lg group-hover:shadow-xl group-hover:-translate-y-1 transition-all">
                  <span class="material-symbols-outlined text-white text-[32px]" style="font-variation-settings: 'FILL' 1">{{ step.icon }}</span>
                </div>
                <div class="text-label-sm font-label-sm text-electric-blue mb-1">LANGKAH {{ step.num }}</div>
                <h3 class="font-headline-md text-headline-md font-bold text-on-surface mb-2">{{ step.title }}</h3>
                <p class="text-on-surface-variant font-body-md text-body-md">{{ step.desc }}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Benefits Grid -->
      <section class="py-16 md:py-24 px-gutter bg-background">
        <div class="max-w-container-max-width mx-auto">
          <div class="text-center mb-12">
            <h2 class="text-headline-lg font-headline-lg font-bold text-on-surface mb-3">Kenapa Jadi Partner Referral?</h2>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-5">
            <div v-for="b in benefits" :key="b.title" class="flex gap-4 bg-surface-white rounded-2xl p-6 border border-border-subtle hover:border-electric-blue/30 hover:shadow-md transition-all group">
              <div class="w-12 h-12 rounded-xl bg-primary-fixed/40 flex items-center justify-center flex-shrink-0 group-hover:bg-electric-blue group-hover:text-white transition-colors">
                <span class="material-symbols-outlined text-electric-blue group-hover:text-white transition-colors" style="font-variation-settings: 'FILL' 1">{{ b.icon }}</span>
              </div>
              <div>
                <h3 class="font-bold text-on-surface mb-1">{{ b.title }}</h3>
                <p class="text-on-surface-variant text-body-md font-body-md text-sm">{{ b.desc }}</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Simulasi Penghasilan -->
      <section class="py-16 md:py-24 px-gutter bg-gradient-to-br from-primary-fixed/30 to-secondary-fixed/20">
        <div class="max-w-container-max-width mx-auto">
          <div class="text-center mb-12">
            <h2 class="text-headline-lg font-headline-lg font-bold text-on-surface mb-3">Simulasi Penghasilan Partner</h2>
            <p class="text-on-surface-variant font-body-md text-body-md">Berapa uang yang bisa kamu hasilkan setiap bulan?</p>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            <div class="bg-surface-white rounded-2xl p-6 border border-border-subtle text-center">
              <div class="text-3xl font-bold text-on-surface mb-1">Rp150rb</div>
              <div class="text-label-sm font-label-sm text-on-surface-variant mb-4">SKENARIO MINIMAL</div>
              <ul class="text-left space-y-2 text-sm text-on-surface-variant mb-5">
                <li class="flex gap-2"><span class="text-success-green">✓</span> 1 teman deal Quick Fix Rp300rb</li>
                <li class="flex gap-2"><span class="text-success-green">✓</span> 1 teman deal project Rp1.2jt</li>
              </ul>
              <div class="text-electric-blue font-bold text-sm">Komisi = Rp150rb/bulan</div>
            </div>
            <div class="bg-electric-blue rounded-2xl p-6 border border-electric-blue text-white text-center relative ring-2 ring-electric-blue/30">
              <span class="absolute -top-3 left-1/2 -translate-x-1/2 bg-success-green text-white text-[10px] font-bold uppercase px-3 py-1 rounded-full">Paling Realistis</span>
              <div class="text-3xl font-bold mb-1">Rp500rb+</div>
              <div class="text-[12px] text-white/70 mb-4">TARGET BULANAN</div>
              <ul class="text-left space-y-2 text-sm text-white/80 mb-5">
                <li class="flex gap-2"><span class="text-tertiary-fixed">✓</span> 3–4 teman deal berbagai tier</li>
                <li class="flex gap-2"><span class="text-tertiary-fixed">✓</span> 1 project skripsi Rp2.5jt</li>
              </ul>
              <div class="text-tertiary-fixed font-bold text-sm">Komisi = Rp250rb–Rp500rb/bulan</div>
            </div>
            <div class="bg-surface-white rounded-2xl p-6 border border-border-subtle text-center">
              <div class="text-3xl font-bold text-on-surface mb-1">Rp1jt+</div>
              <div class="text-label-sm font-label-sm text-on-surface-variant mb-4">SKENARIO OPTIMAL</div>
              <ul class="text-left space-y-2 text-sm text-on-surface-variant mb-5">
                <li class="flex gap-2"><span class="text-success-green">✓</span> 8–10 teman aktif direferensikan</li>
                <li class="flex gap-2"><span class="text-success-green">✓</span> 2+ project skripsi/capstone</li>
              </ul>
              <div class="text-electric-blue font-bold text-sm">Komisi = Rp700rb–Rp1.5jt/bulan</div>
            </div>
          </div>
        </div>
      </section>

      <!-- Form Daftar / Cek Komisi -->
      <section id="daftar" class="py-16 md:py-24 px-gutter bg-surface-white scroll-mt-20">
        <div class="max-w-xl mx-auto">
          <!-- Action Tabs -->
          <div class="flex justify-center mb-8">
            <div class="inline-flex p-1 rounded-xl bg-surface-container-high border border-border-subtle">
              <button
                @click="activeActionTab = 'register'"
                class="px-5 py-2.5 rounded-lg text-xs sm:text-sm font-bold transition-all"
                :class="activeActionTab === 'register' ? 'bg-surface-white text-electric-blue shadow-xs' : 'text-secondary hover:text-on-surface'"
              >
                Daftar Partner Baru
              </button>
              <button
                @click="activeActionTab = 'check'"
                class="px-5 py-2.5 rounded-lg text-xs sm:text-sm font-bold transition-all flex items-center gap-1.5"
                :class="activeActionTab === 'check' ? 'bg-surface-white text-electric-blue shadow-xs' : 'text-secondary hover:text-on-surface'"
              >
                <span class="material-symbols-outlined text-[16px]">account_balance_wallet</span>
                Cek Komisi Saya
              </button>
            </div>
          </div>

          <!-- TAB 2: CEK KOMISI & STATUS PARTNER -->
          <div v-if="activeActionTab === 'check'" class="space-y-6">
            <div class="text-center mb-6">
              <h2 class="text-headline-md sm:text-headline-lg font-bold text-on-surface mb-2">Portal Transparansi Komisi Partner</h2>
              <p class="text-secondary text-sm">Masukkan kode referral unikmu untuk cek status teman yang kamu bantu dan total komisi yang berhak kamu cairkan.</p>
            </div>

            <form @submit.prevent="handleCheckPartner" class="flex gap-2">
              <input
                v-model="checkInput"
                type="text"
                placeholder="Contoh: REF-BUDI10"
                class="flex-1 rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-sm font-mono uppercase tracking-wider text-on-surface outline-none focus:border-electric-blue focus:ring-1 focus:ring-electric-blue"
              />
              <button
                type="submit"
                :disabled="checkLoading"
                class="bg-electric-blue text-white px-5 py-3 rounded-xl font-bold text-sm hover:bg-primary transition-all disabled:opacity-60 flex items-center gap-1.5 shrink-0"
              >
                <span v-if="checkLoading" class="material-symbols-outlined text-[18px] animate-spin">progress_activity</span>
                <span v-else class="material-symbols-outlined text-[18px]">search</span>
                Cek
              </button>
            </form>

            <div v-if="checkError" class="bg-error-container/40 text-on-error-container p-3.5 rounded-xl text-xs flex items-center gap-2">
              <span class="material-symbols-outlined text-[18px]">error</span>
              <span>{{ checkError }}</span>
            </div>

            <!-- Result Portal -->
            <div v-if="partnerData" class="space-y-6 pt-2">
              <div class="bg-gradient-to-br from-primary-fixed/30 to-secondary-fixed/20 p-5 sm:p-6 rounded-2xl border border-electric-blue/30">
                <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-border-subtle/50">
                  <div>
                    <span class="text-xs font-semibold text-secondary uppercase tracking-wider">Partner Terverifikasi</span>
                    <h3 class="text-lg font-extrabold text-on-surface">{{ partnerData.partner.full_name }}</h3>
                    <p class="text-xs text-secondary mt-0.5">{{ partnerData.partner.campus || 'Mahasiswa IT' }} · Kode: <strong class="text-electric-blue font-mono">{{ partnerData.partner.referral_code }}</strong></p>
                  </div>
                  <button
                    @click="copyPromoText"
                    class="self-start sm:self-auto bg-surface-white border border-border-subtle hover:border-electric-blue text-electric-blue text-xs font-bold px-3 py-2 rounded-xl transition-all flex items-center gap-1.5 shadow-2xs"
                  >
                    <span class="material-symbols-outlined text-[16px]">share</span>
                    {{ copyPromoSuccess ? '✓ Teks Tersalin!' : 'Salin Teks Rekomendasi' }}
                  </button>
                </div>

                <!-- Stats Grid -->
                <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-4 text-center">
                  <div class="bg-surface-white/80 backdrop-blur-xs p-3 rounded-xl border border-border-subtle">
                    <div class="text-xs text-secondary mb-1">Teman Pakai</div>
                    <div class="text-xl font-extrabold text-on-surface">{{ partnerData.stats.totalReferrals }}</div>
                  </div>
                  <div class="bg-surface-white/80 backdrop-blur-xs p-3 rounded-xl border border-border-subtle">
                    <div class="text-xs text-secondary mb-1">Project Deal</div>
                    <div class="text-xl font-extrabold text-electric-blue">{{ partnerData.stats.dealCount }}</div>
                  </div>
                  <div class="bg-surface-white/80 backdrop-blur-xs p-3 rounded-xl border border-border-subtle">
                    <div class="text-xs text-secondary mb-1">Komisi Cair</div>
                    <div class="text-xl font-extrabold text-success-green">{{ formatRupiah(partnerData.stats.totalEarned) }}</div>
                  </div>
                  <div class="bg-surface-white/80 backdrop-blur-xs p-3 rounded-xl border border-border-subtle">
                    <div class="text-xs text-secondary mb-1">Menunggu Cair</div>
                    <div class="text-xl font-extrabold text-urgency-red">{{ formatRupiah(partnerData.stats.pendingEarned) }}</div>
                  </div>
                </div>
              </div>

              <!-- List of Referred Requests -->
              <div>
                <h4 class="font-bold text-sm text-on-surface mb-3 flex items-center gap-1.5">
                  <span class="material-symbols-outlined text-[18px] text-electric-blue">history</span>
                  Riwayat Project Teman Kamu
                </h4>
                <div v-if="partnerData.requests.length === 0" class="text-center py-8 bg-surface-container-low rounded-xl text-xs text-secondary">
                  Belum ada teman yang menggunakan kodemu. Bagikan kodemu ke grup angkatan sekarang!
                </div>
                <div v-else class="space-y-2">
                  <div
                    v-for="req in partnerData.requests"
                    :key="req.order_no"
                    class="bg-surface-container-lowest p-3.5 rounded-xl border border-border-subtle flex items-center justify-between text-xs"
                  >
                    <div>
                      <div class="font-bold text-on-surface">Order #{{ req.order_no }} ({{ CATEGORY_LABELS[req.category] || req.category }})</div>
                      <div class="text-secondary mt-0.5">Status: <span class="font-semibold text-on-surface">{{ STATUS_LABELS[req.status] || req.status }}</span></div>
                    </div>
                    <div class="text-right">
                      <div v-if="req.quote_amount" class="font-extrabold text-electric-blue">
                        Komisi: {{ formatRupiah(req.quote_amount * 0.1) }}
                      </div>
                      <span
                        v-if="req.commission_paid"
                        class="inline-block mt-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-success-green/10 text-success-green"
                      >
                        ✓ Sudah Ditransfer
                      </span>
                      <span
                        v-else-if="['done', 'paid', 'review'].includes(req.status)"
                        class="inline-block mt-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-yellow-500/10 text-yellow-600"
                      >
                        Menunggu Transfer (1x24 Jam)
                      </span>
                      <span
                        v-else
                        class="inline-block mt-1 px-2 py-0.5 rounded-full text-[10px] font-medium text-secondary"
                      >
                        Dalam Proses
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <div class="bg-surface-container p-4 rounded-xl text-xs text-secondary flex items-start gap-2.5">
                <span class="material-symbols-outlined text-[18px] text-electric-blue mt-0.5">info</span>
                <div>
                  Ada pertanyaan seputar pencairan komisi? Langsung chat ke WhatsApp Engineer:
                  <a :href="waLink(WA_ENGINEER, `Halo, saya partner ${partnerData.partner.referral_code} mau tanya update komisi.`)" target="_blank" class="text-electric-blue font-bold underline ml-1">
                    Hubungi via WhatsApp
                  </a>
                </div>
              </div>
            </div>
          </div>

          <!-- TAB 1: FORM DAFTAR PARTNER BARU -->
          <div v-else>
          <!-- Success State -->
          <div v-if="success" class="text-center">
            <div class="w-20 h-20 rounded-full bg-success-green/10 flex items-center justify-center mx-auto mb-6">
              <span class="material-symbols-outlined text-success-green text-[40px]" style="font-variation-settings: 'FILL' 1">check_circle</span>
            </div>
            <h2 class="text-headline-md font-headline-md font-bold text-on-surface mb-2">Kamu Resmi Jadi Partner! 🎉</h2>
            <p class="text-on-surface-variant font-body-md text-body-md mb-8">Engineer akan menghubungi kamu via WhatsApp dalam 1×24 jam untuk konfirmasi. Ini kode referral unikmu:</p>

            <div class="bg-gradient-to-r from-electric-blue/5 to-primary-fixed/20 border-2 border-electric-blue/30 rounded-2xl p-6 mb-6">
              <div class="text-label-sm font-label-sm text-on-surface-variant mb-2">KODE REFERRAL KAMU</div>
              <div class="text-3xl font-bold text-electric-blue tracking-widest mb-3">{{ generatedCode }}</div>
              <button @click="copyCode" class="inline-flex items-center gap-1.5 bg-electric-blue text-white text-sm font-bold px-4 py-2 rounded-lg hover:bg-primary transition-colors">
                <span class="material-symbols-outlined text-[16px]">content_copy</span>
                Salin Kode
              </button>
            </div>

            <div class="bg-surface-container rounded-xl p-5 text-left text-sm text-on-surface-variant mb-6">
              <p class="font-bold text-on-surface mb-2">Langkah selanjutnya:</p>
              <ol class="space-y-1.5 list-decimal list-inside">
                <li>Simpan kode referralmu di atas.</li>
                <li>Bagikan ke teman yang lagi deadline atau mentok ngoding.</li>
                <li>Minta mereka sebut kode kamu saat ngobrol dengan engineer via WhatsApp.</li>
                <li>Komisi 10% otomatis tercatat dan dibayar setelah deal selesai.</li>
              </ol>
            </div>

            <a :href="waLink(WA_ENGINEER, `Halo, saya baru daftar jadi Partner Referral. Kode saya: ${generatedCode}`)" target="_blank" rel="noopener" class="inline-flex items-center gap-2 bg-success-green text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:opacity-90 transition-opacity">
              <span class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1">chat</span>
              Konfirmasi via WhatsApp
            </a>
          </div>

          <!-- Form State -->
          <div v-else>
            <div class="text-center mb-10">
              <h2 class="text-headline-lg font-headline-lg font-bold text-on-surface mb-3">Daftar Jadi Partner Referral</h2>
              <p class="text-on-surface-variant font-body-md text-body-md">Gratis. Tidak ada kewajiban. Mulai hasilkan komisi hari ini.</p>
            </div>

            <form @submit.prevent="handleSubmit" class="space-y-5">
              <div>
                <label class="block text-label-sm font-label-sm text-on-surface-variant mb-1.5">Nama Lengkap <span class="text-urgency-red">*</span></label>
                <input v-model="form.full_name" type="text" placeholder="Nama kamu (dipakai untuk generate kode)" required
                  class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40 focus:border-electric-blue transition-all">
              </div>

              <div>
                <label class="block text-label-sm font-label-sm text-on-surface-variant mb-1.5">Nomor WhatsApp <span class="text-urgency-red">*</span></label>
                <input v-model="form.whatsapp" type="tel" placeholder="08xxxx (komisi dikirim & dikonfirmasi via WA)" required
                  class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40 focus:border-electric-blue transition-all">
              </div>

              <div>
                <label class="block text-label-sm font-label-sm text-on-surface-variant mb-1.5">Kampus <span class="text-on-surface-variant/50">(opsional)</span></label>
                <input v-model="form.campus" type="text" placeholder="Contoh: Binus, Telkom, Trisakti..."
                  class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40 focus:border-electric-blue transition-all">
              </div>

              <div>
                <label class="block text-label-sm font-label-sm text-on-surface-variant mb-1.5">Info Rekening / E-wallet <span class="text-on-surface-variant/50">(opsional, bisa diisi nanti)</span></label>
                <input v-model="form.ewallet_info" type="text" placeholder="GoPay/OVO/Dana: 08xxx atau Nama Bank: No Rek"
                  class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40 focus:border-electric-blue transition-all">
                <p class="text-[11px] text-on-surface-variant mt-1">Digunakan untuk transfer komisi. Bisa dikirimkan via WhatsApp kemudian.</p>
              </div>

              <p v-if="errorMsg" class="text-sm text-urgency-red bg-error-container/30 rounded-lg px-4 py-2.5">{{ errorMsg }}</p>

              <button type="submit" :disabled="submitting"
                class="w-full flex items-center justify-center gap-2 bg-electric-blue text-white font-label-bold text-label-bold px-7 py-4 rounded-xl shadow-md hover:bg-primary hover:shadow-lg transition-all disabled:opacity-60 disabled:cursor-not-allowed">
                <span v-if="submitting" class="material-symbols-outlined animate-spin text-[20px]">progress_activity</span>
                <span v-else class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1">how_to_reg</span>
                {{ submitting ? 'Mendaftarkan...' : 'Daftar Jadi Partner Sekarang' }}
              </button>

              <p class="text-center text-xs text-on-surface-variant">
                Dengan mendaftar, kamu setuju dengan <a href="#faq" class="text-electric-blue underline">ketentuan program referral</a>.
                Data kamu aman dan tidak dibagikan ke pihak ketiga.
              </p>
            </form>
          </div>
          </div>
        </div>
      </section>

      <!-- FAQ -->
      <section id="faq" class="py-16 md:py-24 px-gutter bg-background">
        <div class="max-w-2xl mx-auto">
          <h2 class="text-headline-lg font-headline-lg font-bold text-on-surface mb-10 text-center">Pertanyaan yang Sering Ditanya</h2>
          <div class="space-y-3">
            <div v-for="(item, i) in faqs" :key="i"
              class="bg-surface-white rounded-xl border border-border-subtle overflow-hidden">
              <button @click="toggleFaq(i)" class="w-full flex items-center justify-between px-5 py-4 text-left">
                <span class="font-bold text-on-surface text-sm md:text-base">{{ item.q }}</span>
                <span class="material-symbols-outlined text-electric-blue flex-shrink-0 transition-transform" :class="openFaq === i ? 'rotate-180' : ''">expand_more</span>
              </button>
              <div v-if="openFaq === i" class="px-5 pb-4 text-on-surface-variant text-body-md font-body-md text-sm">{{ item.a }}</div>
            </div>
          </div>
        </div>
      </section>

    </main>
    <BottomNavBar />
    <FooterBar />
  </div>
</template>
