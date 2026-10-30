<script setup>
/**
 * PREVIEW SEMENTARA — bukan bagian aplikasi.
 * Merender komponen UI asli dengan data contoh agar styling bisa
 * diperiksa secara visual tanpa Supabase (project sedang NXDOMAIN).
 * Hapus file ini setelah verifikasi.
 */
import { ref } from 'vue'
import KpiCard from '../components/ui/KpiCard.vue'
import DataTable from '../components/ui/DataTable.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import AppModal from '../components/ui/AppModal.vue'

const showModal = ref(false)

const columns = [
  { key: 'university', label: 'Universitas', sortable: true },
  { key: 'province', label: 'Provinsi', sortable: true },
  { key: 'community', label: 'Komunitas' },
  { key: 'consent', label: 'Consent' },
  { key: 'status', label: 'Status' },
]
const rows = [
  { university: 'Universitas Padjadjaran', province: 'Jawa Barat', community: 'BEM FMIPA', consent: 'GRANTED', status: 'QUALIFIED' },
  { university: 'Institut Teknologi Bandung', province: 'Jawa Barat', community: 'Himpunan Informatika', consent: 'REQUESTED', status: 'CONTACTED' },
  { university: 'Universitas Indonesia', province: 'DKI Jakarta', community: 'BEM Fasilkom', consent: 'UNKNOWN', status: 'NEW' },
  { university: 'Universitas Gadjah Mada', province: 'DI Yogyakarta', community: 'KMTETI', consent: 'DECLINED', status: 'DO_NOT_CONTACT' },
]
</script>

<template>
  <div class="min-h-screen bg-background p-6 md:p-10">
    <div class="max-w-6xl mx-auto space-y-8">

      <PageHeader
        eyebrow="Overview"
        title="Overview"
        description="Ringkasan operasi bisnis: kampus, lead, proyek, dan pendapatan."
      />

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-2">
        <KpiCard label="Total Kampus" :value="128" icon="school" hint="Data nyata dari tabel campuses" />
        <KpiCard label="Lead Qualified" :value="42" icon="groups" tone="positive" />
        <KpiCard label="Proyek Aktif" :value="7" icon="folder_open" />
        <KpiCard label="Pendapatan" :value="12500000" format="currency" icon="payments" tone="positive" />
        <KpiCard label="Komisi Pending" :value="750000" format="currency" icon="pending_actions" tone="warning" />
        <KpiCard label="Workflow Gagal" :value="0" icon="error" tone="danger" />
        <KpiCard label="Belum Ada Data" :value="null" icon="help" hint='Nilai kosong tampil "—"' />
        <KpiCard label="Conversion" :value="18.5" format="percent" icon="trending_up" tone="positive" />
      </div>

      <div>
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-headline-md font-headline-md font-bold text-on-surface">Campus Database</h2>
          <button
            class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold
                   px-4 py-2.5 rounded-xl hover:bg-primary transition-colors"
            @click="showModal = true"
          >
            <span class="material-symbols-outlined text-[18px]">add</span>
            Tambah Kampus
          </button>
        </div>
        <DataTable :columns="columns" :rows="rows" searchable>
          <template #cell-consent="{ row }">
            <StatusBadge :value="row.consent" />
          </template>
          <template #cell-status="{ row }">
            <StatusBadge :value="row.status" />
          </template>
        </DataTable>
      </div>

      <div class="grid md:grid-cols-2 gap-4">
        <EmptyState icon="inbox" title="Belum ada aktivitas" description="Aktivitas akan muncul di sini." />
        <div class="bg-surface-white rounded-xl border border-border-subtle shadow-card p-5">
          <h3 class="text-label-bold font-label-bold text-secondary uppercase tracking-wide mb-3">Semua Status Badge</h3>
          <div class="flex flex-wrap gap-2">
            <StatusBadge v-for="s in ['NEW','CONTACTED','QUALIFIED','CLIENT','PAID','PENDING','FAILED','ACTIVE','PAUSED','DRAFT','HIGH','URGENT','GRANTED','DECLINED']" :key="s" :value="s" />
          </div>
        </div>
      </div>

      <AppModal :open="showModal" title="Tambah Kampus" @close="showModal = false">
        <div class="space-y-3">
          <label class="block">
            <span class="text-[12px] font-semibold text-secondary">Universitas *</span>
            <input class="mt-1 w-full border border-outline-variant rounded-xl px-3 py-2.5 text-sm" placeholder="Universitas Padjadjaran" />
          </label>
          <label class="block">
            <span class="text-[12px] font-semibold text-secondary">Provinsi *</span>
            <input class="mt-1 w-full border border-outline-variant rounded-xl px-3 py-2.5 text-sm" placeholder="Jawa Barat" />
          </label>
        </div>
        <template #footer>
          <button class="px-4 py-2.5 rounded-xl border border-border-subtle text-secondary font-label-bold hover:bg-surface-container-low" @click="showModal = false">Batal</button>
          <button class="px-4 py-2.5 rounded-xl bg-electric-blue text-white font-label-bold hover:bg-primary">Simpan</button>
        </template>
      </AppModal>

    </div>
  </div>
</template>
