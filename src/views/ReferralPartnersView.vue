<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import DataTable from '../components/ui/DataTable.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import AppModal from '../components/ui/AppModal.vue'
import {
  listAttributions, listCommissions, createTask,
} from '../lib/internal'
import { listPartners, updatePartner, ensureUniqueReferralCode } from '../lib/api'
import { formatRupiah } from '../lib/api'
import { pesanGalat } from '../lib/galat'

const loading = ref(true)
const error = ref('')
const partners = ref([])
const attributions = ref([])
const commissions = ref([])
const showForm = ref(false)
const saving = ref(false)
const formError = ref('')
const form = ref({ full_name: '', whatsapp: '', campus: '', ewallet_info: '', notes: '' })

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [p, a, c] = await Promise.all([
      listPartners(),
      listAttributions().catch(() => []),
      listCommissions().catch(() => []),
    ])
    partners.value = p || []
    attributions.value = a || []
    commissions.value = c || []
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  } finally {
    loading.value = false
  }
}
onMounted(load)

const stats = computed(() => {
  const active = partners.value.filter(p => p.status === 'active')
  const conv = attributions.value.filter(a => a.status === 'CONVERTED')
  const pending = commissions.value.filter(c => ['PENDING', 'ELIGIBLE'].includes(c.status))
  return {
    total: partners.value.length,
    active: active.length,
    conversions: conv.length,
    liability: pending.reduce((s, c) => s + Number(c.amount || 0), 0),
  }
})

const columns = [
  { key: 'full_name', label: 'Partner', sortable: true },
  { key: 'referral_code', label: 'Kode', sortable: true },
  { key: 'rate', label: 'Komisi', align: 'right' },
  { key: 'conversions', label: 'Konversi', align: 'right', sortable: true },
  { key: 'earned', label: 'Total komisi', align: 'right', sortable: true },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'actions', label: '', align: 'right', width: '120px' },
]

const rows = computed(() => partners.value.map(p => {
  const mine = commissions.value.filter(c => c.partner_id === p.id)
  const earned = mine
    .filter(c => ['PAID', 'ELIGIBLE'].includes(c.status))
    .reduce((s, c) => s + Number(c.amount || 0), 0)
  return {
    ...p,
    rate: (p.commission_rate ?? 10) + '%',
    conversions: attributions.value.filter(a => a.partner_id === p.id && a.status === 'CONVERTED').length,
    earned,
  }
}))

async function approve(p) {
  try {
    const code = p.referral_code || await ensureUniqueReferralCode()
    await updatePartner(p.id, { status: 'active', referral_code: code })
    // Automation: partner.approved -> task review
    await createTask({
      title: `Review partner baru: ${p.full_name}`,
      detail: `Partner aktif dengan kode ${code}. Verifikasi data dan kirim panduan program 10%.`,
      status: 'OPEN', priority: 'MEDIUM',
    }).catch(() => {})
    await load()
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  }
}

async function suspend(p) {
  if (!confirm(`Nonaktifkan partner "${p.full_name}"? Referral baru tidak akan tercatat.`)) return
  try {
    await updatePartner(p.id, { status: 'inactive' })
    await load()
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  }
}

async function createPartner() {
  formError.value = ''
  if (!form.value.full_name?.trim()) {
    formError.value = 'Nama partner wajib diisi.'
    return
  }
  if (!form.value.whatsapp?.trim()) {
    formError.value = 'Nomor WhatsApp wajib diisi (dipakai untuk payout).'
    return
  }
  saving.value = true
  try {
    const code = await ensureUniqueReferralCode()
    const { supabase } = await import('../lib/supabase')
    const { error: err } = await supabase.from('partners').insert({
      full_name: form.value.full_name.trim(),
      whatsapp: form.value.whatsapp.trim(),
      campus: form.value.campus || null,
      ewallet_info: form.value.ewallet_info || null,
      notes: form.value.notes || null,
      referral_code: code,
      status: 'active',
    })
    if (err) throw err
    showForm.value = false
    form.value = { full_name: '', whatsapp: '', campus: '', ewallet_info: '', notes: '' }
    await load()
  } catch (e) {
    formError.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  } finally {
    saving.value = false
  }
}

const attrRows = computed(() => attributions.value.map(a => ({
  ...a,
  partner: a.partners?.full_name || '—',
  code: a.partners?.referral_code || '—',
  created_at: a.created_at ? new Date(a.created_at).toLocaleDateString('id-ID') : '—',
})))

const attrCols = [
  { key: 'partner', label: 'Partner', sortable: true },
  { key: 'code', label: 'Kode' },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'created_at', label: 'Tanggal', sortable: true },
]
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 6"
      title="Referral Partners"
      description="Program referral 10% dari pendapatan bersih proyek yang memenuhi syarat. Komisi hanya lahir dari pembayaran terverifikasi — bukan dari lead atau klik."
    >
      <template #actions>
        <button class="inline-flex items-center gap-2 bg-accent-fill text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary-container transition-colors" @click="showForm = true">
          <span class="material-symbols-outlined text-[18px]">person_add</span>
          Partner baru
        </button>
      </template>
    </PageHeader>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <KpiCard label="Total partner" :value="stats.total" icon="handshake" :loading="loading" />
      <KpiCard label="Partner aktif" :value="stats.active" icon="verified" tone="positive" :loading="loading" />
      <KpiCard label="Konversi referral" :value="stats.conversions" icon="conversion_path" :loading="loading" />
      <KpiCard label="Kewajiban komisi" :value="stats.liability" format="currency" icon="pending_actions" tone="warning" :loading="loading" />
    </div>

    <div class="mb-6 rounded-2xl bg-primary-fixed/50 border border-primary/15 px-5 py-4">
      <div class="flex items-start gap-3">
        <span class="material-symbols-outlined text-primary">info</span>
        <div class="text-[13px] text-on-surface/80 leading-relaxed">
          <b>Aturan program:</b> komisi default 10% dari pendapatan bersih proyek yang lolos verifikasi.
          Self-referral ditolak, atribusi ganda dicegah, event webhook berulang diabaikan (idempoten).
          Perubahan status partner tercatat di audit log.
        </div>
      </div>
    </div>

    <EmptyState v-if="error" tone="error" icon="database_off" title="Gagal memuat partner"
                :description="error" action-label="Coba lagi" @action="load" />

    <template v-else>
      <h2 class="font-bold text-[15px] mb-3">Daftar partner</h2>
      <DataTable :columns="columns" :rows="rows" :loading="loading"
                 search-placeholder="Cari nama, kode referral…"
                 empty-text="Belum ada partner terdaftar.">
        <template #cell-full_name="{ row }">
          <div class="font-medium">{{ row.full_name }}</div>
          <div class="text-[12px] text-muted">{{ row.whatsapp || row.campus || '—' }}</div>
        </template>
        <template #cell-referral_code="{ row }">
          <code class="text-[12px] bg-surface-container px-1.5 py-0.5 rounded">{{ row.referral_code || '—' }}</code>
        </template>
        <template #cell-earned="{ row }">{{ formatRupiah(row.earned) }}</template>
        <template #cell-status="{ row }">
          <span class="inline-flex items-center gap-1.5 text-[12px] font-semibold px-2 py-1 rounded-lg"
                :class="row.status === 'active' ? 'bg-success-green/10 text-success-green' : 'bg-surface-container text-on-surface-variant'">
            {{ row.status === 'active' ? 'Aktif' : 'Nonaktif' }}
          </span>
        </template>
        <template #cell-actions="{ row }">
          <div class="flex justify-end gap-2">
            <button v-if="row.status !== 'active'" class="text-[12px] font-semibold text-primary hover:underline" @click.stop="approve(row)">Aktifkan</button>
            <button v-else class="text-[12px] font-semibold text-on-error-container hover:underline" @click.stop="suspend(row)">Nonaktifkan</button>
          </div>
        </template>
      </DataTable>

      <h2 class="font-bold text-[15px] mt-8 mb-3">Atribusi referral</h2>
      <DataTable :columns="attrCols" :rows="attrRows" :loading="loading"
                 search-placeholder="Cari partner, kode…"
                 empty-text="Belum ada atribusi referral tercatat.">
        <template #cell-status="{ row }"><StatusBadge :value="row.status" /></template>
      </DataTable>
    </template>

    <AppModal :open="showForm" title="Partner referral baru" subtitle="Kode referral dibuat otomatis dan unik." @close="showForm = false">
      <div class="grid sm:grid-cols-2 gap-4">
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Nama lengkap *</span>
          <input v-model="form.full_name" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">WhatsApp *</span>
          <input v-model="form.whatsapp" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="08xx" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Kampus / komunitas</span>
          <input v-model="form.campus" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Info e-wallet (payout)</span>
          <input v-model="form.ewallet_info" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="GoPay / OVO / bank" />
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Catatan</span>
          <textarea v-model="form.notes" rows="2" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
      </div>
      <p v-if="formError" class="mt-4 text-[13px] text-on-error-container bg-error-container border border-error/25 rounded-xl px-3 py-2">{{ formError }}</p>
      <template #footer>
        <div class="flex justify-end gap-2">
          <button class="px-4 py-2.5 rounded-xl border border-border-subtle font-label-bold hover:bg-surface-container-low" @click="showForm = false">Batal</button>
          <button class="px-4 py-2.5 rounded-xl bg-accent-fill text-white font-label-bold hover:bg-primary-container disabled:opacity-50" :disabled="saving" @click="createPartner">
            {{ saving ? 'Menyimpan…' : 'Buat partner' }}
          </button>
        </div>
      </template>
    </AppModal>
  </SideNav>
</template>
