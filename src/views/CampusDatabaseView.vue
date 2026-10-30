<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import DataTable from '../components/ui/DataTable.vue'
import AppModal from '../components/ui/AppModal.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import {
  listCampuses, createCampus, updateCampus, deleteCampus, importCampuses,
  COMMUNITY_TYPES, CONSENT_LABEL, PROVENANCE_LABEL,
} from '../lib/internal'
import { pesanGalat } from '../lib/galat'

const loading = ref(true)
const error = ref('')
const rows = ref([])
const saving = ref(false)
const formError = ref('')

const filterProvince = ref('')
const filterConsent = ref('')

const showModal = ref(false)
const editing = ref(null)
const fileInput = ref(null)
const importReport = ref(null)

const blank = () => ({
  province: '', city: '', university: '', faculty: '', study_program: '',
  cohort_year: '', community_name: '', community_type: 'BEM',
  authorized_contact_name: '', authorized_contact_role: '',
  consent_status: 'UNKNOWN', provenance: 'MANUAL', provenance_ref: '',
  tags: '', notes: '',
})
const form = ref(blank())

const columns = [
  { key: 'university', label: 'Universitas', sortable: true },
  { key: 'faculty', label: 'Fakultas / Prodi', sortable: true },
  { key: 'region', label: 'Wilayah', sortable: true },
  { key: 'community_name', label: 'Komunitas', sortable: true },
  { key: 'contact', label: 'Kontak resmi' },
  { key: 'consent_status', label: 'Consent' },
  { key: 'actions', label: '', align: 'right', width: '90px' },
]

async function load() {
  loading.value = true
  error.value = ''
  try {
    rows.value = await listCampuses({
      province: filterProvince.value || undefined,
      consent_status: filterConsent.value || undefined,
    })
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  } finally {
    loading.value = false
  }
}
onMounted(load)

const tableRows = computed(() => rows.value.map(r => ({
  ...r,
  region: [r.city, r.province].filter(Boolean).join(', ') || '—',
  contact: r.authorized_contact_name
    ? `${r.authorized_contact_name}${r.authorized_contact_role ? ' · ' + r.authorized_contact_role : ''}`
    : '—',
})))

const provinces = computed(() =>
  [...new Set(rows.value.map(r => r.province).filter(Boolean))].sort()
)

const stats = computed(() => ({
  total: rows.value.length,
  granted: rows.value.filter(r => r.consent_status === 'GRANTED').length,
  unknown: rows.value.filter(r => r.consent_status === 'UNKNOWN').length,
  provinces: provinces.value.length,
}))

function openCreate() {
  editing.value = null
  form.value = blank()
  formError.value = ''
  showModal.value = true
}

function openEdit(row) {
  editing.value = row
  formError.value = ''
  form.value = {
    ...blank(),
    ...row,
    tags: Array.isArray(row.tags) ? row.tags.join(', ') : (row.tags || ''),
    cohort_year: row.cohort_year ?? '',
  }
  showModal.value = true
}

async function save() {
  formError.value = ''
  if (!form.value.province?.trim() || !form.value.university?.trim()) {
    formError.value = 'Provinsi dan universitas wajib diisi.'
    return
  }
  saving.value = true
  try {
    const payload = {
      ...form.value,
      cohort_year: form.value.cohort_year ? Number(form.value.cohort_year) : null,
      tags: form.value.tags ? String(form.value.tags).split(',').map(t => t.trim()).filter(Boolean) : [],
    }
    if (editing.value) await updateCampus(editing.value.id, payload)
    else await createCampus(payload)
    showModal.value = false
    await load()
  } catch (e) {
    formError.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  } finally {
    saving.value = false
  }
}

async function remove(row) {
  if (!confirm(`Hapus data kampus "${row.university}"? Tindakan ini tercatat di audit log.`)) return
  try {
    await deleteCampus(row.id)
    await load()
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  }
}

/* ---------------- CSV import ---------------- */
function parseCsv(text) {
  const lines = text.split(/\r?\n/).filter(l => l.trim())
  if (!lines.length) return []
  const split = (line) => {
    const out = []
    let cur = ''
    let quoted = false
    for (let i = 0; i < line.length; i++) {
      const ch = line[i]
      if (ch === '"') {
        if (quoted && line[i + 1] === '"') { cur += '"'; i++ }
        else quoted = !quoted
      } else if (ch === ',' && !quoted) { out.push(cur); cur = '' }
      else cur += ch
    }
    out.push(cur)
    return out.map(s => s.trim())
  }
  const header = split(lines[0]).map(h => h.toLowerCase().replace(/\s+/g, '_'))
  return lines.slice(1).map(line => {
    const cells = split(line)
    const obj = {}
    header.forEach((h, i) => { obj[h] = cells[i] ?? '' })
    return obj
  })
}

async function onFile(e) {
  const file = e.target.files?.[0]
  if (!file) return
  importReport.value = null
  try {
    const text = await file.text()
    const parsed = parseCsv(text)
    if (!parsed.length) {
      importReport.value = { error: 'File CSV kosong atau header tidak terbaca.' }
      return
    }
    const res = await importCampuses(parsed)
    importReport.value = { ...res, total: parsed.length }
    await load()
  } catch (err) {
    importReport.value = { error: pesanGalat(err) }
  } finally {
    if (fileInput.value) fileInput.value.value = ''
  }
}

function downloadTemplate() {
  const header = 'province,city,university,faculty,study_program,cohort_year,community_name,community_type,authorized_contact_name,authorized_contact_role,consent_status,provenance,provenance_ref,tags,notes'
  const sample = 'Jawa Barat,Bandung,Universitas Contoh,Fakultas Ilmu Komputer,Teknik Informatika,2023,BEM FIK,BEM,Budi Santoso,Ketua Umum,UNKNOWN,PUBLIC_DIRECTORY,https://instagram.com/bemfik,"komunitas,bandung",Kontak dari direktori resmi kampus'
  const blob = new Blob([header + '\n' + sample + '\n'], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = 'template-kampus.csv'
  a.click()
  URL.revokeObjectURL(a.href)
}
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 2"
      title="Campus Database"
      description="Direktori komunitas mahasiswa IT se-Indonesia. Hanya akun organisasi publik dan kontak resmi — tidak ada scraping akun pribadi atau daftar follower."
    >
      <template #actions>
        <button class="inline-flex items-center gap-2 border border-border-subtle bg-surface-white font-label-bold px-3.5 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors" @click="downloadTemplate">
          <span class="material-symbols-outlined text-[18px]">download</span>
          Template
        </button>
        <label class="inline-flex items-center gap-2 border border-border-subtle bg-surface-white font-label-bold px-3.5 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors cursor-pointer">
          <span class="material-symbols-outlined text-[18px]">upload</span>
          Import CSV
          <input ref="fileInput" type="file" accept=".csv,text/csv" class="hidden" @change="onFile" />
        </label>
        <button class="inline-flex items-center gap-2 bg-accent-fill text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary-container transition-colors" @click="openCreate">
          <span class="material-symbols-outlined text-[18px]">add</span>
          Tambah kampus
        </button>
      </template>
    </PageHeader>

    <div v-if="importReport" class="mb-5 rounded-xl px-4 py-3 text-[13px] border"
         :class="importReport.error ? 'bg-error-container border-error/25 text-on-error-container' : 'bg-success-green/10 border-success-green/25 text-success-green'">
      <template v-if="importReport.error">{{ importReport.error }}</template>
      <template v-else>
        Import selesai: <b>{{ importReport.inserted }}</b> ditambahkan,
        <b>{{ importReport.skipped }}</b> dilewati (duplikat) dari {{ importReport.total }} baris.
      </template>
      <button class="ml-2 underline" @click="importReport = null">tutup</button>
    </div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <KpiCard label="Total entri" :value="stats.total" icon="school" :loading="loading" />
      <KpiCard label="Consent diberikan" :value="stats.granted" icon="verified_user" tone="positive" :loading="loading" />
      <KpiCard label="Consent belum jelas" :value="stats.unknown" icon="help" tone="warning" :loading="loading" />
      <KpiCard label="Provinsi tercakup" :value="stats.provinces" icon="map" :loading="loading" />
    </div>

    <div class="flex flex-wrap gap-2 mb-4">
      <select v-model="filterProvince" class="text-[13px] border border-border-subtle rounded-xl px-3 py-2 bg-surface-white" @change="load">
        <option value="">Semua provinsi</option>
        <option v-for="p in provinces" :key="p" :value="p">{{ p }}</option>
      </select>
      <select v-model="filterConsent" class="text-[13px] border border-border-subtle rounded-xl px-3 py-2 bg-surface-white" @change="load">
        <option value="">Semua consent</option>
        <option v-for="(lbl, k) in CONSENT_LABEL" :key="k" :value="k">{{ lbl }}</option>
      </select>
    </div>

    <EmptyState
      v-if="error" tone="error" icon="database_off" title="Gagal memuat data"
      :description="error" action-label="Coba lagi" @action="load"
    />

    <DataTable
      v-else
      :columns="columns" :rows="tableRows" :loading="loading"
      search-placeholder="Cari universitas, kota, komunitas…"
      empty-text="Belum ada data kampus. Tambah manual atau import CSV."
    >
      <template #cell-university="{ row }">
        <div class="font-medium">{{ row.university }}</div>
        <div class="text-[12px] text-muted">{{ row.study_program || '—' }}</div>
      </template>
      <template #cell-faculty="{ row }">
        <div>{{ row.faculty || '—' }}</div>
        <div v-if="row.cohort_year" class="text-[12px] text-muted">Angkatan {{ row.cohort_year }}</div>
      </template>
      <template #cell-community_name="{ row }">
        <div>{{ row.community_name || '—' }}</div>
        <div v-if="row.community_type" class="text-[12px] text-muted">{{ row.community_type }}</div>
      </template>
      <template #cell-consent_status="{ row }">
        <StatusBadge :value="row.consent_status" :label="CONSENT_LABEL[row.consent_status]" />
      </template>
      <template #cell-actions="{ row }">
        <div class="flex justify-end gap-1">
          <button class="p-1.5 rounded-lg hover:bg-surface-container text-secondary" title="Edit" @click.stop="openEdit(row)">
            <span class="material-symbols-outlined text-[18px]">edit</span>
          </button>
          <button class="p-1.5 rounded-lg hover:bg-error-container text-on-error-container" title="Hapus" @click.stop="remove(row)">
            <span class="material-symbols-outlined text-[18px]">delete</span>
          </button>
        </div>
      </template>
    </DataTable>

    <AppModal :open="showModal"
      :title="editing ? 'Edit data kampus' : 'Tambah data kampus'"
      subtitle="Isi hanya data dari sumber resmi/publik."
      @close="showModal = false"
    >
      <div class="grid sm:grid-cols-2 gap-4">
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Provinsi *</span>
          <input v-model="form.province" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="Jawa Barat" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Kota</span>
          <input v-model="form.city" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="Bandung" />
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Universitas *</span>
          <input v-model="form.university" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Fakultas</span>
          <input v-model="form.faculty" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Program studi</span>
          <input v-model="form.study_program" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Angkatan</span>
          <input v-model="form.cohort_year" type="number" min="1990" max="2036" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Jenis komunitas</span>
          <select v-model="form.community_type" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option v-for="t in COMMUNITY_TYPES" :key="t" :value="t">{{ t }}</option>
          </select>
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Nama komunitas / akun organisasi publik</span>
          <input v-model="form.community_name" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="BEM FIK" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Nama kontak resmi</span>
          <input v-model="form.authorized_contact_name" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Jabatan kontak</span>
          <input v-model="form.authorized_contact_role" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="Ketua Umum" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Status consent</span>
          <select v-model="form.consent_status" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option v-for="(lbl, k) in CONSENT_LABEL" :key="k" :value="k">{{ lbl }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Sumber data (provenance)</span>
          <select v-model="form.provenance" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option v-for="(lbl, k) in PROVENANCE_LABEL" :key="k" :value="k">{{ lbl }}</option>
          </select>
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Referensi sumber</span>
          <input v-model="form.provenance_ref" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="URL direktori resmi / nama acara" />
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Tag (pisahkan dengan koma)</span>
          <input v-model="form.tags" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="jabar, informatika" />
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Catatan</span>
          <textarea v-model="form.notes" rows="3" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
      </div>

      <p v-if="formError" class="mt-4 text-[13px] text-on-error-container bg-error-container border border-error/25 rounded-xl px-3 py-2">{{ formError }}</p>

      <template #footer>
        <div class="flex justify-end gap-2">
          <button class="px-4 py-2.5 rounded-xl border border-border-subtle font-label-bold hover:bg-surface-container-low" @click="showModal = false">Batal</button>
          <button class="px-4 py-2.5 rounded-xl bg-accent-fill text-white font-label-bold hover:bg-primary-container disabled:opacity-50" :disabled="saving" @click="save">
            {{ saving ? 'Menyimpan…' : 'Simpan' }}
          </button>
        </div>
      </template>
    </AppModal>
  </SideNav>
</template>
