<script setup>
import { ref, computed, onMounted } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  listPartners, updatePartner, ensureUniqueReferralCode, createPartner,
  listCommissions, markCommissionPaid, rotatePartnerCode, formatRupiah, CATEGORY_LABELS,
} from '../lib/api'
import { downloadCsv, toCsv } from '../lib/csv'
import { pesanGalat } from '../lib/galat'

const partners = ref([])
const commissions = ref([])
const loading = ref(true)
const activeTab = ref('partners') // 'partners' | 'commissions'
const actionError = ref('')
const actionNotice = ref('')

// Add partner modal
const showAddModal = ref(false)
const addForm = ref({ full_name: '', whatsapp: '', campus: '', ewallet_info: '' })
const addError = ref('')
const adding = ref(false)

// Edit partner modal
const showEditModal = ref(false)
const editTarget = ref(null)
const editForm = ref({ full_name: '', whatsapp: '', campus: '', ewallet_info: '', notes: '' })
const editError = ref('')
const savingEdit = ref(false)
const rotating = ref(false)

// Payout modal
const payTarget = ref(null)
const payForm = ref({ proofUrl: '', note: '' })
const payError = ref('')
const paySaving = ref(false)

// Filters
const filterPartnerCode = ref('')
const commissionPeriod = ref('all')
const exporting = ref(false)

const PERIOD_OPTIONS = [
  { value: 'all', label: 'Semua waktu' },
  { value: '30d', label: '30 hari' },
  { value: 'month', label: 'Bulan ini' },
]

const COMMISSION_STATUS = {
  PENDING: { label: 'Menunggu Lunas', class: 'bg-surface-container text-on-surface-variant' },
  ELIGIBLE: { label: 'Siap Dibayar', class: 'bg-urgency-red/10 text-urgency-red' },
  PAID: { label: 'Sudah Dibayar', class: 'bg-success-green/10 text-success-green' },
  VOID: { label: 'Batal', class: 'bg-surface-container text-on-surface-variant' },
  ADJUSTMENT: { label: 'Perlu Review', class: 'bg-amber-100 text-amber-700' },
}

const statusMeta = (s) => COMMISSION_STATUS[s] || COMMISSION_STATUS.PENDING

function normalizeWa(value) {
  const wa = String(value || '').replace(/[^0-9]/g, '')
  if (!wa) return ''
  return wa.startsWith('0') ? '62' + wa.slice(1) : wa.startsWith('62') ? wa : '62' + wa
}

/** Batas awal periode, atau null untuk semua waktu. */
function periodStart() {
  if (commissionPeriod.value === 'all') return null
  const now = new Date()
  if (commissionPeriod.value === 'month') return new Date(now.getFullYear(), now.getMonth(), 1)
  const d = new Date(now)
  d.setDate(d.getDate() - 29)
  return d
}

const periodCommissions = computed(() => {
  const from = periodStart()
  if (!from) return commissions.value
  return commissions.value.filter(c => c.created_at && new Date(c.created_at) >= from)
})

// Nominal berasal dari database (integer rupiah), tidak dihitung ulang di sini.
const filteredCommissions = computed(() => {
  if (!filterPartnerCode.value) return periodCommissions.value
  return periodCommissions.value.filter(c => c.partners?.referral_code === filterPartnerCode.value)
})

const totalOutstanding = computed(() =>
  filteredCommissions.value
    .filter(c => c.status === 'ELIGIBLE')
    .reduce((sum, c) => sum + Number(c.amount || 0), 0)
)

const totalPaid = computed(() =>
  filteredCommissions.value
    .filter(c => c.status === 'PAID')
    .reduce((sum, c) => sum + Number(c.amount || 0), 0)
)

const uniquePartnerCodes = computed(() => {
  const codes = [...new Set(commissions.value.map(c => c.partners?.referral_code).filter(Boolean))]
  return codes
})

const commissionForPartner = (partnerId) =>
  commissions.value
    .filter(c => c.partner_id === partnerId && ['ELIGIBLE', 'PAID'].includes(c.status))
    .reduce((sum, c) => sum + Number(c.amount || 0), 0)

const referralCountForPartner = (partnerId) =>
  commissions.value.filter(c => c.partner_id === partnerId).length

async function load() {
  loading.value = true
  try {
    ;[partners.value, commissions.value] = await Promise.all([listPartners(), listCommissions()])
  } catch (err) {
    console.error(err)
    actionError.value = pesanGalat(err, 'Gagal memuat data partner.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function toggleStatus(partner) {
  const newStatus = partner.status === 'active' ? 'inactive' : 'active'
  await updatePartner(partner.id, { status: newStatus })
  partner.status = newStatus
}

async function handleAddPartner() {
  addError.value = ''
  if (!addForm.value.full_name.trim() || !addForm.value.whatsapp.trim()) {
    addError.value = 'Nama dan WhatsApp wajib diisi.'
    return
  }
  adding.value = true
  try {
    const waNum = normalizeWa(addForm.value.whatsapp)
    const code = await ensureUniqueReferralCode(addForm.value.full_name)
    const newPartner = await createPartner({
      full_name: addForm.value.full_name.trim(),
      whatsapp: waNum,
      campus: addForm.value.campus.trim() || null,
      ewallet_info: addForm.value.ewallet_info.trim() || null,
      referral_code: code,
    })
    partners.value.unshift(newPartner)
    showAddModal.value = false
    addForm.value = { full_name: '', whatsapp: '', campus: '', ewallet_info: '' }
    actionNotice.value = `Partner ${newPartner.full_name} ditambahkan dengan kode ${newPartner.referral_code}.`
  } catch (err) {
    addError.value = 'Gagal tambah partner: ' + pesanGalat(err, 'Coba lagi.')
  } finally {
    adding.value = false
  }
}

function openEdit(partner) {
  editTarget.value = partner
  editForm.value = {
    full_name: partner.full_name || '',
    whatsapp: partner.whatsapp || '',
    campus: partner.campus || '',
    ewallet_info: partner.ewallet_info || '',
    notes: partner.notes || '',
  }
  editError.value = ''
  showEditModal.value = true
}

async function rotateCode() {
  if (!editTarget.value) return
  const ok = window.confirm(
    'Ganti kode referral?\n\nKode lama langsung tidak berlaku dan klien yang membuka tautan lama tidak akan mendapat atribusi. Proyek yang sudah tercatat tidak terpengaruh.',
  )
  if (!ok) return

  rotating.value = true
  editError.value = ''
  try {
    const code = await rotatePartnerCode(editTarget.value.id)
    editTarget.value.referral_code = code
    const idx = partners.value.findIndex(p => p.id === editTarget.value.id)
    if (idx !== -1) partners.value[idx].referral_code = code
    actionNotice.value = `Kode referral baru: ${code}. Bagikan ulang ke partner.`
  } catch (err) {
    editError.value = pesanGalat(err, 'Gagal mengganti kode referral.')
  } finally {
    rotating.value = false
  }
}

async function saveEdit() {
  editError.value = ''
  if (!editForm.value.full_name.trim() || !editForm.value.whatsapp.trim()) {
    editError.value = 'Nama dan WhatsApp wajib diisi.'
    return
  }
  savingEdit.value = true
  try {
    const updated = await updatePartner(editTarget.value.id, {
      full_name: editForm.value.full_name.trim(),
      whatsapp: normalizeWa(editForm.value.whatsapp),
      campus: editForm.value.campus.trim() || null,
      ewallet_info: editForm.value.ewallet_info.trim() || null,
      notes: editForm.value.notes.trim() || null,
    })
    const idx = partners.value.findIndex(p => p.id === updated.id)
    if (idx !== -1) partners.value[idx] = updated
    showEditModal.value = false
    actionNotice.value = `Data partner ${updated.full_name} diperbarui. Kode referral tidak berubah.`
  } catch (err) {
    editError.value = pesanGalat(err, 'Gagal menyimpan perubahan.')
  } finally {
    savingEdit.value = false
  }
}

function openPay(commission) {
  payTarget.value = commission
  payForm.value = { proofUrl: '', note: '' }
  payError.value = ''
}

async function confirmPay() {
  if (!payTarget.value) return
  payError.value = ''
  const partnerLabel = payTarget.value.partners?.full_name || 'partner'
  paySaving.value = true
  try {
    const updated = await markCommissionPaid(payTarget.value.id, {
      proofUrl: payForm.value.proofUrl.trim() || null,
      note: payForm.value.note.trim() || null,
    })
    Object.assign(payTarget.value, updated)
    actionNotice.value = `Komisi ${formatRupiah(updated.amount)} untuk ${partnerLabel} ditandai lunas.`
    payTarget.value = null
  } catch (err) {
    payError.value = pesanGalat(err, 'Gagal menandai komisi lunas.')
  } finally {
    paySaving.value = false
  }
}

function exportCommissions() {
  exporting.value = true
  try {
    const rows = filteredCommissions.value.map(c => ({
      order_no: c.requests?.order_no || '',
      customer: c.requests?.customer_name || '',
      partner: c.partners?.full_name || '',
      referral_code: c.partners?.referral_code || '',
      category: c.requests?.category || '',
      project_value: Number(c.requests?.quote_amount || 0) - Number(c.requests?.discount_amount || 0),
      eligible_amount: c.eligible_amount,
      rate_percent: Number(c.rate_bps || 0) / 100,
      commission: c.amount,
      status: c.status,
      created_at: c.created_at || '',
      paid_at: c.paid_at || '',
      proof: c.payment_proof || '',
    }))
    downloadCsv(
      `komisi-${new Date().toISOString().slice(0, 10)}.csv`,
      toCsv(rows, ['order_no', 'customer', 'partner', 'referral_code', 'category',
        'project_value', 'eligible_amount', 'rate_percent', 'commission',
        'status', 'created_at', 'paid_at', 'proof']),
    )
    actionNotice.value = `${rows.length} baris komisi diekspor.`
  } catch (err) {
    actionError.value = pesanGalat(err, 'Gagal mengekspor komisi.')
  } finally {
    exporting.value = false
  }
}

function partnerName(code) {
  const p = partners.value.find(p => p.referral_code === code)
  return p ? p.full_name : code
}

function partnerWa(code) {
  const p = partners.value.find(p => p.referral_code === code)
  return p ? p.whatsapp : null
}

function waLink(wa) {
  return `https://wa.me/${wa}`
}
</script>

<template>
  <SideNav>
    <!-- Header -->
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
      <div>
        <h1 class="text-headline-md font-headline-md font-bold text-on-surface">Partner Referral</h1>
        <p class="text-body-md font-body-md text-secondary mt-1">Kelola partner dan tracking komisi 10% per transaksi.</p>
      </div>
      <button @click="showAddModal = true"
        class="inline-flex items-center gap-2 bg-accent-fill text-white font-label-bold text-label-bold px-5 py-2.5 rounded-xl hover:bg-accent-fill transition-colors shadow-sm">
        <span class="material-symbols-outlined text-[20px]">person_add</span>
        Tambah Partner
      </button>
    </div>

    <!-- Error -->
    <div v-if="actionError" class="mb-5 flex items-start gap-2 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-on-error-container">
      <span class="material-symbols-outlined text-[18px]">error</span>
      <span class="text-sm">{{ actionError }}</span>
    </div>

    <div v-if="actionNotice" class="mb-5 flex items-start gap-2 rounded-xl border border-success-green/30 bg-success-green/10 p-4">
      <span class="material-symbols-outlined text-[18px] text-success-green">check_circle</span>
      <span class="text-sm">{{ actionNotice }}</span>
    </div>

    <!-- Stats Row -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      <div class="bg-surface-white rounded-xl p-5 border border-border-subtle">
        <p class="text-label-sm font-label-sm text-on-surface-variant mb-1">Total Partner</p>
        <p class="text-2xl font-bold text-on-surface">{{ partners.length }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-5 border border-border-subtle">
        <p class="text-label-sm font-label-sm text-on-surface-variant mb-1">Partner Aktif</p>
        <p class="text-2xl font-bold text-success-green">{{ partners.filter(p => p.status === 'active').length }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-5 border border-border-subtle">
        <p class="text-label-sm font-label-sm text-on-surface-variant mb-1">Komisi Sudah Dibayar</p>
        <p class="text-2xl font-bold text-on-surface">{{ formatRupiah(totalPaid) }}</p>
      </div>
      <div class="bg-electric-blue/5 border border-electric-blue/20 rounded-xl p-5">
        <p class="text-label-sm font-label-sm text-electric-blue mb-1">Komisi Siap Dibayar</p>
        <p class="text-2xl font-bold text-electric-blue">{{ formatRupiah(totalOutstanding) }}</p>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 bg-surface-container p-1 rounded-xl mb-6 w-fit">
      <button @click="activeTab = 'partners'" :class="activeTab === 'partners' ? 'bg-surface-white shadow text-on-surface' : 'text-on-surface-variant hover:text-on-surface'"
        class="px-5 py-2 rounded-lg font-bold text-sm transition-all">
        Partner List
      </button>
      <button @click="activeTab = 'commissions'" :class="activeTab === 'commissions' ? 'bg-surface-white shadow text-on-surface' : 'text-on-surface-variant hover:text-on-surface'"
        class="px-5 py-2 rounded-lg font-bold text-sm transition-all flex items-center gap-1.5">
        Komisi Tracker
        <span v-if="totalOutstanding > 0" class="w-2 h-2 rounded-full bg-urgency-red"></span>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-16 text-on-surface-variant">
      <span class="material-symbols-outlined text-[40px] animate-spin">progress_activity</span>
    </div>

    <!-- Partners Tab -->
    <div v-else-if="activeTab === 'partners'">
      <div v-if="partners.length === 0" class="text-center py-16 text-on-surface-variant">
        <span class="material-symbols-outlined text-[48px] mb-3 block">group_add</span>
        <p class="font-bold">Belum ada partner terdaftar.</p>
        <p class="text-sm mt-1">Rekrut partner pertamamu atau tunggu daftar dari halaman /partner.</p>
      </div>
      <div v-else class="space-y-3">
        <div v-for="p in partners" :key="p.id"
          class="bg-surface-white rounded-xl border border-border-subtle p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:border-electric-blue/20 transition-colors">
          <div class="flex items-center gap-4">
            <div class="w-11 h-11 rounded-xl bg-primary-fixed/40 flex items-center justify-center flex-shrink-0">
              <span class="material-symbols-outlined text-electric-blue" style="font-variation-settings: 'FILL' 1">person</span>
            </div>
            <div>
              <p class="font-bold text-on-surface">{{ p.full_name }}</p>
              <p class="text-sm text-on-surface-variant">{{ p.campus || '—' }} · <a :href="`https://wa.me/${p.whatsapp}`" target="_blank" class="text-electric-blue hover:underline">{{ p.whatsapp }}</a></p>
              <p class="text-xs text-on-surface-variant mt-0.5">{{ p.ewallet_info || 'E-wallet belum diisi' }}</p>
            </div>
          </div>
          <div class="flex items-center gap-3 flex-wrap sm:flex-nowrap">
            <div class="bg-primary-fixed/30 text-electric-blue font-mono font-bold text-sm px-3 py-1.5 rounded-lg tracking-wide">
              {{ p.referral_code }}
            </div>
            <div class="text-center">
              <p class="text-xs text-on-surface-variant">Referrals</p>
              <p class="font-bold text-on-surface">{{ referralCountForPartner(p.id) }}</p>
            </div>
            <div class="text-center">
              <p class="text-xs text-on-surface-variant">Komisi</p>
              <p class="font-bold text-electric-blue text-sm">{{ formatRupiah(commissionForPartner(p.id)) }}</p>
            </div>
            <button @click="toggleStatus(p)"
              :class="p.status === 'active' ? 'bg-success-green/10 text-success-green' : 'bg-surface-container text-on-surface-variant'"
              class="text-xs font-bold px-3 py-1.5 rounded-lg">
              {{ p.status === 'active' ? 'Aktif' : 'Nonaktif' }}
            </button>
            <button @click="openEdit(p)"
              class="text-xs font-bold px-3 py-1.5 rounded-lg border border-outline-variant text-on-surface-variant hover:bg-surface-container-low">
              Edit
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Commissions Tab -->
    <div v-else-if="activeTab === 'commissions'">
      <div class="flex flex-col sm:flex-row gap-3 mb-5">
        <select v-model="filterPartnerCode"
          class="rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5 text-on-surface text-sm focus:outline-none focus:ring-2 focus:ring-electric-blue/40">
          <option value="">Semua Partner</option>
          <option v-for="code in uniquePartnerCodes" :key="code" :value="code">{{ partnerName(code) }} ({{ code }})</option>
        </select>
        <select v-model="commissionPeriod"
          class="rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5 text-on-surface text-sm focus:outline-none focus:ring-2 focus:ring-electric-blue/40">
          <option v-for="opt in PERIOD_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
        <button @click="exportCommissions" :disabled="exporting || filteredCommissions.length === 0"
          class="inline-flex items-center justify-center gap-2 rounded-xl border border-outline-variant px-4 py-2.5 text-sm font-bold hover:bg-surface-container-low disabled:opacity-50">
          <span class="material-symbols-outlined text-[18px]">download</span>
          {{ exporting ? 'Mengekspor...' : 'Ekspor CSV' }}
        </button>
      </div>

      <div v-if="filteredCommissions.length === 0" class="text-center py-16 text-on-surface-variant">
        <span class="material-symbols-outlined text-[48px] mb-3 block">receipt_long</span>
        <p class="font-bold">Belum ada komisi tercatat.</p>
        <p class="text-sm mt-1">Komisi muncul otomatis setelah proyek dengan kode referral lunas.</p>
      </div>

      <div v-else class="space-y-3">
        <div v-for="c in filteredCommissions" :key="c.id"
          class="bg-surface-white rounded-xl border p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4"
          :class="c.status === 'PAID' ? 'border-success-green/20' : 'border-border-subtle'">
          <div>
            <div class="flex items-center gap-2 mb-1 flex-wrap">
              <p class="font-bold text-on-surface">{{ c.requests?.order_no }} — {{ c.requests?.customer_name }}</p>
              <span :class="statusMeta(c.status).class"
                class="text-[11px] font-bold px-2 py-0.5 rounded-full">
                {{ statusMeta(c.status).label }}
              </span>
            </div>
            <p class="text-sm text-on-surface-variant">
              Partner: <span class="font-bold text-on-surface">{{ c.partners?.full_name || '—' }}</span>
              ({{ c.partners?.referral_code }})
            </p>
            <p class="text-sm text-on-surface-variant">
              Kategori: {{ CATEGORY_LABELS[c.requests?.category] || c.requests?.category }} ·
              Nilai proyek: <span class="font-bold text-on-surface">{{ formatRupiah(c.requests?.quote_amount) }}</span>
            </p>
          </div>
          <div class="flex flex-col items-end gap-2">
            <div class="text-right">
              <p class="text-xs text-on-surface-variant">Komisi 10% (dari database)</p>
              <p class="text-lg font-bold text-electric-blue">{{ formatRupiah(c.amount) }}</p>
              <p v-if="c.status === 'PENDING'" class="text-[11px] text-on-surface-variant">Baru dihitung setelah pelunasan</p>
            </div>
            <div class="flex gap-2">
              <a v-if="c.partners?.whatsapp" :href="waLink(c.partners.whatsapp)" target="_blank"
                class="inline-flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-success-green/10 text-success-green hover:bg-success-green/20 transition-colors">
                <span class="material-symbols-outlined text-[14px]">chat</span>
                WA Partner
              </a>
              <button v-if="c.status === 'ELIGIBLE'" @click="openPay(c)"
                class="inline-flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-accent-fill text-white hover:bg-accent-fill transition-colors">
                <span class="material-symbols-outlined text-[14px]">payments</span>
                Tandai Lunas
              </button>
              <a v-if="c.status === 'PAID' && c.payment_proof" :href="c.payment_proof" target="_blank" rel="noopener"
                class="inline-flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-surface-container text-on-surface-variant hover:bg-surface-container-high">
                <span class="material-symbols-outlined text-[14px]">receipt_long</span>
                Bukti
              </a>
              <a v-if="c.status === 'ADJUSTMENT'" :href="waLink(c.partners?.whatsapp || '')" target="_blank"
                class="inline-flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-amber-100 text-amber-700">
                <span class="material-symbols-outlined text-[14px]">support_agent</span>
                Review Manual
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Partner Modal -->
    <div v-if="showAddModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4" @click.self="showAddModal = false">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex items-center justify-between mb-5">
          <h2 class="font-bold text-on-surface text-lg">Tambah Partner Manual</h2>
          <button @click="showAddModal = false" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <form @submit.prevent="handleAddPartner" class="space-y-4">
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Nama Lengkap *</label>
            <input v-model="addForm.full_name" type="text" required placeholder="Nama partner" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">WhatsApp *</label>
            <input v-model="addForm.whatsapp" type="tel" required placeholder="08xxxx" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Kampus</label>
            <input v-model="addForm.campus" type="text" placeholder="Binus, Telkom..." class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Info E-wallet/Rekening</label>
            <input v-model="addForm.ewallet_info" type="text" placeholder="GoPay/OVO/Dana: 08xxx" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-on-surface focus:outline-none focus:ring-2 focus:ring-electric-blue/40">
          </div>
          <p v-if="addError" class="text-sm text-urgency-red">{{ addError }}</p>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showAddModal = false" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant text-on-surface-variant font-bold text-sm hover:bg-surface-container transition-colors">Batal</button>
            <button type="submit" :disabled="adding" class="flex-1 px-4 py-2.5 rounded-xl bg-accent-fill text-white font-bold text-sm hover:bg-accent-fill transition-colors disabled:opacity-60">
              {{ adding ? 'Menyimpan...' : 'Tambah Partner' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Edit Partner Modal -->
    <div v-if="showEditModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4" @click.self="showEditModal = false">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex items-center justify-between mb-2">
          <h2 class="font-bold text-on-surface text-lg">Edit Partner</h2>
          <button @click="showEditModal = false" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <div class="flex items-center justify-between gap-2 mb-4 rounded-xl bg-surface-container-low px-3 py-2">
          <span class="text-xs font-mono font-bold text-electric-blue">{{ editTarget?.referral_code }}</span>
          <button
            type="button"
            @click="rotateCode"
            :disabled="rotating"
            class="text-[11px] font-bold text-urgency-red hover:underline disabled:opacity-50"
          >
            {{ rotating ? 'Mengganti...' : 'Ganti kode' }}
          </button>
        </div>
        <form @submit.prevent="saveEdit" class="space-y-4">
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Nama Lengkap *</label>
            <input v-model="editForm.full_name" type="text" required class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">WhatsApp *</label>
            <input v-model="editForm.whatsapp" type="tel" required class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            <p class="text-[11px] text-on-surface-variant mt-1">Disimpan sebagai: <span class="font-mono">{{ normalizeWa(editForm.whatsapp) || '—' }}</span></p>
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Kampus</label>
            <input v-model="editForm.campus" type="text" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Info E-wallet/Rekening</label>
            <input v-model="editForm.ewallet_info" type="text" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Catatan</label>
            <textarea v-model="editForm.notes" rows="2" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm resize-none"></textarea>
          </div>
          <p v-if="editError" class="text-sm text-urgency-red">{{ editError }}</p>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showEditModal = false" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant font-bold text-sm">Batal</button>
            <button type="submit" :disabled="savingEdit" class="flex-1 px-4 py-2.5 rounded-xl bg-accent-fill text-white font-bold text-sm disabled:opacity-60">
              {{ savingEdit ? 'Menyimpan...' : 'Simpan Perubahan' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Payout Modal -->
    <div v-if="payTarget" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4" @click.self="payTarget = null">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-bold text-on-surface text-lg">Tandai Komisi Lunas</h2>
          <button @click="payTarget = null" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <div class="rounded-xl bg-surface-container-low p-4 mb-4 text-sm">
          <p class="font-bold">{{ payTarget.partners?.full_name || 'Partner' }} · {{ payTarget.partners?.referral_code }}</p>
          <p class="text-on-surface-variant text-xs mt-1">{{ payTarget.requests?.order_no }} — {{ payTarget.requests?.customer_name }}</p>
          <p class="text-electric-blue font-bold text-lg mt-2">{{ formatRupiah(payTarget.amount) }}</p>
          <p v-if="payTarget.partners?.ewallet_info" class="text-[11px] text-on-surface-variant mt-1">Tujuan: {{ payTarget.partners.ewallet_info }}</p>
        </div>
        <form @submit.prevent="confirmPay" class="space-y-3">
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Bukti transfer (URL, opsional)</label>
            <input v-model="payForm.proofUrl" type="url" placeholder="https://..." class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <div>
            <label class="text-label-sm font-label-sm text-on-surface-variant block mb-1">Catatan (opsional)</label>
            <input v-model="payForm.note" type="text" placeholder="mis. transfer DANA 29 Okt" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <p class="text-[11px] text-on-surface-variant">Pastikan transfer benar-benar sudah dilakukan. Status tidak bisa dikembalikan dari UI.</p>
          <p v-if="payError" class="text-sm text-urgency-red">{{ payError }}</p>
          <div class="flex gap-3 pt-1">
            <button type="button" @click="payTarget = null" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant font-bold text-sm">Batal</button>
            <button type="submit" :disabled="paySaving" class="flex-1 px-4 py-2.5 rounded-xl bg-accent-fill text-white font-bold text-sm disabled:opacity-60">
              {{ paySaving ? 'Menyimpan...' : 'Konfirmasi Lunas' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </SideNav>
</template>
