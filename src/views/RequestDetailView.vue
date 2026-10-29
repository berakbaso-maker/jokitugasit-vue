<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import SideNav from '../components/SideNav.vue'
import {
  getRequest, updateRequest, waLink, DEADLINE_LABELS, STATUS_LABELS, CATEGORY_LABELS,
  SOURCE_LABELS, formatRupiah, listPayments, listCommissions, recordPayment, voidPayment,
  recomputeCommission, getAttachmentSignedUrl,
} from '../lib/api'
import {
  PAYMENT_KIND_LABELS, PAYMENT_STATUS_LABELS, paymentKey, remainingAmount,
  summarizePayments, toRupiahInteger,
} from '../lib/money'

const route = useRoute()
const router = useRouter()

const request = ref(null)
const loading = ref(true)
const errorMsg = ref('')

const quote = ref('')
const discount = ref('')
const notes = ref('')
const status = ref('consultation')
const source = ref('INBOUND')
const campus = ref('')
const stack = ref('')
const walkthroughUrl = ref('')
const walkthroughNotes = ref('')
const saving = ref(false)
const savedMsg = ref('')
const copySowSuccess = ref(false)

// ---------- pembayaran & komisi ----------
const payments = ref([])
const commission = ref(null)
const moneyLoading = ref(false)
const moneyError = ref('')
const paySaving = ref(false)
const payError = ref('')
const payMsg = ref('')
const pendingKey = ref('')
const payForm = ref({ kind: 'DP', amount: '', method: 'transfer', proofUrl: '', note: '' })
const paymentsSection = ref(null)
const attachmentLoading = ref(false)
const attachmentError = ref('')

const savedTotal = computed(() =>
  Math.max(Number(request.value?.quote_amount || 0) - Number(request.value?.discount_amount || 0), 0)
)
const summary = computed(() => summarizePayments(payments.value))
const remaining = computed(() => remainingAmount(savedTotal.value, summary.value.net))

const COMMISSION_LABELS = {
  PENDING: 'Menunggu pelunasan',
  ELIGIBLE: 'Siap dibayar',
  PAID: 'Sudah dibayar',
  VOID: 'Batal',
  ADJUSTMENT: 'Perlu review manual',
}
const commissionStatusText = computed(() => {
  if (!request.value?.referral_code) return 'Tanpa kode referral'
  if (!commission.value) return 'Belum dihitung'
  return COMMISSION_LABELS[commission.value.status] || commission.value.status
})

const ROW_CLICKABLE_CLASS = 'bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6 hover:border hover:border-electric-blue hover:shadow-lg transition-all duration-200 border border-transparent'

async function load() {
  loading.value = true
  try {
    request.value = await getRequest(route.params.id)
    if (request.value) {
      quote.value = request.value.quote_amount || ''
      discount.value = request.value.discount_amount || ''
      notes.value = request.value.internal_notes || ''
      status.value = request.value.status || 'consultation'
      source.value = request.value.source || 'INBOUND'
      campus.value = request.value.campus || ''
      stack.value = request.value.stack || ''
      walkthroughUrl.value = request.value.walkthrough_url || ''
      walkthroughNotes.value = request.value.walkthrough_notes || ''
    }
  } catch (err) {
    errorMsg.value = err.message || 'Gagal memuat detail request.'
  } finally {
    loading.value = false
  }
  await loadMoney()
}

onMounted(load)

async function save() {
  saving.value = true
  savedMsg.value = ''

  const discountInt = discount.value === '' ? 0 : Number(discount.value)
  if (!Number.isInteger(discountInt) || discountInt < 0) {
    savedMsg.value = 'Diskon harus bilangan bulat rupiah dan tidak negatif.'
    saving.value = false
    return
  }
  const quoteInt = quote.value === '' ? 0 : Number(quote.value)
  if (quoteInt && discountInt > quoteInt) {
    savedMsg.value = 'Diskon tidak boleh lebih besar dari nilai quotation.'
    saving.value = false
    return
  }
  if (status.value === 'paid' && request.value.status !== 'paid' && remaining.value > 0) {
    savedMsg.value = 'Status lunas hanya otomatis setelah pelunasan tercatat di bawah.'
    saving.value = false
    return
  }

  try {
    const patch = {
      status: status.value,
      source: source.value || null,
      campus: campus.value.trim() || null,
      stack: stack.value.trim() || null,
      quote_amount: quote.value ? Number(quote.value) : null,
      discount_amount: discountInt,
      internal_notes: notes.value || null,
      walkthrough_url: walkthroughUrl.value.trim() || null,
      walkthrough_notes: walkthroughNotes.value.trim() || null,
    }
    await updateRequest(request.value.id, patch)
    // Quote/diskon bisa berubah setelah pembayaran: nilai komisi harus
    // dihitung ulang oleh database, bukan ditebak di browser.
    // Kalau migration komisi belum terpasang, jangan blokir penyimpanan.
    try {
      await recomputeCommission(request.value.id)
    } catch (commissionErr) {
      console.warn('Recompute komisi dilewati:', commissionErr?.message)
    }
    request.value = await getRequest(request.value.id)
    status.value = request.value.status
    await loadMoney()
    savedMsg.value = 'Perubahan tersimpan.'
    setTimeout(() => (savedMsg.value = ''), 2500)
  } catch (err) {
    savedMsg.value = err.message || 'Gagal menyimpan.'
  } finally {
    saving.value = false
  }
}

function copySowInvoice() {
  if (!request.value) return
  const discountValue = Number(discount.value || request.value.discount_amount || 0)
  const q = Math.max(Number(quote.value || request.value.quote_amount || 0) - discountValue, 0)
  const dp = Math.round(q / 2)
  const sisa = q - dp
  const text = `Halo ${request.value.customer_name}, terima kasih sudah konsultasi di jokitugasit.my.id! 👍

Berikut rangkuman Penawaran & Scope of Work (SOW):
• Nomor Tiket: #${request.value.order_no}
• Kategori: ${CATEGORY_LABELS[request.value.category] || request.value.category}
• Rincian Problem: ${request.value.description}
• Total Investasi: ${q ? formatRupiah(q) : 'Sesuai kesepakatan'}
• DP 50%: ${dp ? formatRupiah(dp) : '-'} (pengerjaan langsung dimulai setelah konfirmasi DP)
• Pelunasan 50%: ${sisa ? formatRupiah(sisa) : '-'} (setelah hasil dicek via video walkthrough / screenshot)

Garansi Layanan:
✓ Free pendampingan & konsultasi persiapan demo dosen
✓ Garansi perbaikan jika ada runtime error saat presentasi

Rekening Pembayaran DP:
• BCA: 1234567890 a.n Engineer
• GoPay / OVO / Dana: 085166337257
(Kirim bukti transfer ke WhatsApp ini ya)

Mohon konfirmasi jika sepakat dengan SOW di atas agar pengerjaan segera dimulai. Terima kasih!`

  navigator.clipboard.writeText(text)
  copySowSuccess.value = true
  setTimeout(() => (copySowSuccess.value = false), 2500)
}

async function setStatus(next) {
  if (next === 'paid' && remaining.value > 0) {
    alert('Catat pelunasan dulu. Status lunas tidak bisa dipilih manual.')
    return
  }
  saving.value = true
  try {
    const updated = await updateRequest(request.value.id, { status: next })
    request.value = updated
    status.value = next
  } catch (err) {
    alert(err.message || 'Gagal update status.')
  } finally {
    saving.value = false
  }
}

// ---------- pembayaran ----------

async function loadMoney() {
  if (!request.value) return
  moneyLoading.value = true
  moneyError.value = ''
  try {
    const [pays, comms] = await Promise.all([
      listPayments(request.value.id),
      listCommissions({ requestId: request.value.id, limit: 1 }),
    ])
    payments.value = pays || []
    commission.value = (comms && comms[0]) || null
  } catch (err) {
    moneyError.value = err.message?.includes('relation') || err.code === '42P01'
      ? 'Tabel pembayaran belum terpasang. Jalankan migration-money-schema.sql lalu migration-payment-flow.sql.'
      : (err.message || 'Gagal memuat data pembayaran.')
  } finally {
    moneyLoading.value = false
  }
}

async function openAttachment() {
  const value = request.value?.file_url
  if (!value) return
  attachmentError.value = ''

  // Data baru menyimpan path. Data lama menyimpan URL publik; kalau URL itu
  // masih menunjuk ke bucket attachments, ekstrak path-nya dan minta signed URL
  // supaya tetap bisa dibuka setelah bucket dijadikan privat.
  let target = value
  if (/^https?:\/\//i.test(value)) {
    try {
      const url = new URL(value)
      const marker = '/attachments/'
      const idx = url.pathname.indexOf(marker)
      if (idx === -1) {
        window.open(value, '_blank', 'noopener')
        return
      }
      target = decodeURIComponent(url.pathname.slice(idx + marker.length))
    } catch {
      window.open(value, '_blank', 'noopener')
      return
    }
  }

  attachmentLoading.value = true
  try {
    const url = await getAttachmentSignedUrl(target)
    window.open(url, '_blank', 'noopener')
  } catch (err) {
    attachmentError.value = err.message || 'Gagal membuka lampiran.'
  } finally {
    attachmentLoading.value = false
  }
}

function scrollToPayments() {
  paymentsSection.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

async function openSettlement() {
  payForm.value.kind = 'SETTLEMENT'
  payForm.value.amount = remaining.value > 0 ? String(remaining.value) : ''
  payError.value = ''
  payMsg.value = ''
  await nextTick()
  scrollToPayments()
}

function fillDp() {
  payForm.value.kind = 'DP'
  payForm.value.amount = savedTotal.value > 0 ? String(Math.round(savedTotal.value / 2)) : ''
}

function fillRemaining() {
  payForm.value.kind = 'SETTLEMENT'
  payForm.value.amount = remaining.value > 0 ? String(remaining.value) : ''
}

async function addPayment() {
  payError.value = ''
  payMsg.value = ''
  if (!request.value) return

  const amount = toRupiahInteger(payForm.value.amount)
  if (!amount) {
    payError.value = 'Nominal harus bilangan bulat rupiah lebih dari 0 (tanpa desimal).'
    return
  }
  if (payForm.value.kind !== 'REFUND' && amount > remaining.value && remaining.value > 0) {
    const ok = window.confirm(
      `Nominal ${formatRupiah(amount)} melebihi sisa tagihan ${formatRupiah(remaining.value)}. Tetap catat?`,
    )
    if (!ok) return
  }

  // Kunci idempotensi dibuat sekali per percobaan; kalau request gagal
  // dan user menekan ulang, database tidak mencatat pembayaran ganda.
  if (!pendingKey.value) pendingKey.value = paymentKey(payForm.value.kind.toLowerCase())

  paySaving.value = true
  try {
    await recordPayment({
      requestId: request.value.id,
      kind: payForm.value.kind,
      amount,
      idempotencyKey: pendingKey.value,
      method: payForm.value.method || null,
      proofUrl: payForm.value.proofUrl.trim() || null,
      note: payForm.value.note.trim() || null,
    })
    pendingKey.value = ''
    payForm.value.amount = ''
    payForm.value.proofUrl = ''
    payForm.value.note = ''
    request.value = await getRequest(request.value.id)
    status.value = request.value.status
    quote.value = request.value.quote_amount || ''
    discount.value = request.value.discount_amount || ''
    await loadMoney()
    payMsg.value = `${PAYMENT_KIND_LABELS[payForm.value.kind] || payForm.value.kind} ${formatRupiah(amount)} tercatat.`
    setTimeout(() => (payMsg.value = ''), 3000)
  } catch (err) {
    payError.value = err.message || 'Gagal mencatat pembayaran.'
  } finally {
    paySaving.value = false
  }
}

async function cancelPayment(payment) {
  const reason = window.prompt(
    `Alasan membatalkan pembayaran ${PAYMENT_KIND_LABELS[payment.kind] || payment.kind} ${formatRupiah(payment.amount)}?\n(Pembayaran tidak dihapus; status jadi VOID dan alasan tersimpan.)`,
  )
  if (!reason || !reason.trim()) return

  payError.value = ''
  payMsg.value = ''
  try {
    await voidPayment(payment.id, reason.trim())
    request.value = await getRequest(request.value.id)
    status.value = request.value.status
    await loadMoney()
    payMsg.value = 'Pembayaran dibatalkan dan komisi dihitung ulang.'
    setTimeout(() => (payMsg.value = ''), 3000)
  } catch (err) {
    payError.value = err.message || 'Gagal membatalkan pembayaran.'
  }
}

const paymentStatusClass = (s) => {
  if (s === 'CONFIRMED') return 'bg-success-green/10 text-success-green'
  if (s === 'VOID') return 'bg-error-container text-on-error-container'
  return 'bg-surface-container text-on-surface-variant'
}

function fmtDate(iso) {
  if (!iso) return '-'
  return new Date(iso).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}

const typeColor = (c) => {
  const colors = { web: 'bg-primary-container text-on-primary-container', data: 'bg-secondary-container text-on-secondary-container', mobile: 'bg-tertiary-container text-on-tertiary', ai: 'bg-error-container text-on-error-container', lainnya: 'bg-surface-container-high text-on-surface-variant' }
  return colors[c] || 'bg-surface-container-high text-on-surface-variant'
}
</script>

<template>
  <SideNav>
    <div v-if="loading" class="p-10 text-center">
      <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
    </div>

    <div v-else-if="errorMsg || !request" class="p-10 text-center">
      <p class="text-body-md">{{ errorMsg || 'Request tidak ditemukan' }}</p>
      <button class="mt-4 text-electric-blue font-label-bold hover:underline" @click="router.push('/dashboard')">Kembali ke Dashboard</button>
    </div>

    <template v-else>
      <!-- Header -->
      <header class="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
        <div class="flex items-center gap-4">
          <button class="text-secondary hover:text-electric-blue transition-colors p-2 -ml-2 rounded-full hover:bg-surface-container-low" @click="router.push('/dashboard')">
            <span class="material-symbols-outlined">arrow_back</span>
          </button>
          <div>
            <h1 class="text-headline-lg font-headline-lg text-on-background flex items-center gap-3">
              {{ request.order_no }}
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize" :class="{ 'bg-tertiary-container text-on-tertiary-container': true }">{{ STATUS_LABELS[request.status] || request.status }}</span>
            </h1>
            <p class="text-secondary mt-1 text-sm">Diajukan {{ request.created_at ? new Date(request.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'long' }) : '-' }}</p>
          </div>
        </div>
      </header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left Column: Details -->
        <div class="lg:col-span-2 space-y-6">
          <section :class="ROW_CLICKABLE_CLASS">
            <h2 class="text-headline-md font-headline-md mb-4 flex items-center gap-2">
              <span class="material-symbols-outlined text-electric-blue">person</span>
              Customer Info
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <p class="text-label-sm font-label-sm text-secondary mb-1">Name</p>
                <p class="font-body-md font-medium">{{ request.customer_name }}</p>
              </div>
              <div>
                <p class="text-label-sm font-label-sm text-secondary mb-1">WhatsApp</p>
                <p class="font-body-md font-medium flex items-center gap-2">
                  +62 {{ request.whatsapp }}
                  <a
                    :href="waLink('62' + request.whatsapp, `Halo ${request.customer_name}, ini engineer jokitugasit.my.id untuk ${request.order_no}.`)"
                    target="_blank"
                    rel="noopener"
                    class="text-electric-blue hover:text-primary transition-colors inline-flex items-center"
                  >
                    <span class="material-symbols-outlined text-sm">chat</span>
                  </a>
                </p>
              </div>
            </div>
          </section>

          <section :class="ROW_CLICKABLE_CLASS + ' border-l-4 border-l-urgency-red'">
            <div class="flex justify-between items-start mb-4">
              <h2 class="text-headline-md font-headline-md flex items-center gap-2 text-urgency-red">
                <span class="material-symbols-outlined">warning</span>
                Problem Description
              </h2>
              <div class="px-3 py-1 bg-error-container text-on-error-container rounded-full text-xs font-bold flex items-center gap-1">
                <span class="material-symbols-outlined text-[16px]">schedule</span>
                {{ DEADLINE_LABELS[request.deadline] || request.deadline }}
              </div>
            </div>
            <div class="mb-6">
              <div class="flex gap-2 mb-3">
                <span class="px-3 py-1 bg-surface-container-low text-primary rounded-full text-xs font-semibold capitalize">{{ CATEGORY_LABELS[request.category] || request.category }}</span>
              </div>
              <div class="bg-surface-container-lowest p-4 rounded-lg border border-border-subtle">
                <p class="font-body-md italic text-on-surface-variant">"{{ request.description }}"</p>
              </div>
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 pt-4 border-t border-border-subtle">
              <div>
                <h3 class="text-label-sm font-label-sm text-secondary mb-2">Attachments</h3>
                <div class="space-y-2">
                  <button
                    v-if="request.file_url"
                    @click="openAttachment"
                    :disabled="attachmentLoading"
                    class="w-full flex items-center gap-2 p-2 rounded-lg bg-surface-container-low hover:bg-surface-container-high transition-colors disabled:opacity-60"
                  >
                    <span class="material-symbols-outlined text-electric-blue">folder_zip</span>
                    <span class="text-sm truncate">{{ attachmentLoading ? 'Membuka...' : 'Lihat file lampiran' }}</span>
                  </button>
                  <p v-else class="text-sm text-outline">Tidak ada lampiran.</p>
                  <p v-if="attachmentError" class="text-[11px] text-urgency-red">{{ attachmentError }}</p>
                </div>
              </div>
              <div>
                <h3 class="text-label-sm font-label-sm text-secondary mb-2">Links</h3>
                <a v-if="request.link" class="flex items-center gap-2 p-2 rounded-lg bg-surface-container-low hover:bg-surface-container-high transition-colors text-electric-blue" :href="request.link" target="_blank" rel="noopener">
                  <span class="material-symbols-outlined">link</span>
                  <span class="text-sm truncate underline">{{ request.link }}</span>
                </a>
                <p v-else class="text-sm text-outline">Tidak ada link.</p>
              </div>
            </div>
          </section>
        </div>

        <!-- Right Column: Action Panel -->
        <div class="space-y-6">
          <section class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6 sticky top-24" :class="request.deadline === 'hari_ini' ? 'border-l-4 border-l-urgency-red' : ''">
            <h2 class="text-headline-md font-headline-md mb-6 border-b border-border-subtle pb-4">Actions</h2>

            <div class="mb-6 bg-surface-container-low p-4 rounded-lg">
              <p class="text-label-sm font-label-sm text-secondary mb-1">Customer Budget Estimate</p>
              <p class="font-headline-md text-primary font-bold">{{ request.budget_estimate ? formatRupiah(request.budget_estimate) : 'Belum diisi' }}</p>
            </div>

            <div class="mb-4">
              <label class="block text-label-bold font-label-bold mb-2">Your Quote (Rp)</label>
              <input v-model="quote" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3" placeholder="e.g. 200000" type="number" />
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Diskon (Rp)</label>
              <input v-model="discount" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3" placeholder="0" type="number" min="0" />
              <p class="text-[11px] text-secondary mt-1">Total tagihan = Quote − Diskon. Komisi 10% dihitung database dari total ini.</p>
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Internal Notes</label>
              <textarea v-model="notes" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3 min-h-[100px]" placeholder="Note for yourself..."></textarea>
            </div>

            <div class="mb-5">
              <label class="block text-label-bold font-label-bold mb-1.5 text-xs">Video Walkthrough URL (Loom/Drive)</label>
              <input v-model="walkthroughUrl" class="w-full rounded-xl border border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all text-xs p-2.5 bg-surface-container-lowest" placeholder="https://loom.com/share/..." type="url" />
            </div>

            <div class="mb-5">
              <label class="block text-label-bold font-label-bold mb-1.5 text-xs">Catatan Logika & Cheatsheet Dosen</label>
              <textarea v-model="walkthroughNotes" class="w-full rounded-xl border border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all text-xs p-2.5 min-h-[70px] bg-surface-container-lowest" placeholder="Penjelasan cara kerja kode, konsep controller/model..."></textarea>
            </div>

            <div class="mb-4">
              <label class="block text-label-bold font-label-bold mb-2">Kampus</label>
              <input v-model="campus" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3" placeholder="mis. Binus, Telkom" />
              <p class="text-[11px] text-secondary mt-1">Dipakai untuk filter kampus di Dashboard.</p>
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Stack / Teknologi</label>
              <input v-model="stack" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3" placeholder="mis. Vue 3 + Supabase" />
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Sumber Klien</label>
              <select v-model="source" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3 bg-surface-white">
                <option v-for="(label, key) in SOURCE_LABELS" :key="key" :value="key">{{ label }}</option>
              </select>
              <p class="text-[11px] text-secondary mt-1">Dipakai untuk membandingkan kanal di Dashboard.</p>
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Update Status</label>
              <select v-model="status" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3 bg-surface-white capitalize">
                <option value="consultation">Consultation</option>
                <option value="working">Sedang dikerjakan</option>
                <option value="review">Menunggu review</option>
                <option value="done">Done</option>
                <option value="paid">Paid</option>
              </select>
            </div>

            <div v-if="savedMsg" class="mb-4 text-success-green font-label-bold text-sm">{{ savedMsg }}</div>

            <button
              class="w-full bg-electric-blue hover:bg-primary text-white font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all shadow-md disabled:opacity-60 mb-3"
              :disabled="saving"
              @click="save"
            >
              {{ saving ? 'Menyimpan...' : 'Simpan Perubahan' }}
            </button>

            <button
              @click="copySowInvoice"
              class="w-full bg-surface-white border-2 border-electric-blue text-electric-blue hover:bg-primary-fixed/20 font-label-bold text-xs py-3 rounded-xl flex items-center justify-center gap-1.5 transition-all shadow-2xs mb-4"
            >
              <span class="material-symbols-outlined text-[18px]">receipt_long</span>
              {{ copySowSuccess ? '✓ SOW & Invoice Tersalin!' : 'Salin SOW & Invoice DP 50% (WA)' }}
            </button>

            <div class="space-y-3">
              <a
                :href="waLink('62' + (request.whatsapp || ''), `Halo ${request.customer_name}, ini engineer jokitugasit.my.id untuk ${request.order_no}.`)"
                target="_blank"
                rel="noopener"
                class="w-full bg-[#25D366] hover:bg-[#1EBE5D] text-white font-label-bold text-label-bold py-3 rounded-xl flex items-center justify-center gap-2 active:scale-95 transition-all shadow-md"
              >
                <span class="material-symbols-outlined">chat</span>
                Chat WhatsApp
              </a>
              <div class="grid grid-cols-2 gap-3 pt-4 border-t border-border-subtle">
                <button class="bg-electric-blue hover:bg-primary text-white font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all text-center" @click="setStatus('working')">Mark as Working</button>
                <button class="bg-success-green hover:bg-green-600 text-white font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all text-center flex items-center justify-center gap-1" @click="setStatus('done')">
                  <span class="material-symbols-outlined text-sm">done_all</span> Done
                </button>
              </div>
              <button class="w-full bg-transparent border border-electric-blue text-electric-blue hover:bg-surface-container-low font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all text-center mt-2" @click="openSettlement">
                Catat Pelunasan
              </button>
              <p class="text-[11px] text-secondary text-center pt-1">
                Status lunas diatur otomatis oleh pembayaran yang tercatat.
              </p>
            </div>
          </section>

          <!-- Pembayaran & Komisi -->
          <section ref="paymentsSection" class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6">
            <div class="flex items-center justify-between border-b border-border-subtle pb-4 mb-4">
              <h2 class="text-headline-md font-headline-md flex items-center gap-2">
                <span class="material-symbols-outlined text-electric-blue">payments</span>
                Pembayaran &amp; Komisi
              </h2>
              <span v-if="request.referral_code" class="text-[11px] font-mono px-2 py-1 rounded-full bg-primary-fixed/30 text-electric-blue">
                {{ request.referral_code }}
              </span>
            </div>

            <div v-if="moneyError" class="mb-4 rounded-lg border border-urgency-red/30 bg-error-container p-3 text-xs text-on-error-container">
              {{ moneyError }}
              <button class="block mt-2 font-bold underline" @click="loadMoney">Coba lagi</button>
            </div>

            <div v-if="moneyLoading" class="py-6 text-center text-secondary text-sm">
              Memuat pembayaran…
            </div>

            <template v-else-if="!moneyError">
              <dl class="grid grid-cols-3 gap-2 text-center mb-4">
                <div class="rounded-lg bg-surface-container-low p-3">
                  <dt class="text-[10px] uppercase tracking-wide text-secondary">Total</dt>
                  <dd class="font-bold text-sm mt-1">{{ formatRupiah(savedTotal) }}</dd>
                </div>
                <div class="rounded-lg bg-surface-container-low p-3">
                  <dt class="text-[10px] uppercase tracking-wide text-secondary">Terbayar</dt>
                  <dd class="font-bold text-sm mt-1 text-success-green">{{ formatRupiah(summary.net) }}</dd>
                </div>
                <div class="rounded-lg bg-surface-container-low p-3">
                  <dt class="text-[10px] uppercase tracking-wide text-secondary">Sisa</dt>
                  <dd class="font-bold text-sm mt-1" :class="remaining > 0 ? 'text-urgency-red' : 'text-success-green'">{{ formatRupiah(remaining) }}</dd>
                </div>
              </dl>

              <div class="flex items-center justify-between text-xs rounded-lg border border-border-subtle px-3 py-2 mb-4">
                <span class="text-secondary">Komisi referral 10%</span>
                <span class="font-bold text-right">
                  {{ commissionStatusText }}
                  <span v-if="commission" class="text-electric-blue">· {{ formatRupiah(commission.amount) }}</span>
                </span>
              </div>

              <div v-if="payMsg" class="mb-3 rounded-lg bg-success-green/10 border border-success-green/30 p-3 text-xs text-on-surface">{{ payMsg }}</div>
              <div v-if="payError" class="mb-3 rounded-lg bg-error-container border border-urgency-red/30 p-3 text-xs text-on-error-container">{{ payError }}</div>

              <div class="space-y-3">
                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label class="block text-[11px] font-bold mb-1">Jenis</label>
                    <select v-model="payForm.kind" class="w-full rounded-lg border border-border-subtle p-2 text-sm bg-surface-white">
                      <option value="DP">DP</option>
                      <option value="SETTLEMENT">Pelunasan</option>
                      <option value="REFUND">Refund</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-[11px] font-bold mb-1">Nominal (Rp)</label>
                    <input v-model="payForm.amount" type="number" min="1" step="1" class="w-full rounded-lg border border-border-subtle p-2 text-sm" placeholder="0" />
                  </div>
                </div>

                <div class="flex gap-2">
                  <button type="button" class="flex-1 text-[11px] font-bold border border-electric-blue text-electric-blue rounded-lg py-1.5 hover:bg-primary-fixed/20 transition-colors" @click="fillDp">Isi DP 50%</button>
                  <button type="button" class="flex-1 text-[11px] font-bold border border-electric-blue text-electric-blue rounded-lg py-1.5 hover:bg-primary-fixed/20 transition-colors" @click="fillRemaining">Isi Sisa</button>
                </div>

                <div class="grid grid-cols-2 gap-2">
                  <div>
                    <label class="block text-[11px] font-bold mb-1">Metode</label>
                    <input v-model="payForm.method" class="w-full rounded-lg border border-border-subtle p-2 text-sm" placeholder="transfer / DANA" />
                  </div>
                  <div>
                    <label class="block text-[11px] font-bold mb-1">Bukti (URL)</label>
                    <input v-model="payForm.proofUrl" class="w-full rounded-lg border border-border-subtle p-2 text-sm" placeholder="https://..." />
                  </div>
                </div>

                <input v-model="payForm.note" class="w-full rounded-lg border border-border-subtle p-2 text-sm" placeholder="Catatan (opsional)" />

                <button
                  class="w-full bg-electric-blue hover:bg-primary text-white font-label-bold text-sm py-2.5 rounded-lg transition-colors disabled:opacity-60"
                  :disabled="paySaving"
                  @click="addPayment"
                >
                  {{ paySaving ? 'Menyimpan…' : 'Catat Pembayaran' }}
                </button>
              </div>

              <div v-if="payments.length" class="mt-5 pt-4 border-t border-border-subtle">
                <p class="text-[11px] uppercase tracking-wide text-secondary mb-2">Riwayat pembayaran</p>
                <div class="space-y-2">
                  <div v-for="p in payments" :key="p.id" class="rounded-lg border border-border-subtle p-2.5">
                    <div class="flex items-center justify-between gap-2">
                      <div class="min-w-0">
                        <p class="text-xs font-bold">
                          {{ PAYMENT_KIND_LABELS[p.kind] || p.kind }} · {{ formatRupiah(p.amount) }}
                        </p>
                        <p class="text-[10px] text-secondary truncate">
                          {{ fmtDate(p.paid_at || p.created_at) }}<span v-if="p.method"> · {{ p.method }}</span>
                          <a v-if="p.proof_url" :href="p.proof_url" target="_blank" rel="noopener" class="underline text-electric-blue ml-1">bukti</a>
                        </p>
                        <p v-if="p.void_reason" class="text-[10px] text-urgency-red mt-1">Dibatalkan: {{ p.void_reason }}</p>
                      </div>
                      <div class="text-right shrink-0">
                        <span class="text-[10px] px-2 py-0.5 rounded-full font-bold" :class="paymentStatusClass(p.status)">
                          {{ PAYMENT_STATUS_LABELS[p.status] || p.status }}
                        </span>
                        <button
                          v-if="p.status === 'CONFIRMED'"
                          class="block mt-1 text-[10px] text-urgency-red underline"
                          @click="cancelPayment(p)"
                        >
                          Batalkan
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <p v-else class="mt-4 text-[11px] text-secondary">
                Belum ada pembayaran tercatat. Status proyek tetap “{{ STATUS_LABELS[request.status] || request.status }}”.
              </p>
            </template>
          </section>
        </div>
      </div>
    </template>
  </SideNav>
</template>