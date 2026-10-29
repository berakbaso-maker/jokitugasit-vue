<script setup>
import { ref, computed, onMounted } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  listPartners, updatePartner, ensureUniqueReferralCode, createPartner,
  listCommissions, markCommissionPaid, formatRupiah, CATEGORY_LABELS
} from '../lib/api'

const partners = ref([])
const commissions = ref([])
const loading = ref(true)
const activeTab = ref('partners') // 'partners' | 'commissions'
const actionError = ref('')

// Add partner modal
const showAddModal = ref(false)
const addForm = ref({ full_name: '', whatsapp: '', campus: '', ewallet_info: '' })
const addError = ref('')
const adding = ref(false)

// Commission filter
const filterPartnerCode = ref('')

const COMMISSION_STATUS = {
  PENDING: { label: 'Menunggu Lunas', class: 'bg-surface-container text-on-surface-variant' },
  ELIGIBLE: { label: 'Siap Dibayar', class: 'bg-urgency-red/10 text-urgency-red' },
  PAID: { label: 'Sudah Dibayar', class: 'bg-success-green/10 text-success-green' },
  VOID: { label: 'Batal', class: 'bg-surface-container text-on-surface-variant' },
  ADJUSTMENT: { label: 'Perlu Review', class: 'bg-amber-100 text-amber-700' },
}

const statusMeta = (s) => COMMISSION_STATUS[s] || COMMISSION_STATUS.PENDING

// Semua nominal berasal dari database (integer rupiah), tidak dihitung di sini.
const filteredCommissions = computed(() => {
  if (!filterPartnerCode.value) return commissions.value
  return commissions.value.filter(c => c.partners?.referral_code === filterPartnerCode.value)
})

const totalOutstanding = computed(() =>
  commissions.value
    .filter(c => c.status === 'ELIGIBLE')
    .reduce((sum, c) => sum + Number(c.amount || 0), 0)
)

const totalPaid = computed(() =>
  commissions.value
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
    actionError.value = err.message || 'Gagal memuat data partner.'
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
    const wa = addForm.value.whatsapp.replace(/[^0-9]/g, '')
    const waNum = wa.startsWith('0') ? '62' + wa.slice(1) : wa.startsWith('62') ? wa : '62' + wa
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
  } catch (err) {
    addError.value = 'Gagal tambah partner: ' + (err.message || 'Coba lagi.')
  } finally {
    adding.value = false
  }
}

async function payCommission(commission) {
  if (commission.status === 'PAID') return
  actionError.value = ''
  try {
    const updated = await markCommissionPaid(commission.id)
    Object.assign(commission, updated)
  } catch (err) {
    actionError.value = err.message || 'Gagal menandai komisi lunas.'
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
        class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold text-label-bold px-5 py-2.5 rounded-xl hover:bg-primary transition-colors shadow-sm">
        <span class="material-symbols-outlined text-[20px]">person_add</span>
        Tambah Partner
      </button>
    </div>

    <!-- Error -->
    <div v-if="actionError" class="mb-5 flex items-start gap-2 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-on-error-container">
      <span class="material-symbols-outlined text-[18px]">error</span>
      <span class="text-sm">{{ actionError }}</span>
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
              <button v-if="c.status === 'ELIGIBLE'" @click="payCommission(c)"
                class="inline-flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-electric-blue text-white hover:bg-primary transition-colors">
                <span class="material-symbols-outlined text-[14px]">payments</span>
                Tandai Lunas
              </button>
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
            <button type="submit" :disabled="adding" class="flex-1 px-4 py-2.5 rounded-xl bg-electric-blue text-white font-bold text-sm hover:bg-primary transition-colors disabled:opacity-60">
              {{ adding ? 'Menyimpan...' : 'Tambah Partner' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </SideNav>
</template>
