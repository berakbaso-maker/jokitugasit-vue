<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  PERMISSION_BASIS_LABELS,
  PROSPECT_STATUS,
  clearDoNotContact,
  createProspect,
  isValidUsername,
  listProspects,
  listTargetAccounts,
  normalizeUsername,
} from '../lib/outreach'
import { supabase } from '../lib/supabase'
import { buildImportPreview, downloadCsv, toCsv } from '../lib/csv'

const loading = ref(true)
const error = ref('')
const notice = ref('')

const prospects = ref([])
const accounts = ref([])

const search = ref('')
const statusFilter = ref('')
const campusFilter = ref('')

// manual add
const showAdd = ref(false)
const addForm = ref({ ig_username: '', display_name: '', campus: '', cohort_year: '', source_account_id: '' })
const addError = ref('')
const adding = ref(false)

// import
const showImport = ref(false)
const importCsvText = ref('')
const importFileName = ref('')
const importSourceAccount = ref('')
const importBasis = ref('ADMIN_SHARED_LIST')
const importPreview = ref(null)
const importResult = ref(null)
const importing = ref(false)

const campuses = computed(() =>
  [...new Set(prospects.value.map(p => p.campus).filter(Boolean))].sort()
)

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  return prospects.value.filter(p => {
    if (statusFilter.value && p.status !== statusFilter.value) return false
    if (campusFilter.value && p.campus !== campusFilter.value) return false
    if (q && !String(p.ig_username).includes(q)
      && !String(p.display_name || '').toLowerCase().includes(q)) return false
    return true
  })
})

const counts = computed(() => ({
  total: prospects.value.length,
  active: prospects.value.filter(p => !p.do_not_contact).length,
  dnc: prospects.value.filter(p => p.do_not_contact).length,
}))

const statusMeta = (s) => PROSPECT_STATUS[s] || PROSPECT_STATUS.NEW

async function load() {
  loading.value = true
  error.value = ''
  try {
    ;[prospects.value, accounts.value] = await Promise.all([listProspects(), listTargetAccounts()])
  } catch (err) {
    error.value = err.message.includes('relation')
      ? 'Schema outreach belum dipasang. Jalankan supabase/migration-outreach-schema.sql.'
      : (err.message || 'Gagal memuat prospek.')
  } finally {
    loading.value = false
  }
}

async function addProspect() {
  addError.value = ''
  const username = normalizeUsername(addForm.value.ig_username)
  if (!isValidUsername(username)) {
    addError.value = 'Username Instagram tidak valid (huruf kecil, angka, titik, underscore; maks 30).'
    return
  }
  adding.value = true
  try {
    await createProspect({
      ig_username: username,
      display_name: addForm.value.display_name.trim() || null,
      campus: addForm.value.campus.trim() || null,
      cohort_year: addForm.value.cohort_year ? Number(addForm.value.cohort_year) : null,
      source_account_id: addForm.value.source_account_id || null,
      permission_basis: 'MANUAL_ENTRY',
    })
    addForm.value = { ig_username: '', display_name: '', campus: '', cohort_year: '', source_account_id: '' }
    showAdd.value = false
    notice.value = `Prospek @${username} ditambahkan.`
    await load()
  } catch (err) {
    addError.value = err.code === '23505'
      ? 'Username ini sudah ada di daftar prospek.'
      : (err.message || 'Gagal menambah prospek.')
  } finally {
    adding.value = false
  }
}

function onFileChange(event) {
  const file = event.target.files?.[0]
  if (!file) return
  importFileName.value = file.name
  const reader = new FileReader()
  reader.onload = () => {
    importCsvText.value = String(reader.result || '')
    importPreview.value = buildImportPreview(importCsvText.value)
    importResult.value = null
  }
  reader.readAsText(file)
}

function onPasteCsv() {
  importPreview.value = importCsvText.value.trim() ? buildImportPreview(importCsvText.value) : null
  importResult.value = null
}

async function commitImport() {
  if (!importPreview.value?.rows?.length) return
  importing.value = true
  error.value = ''
  try {
    const { data, error: rpcError } = await supabase.rpc('import_prospects', {
      p_rows: importPreview.value.rows.map(({ ig_username, display_name, campus, cohort_year }) => ({
        ig_username, display_name, campus, cohort_year,
      })),
      p_source_account: importSourceAccount.value || null,
      p_permission_basis: importBasis.value,
      p_batch_id: null,
    })
    if (rpcError) throw rpcError

    const row = Array.isArray(data) ? data[0] : data
    importResult.value = row
    notice.value = `Import selesai: ${row.inserted_count} baru, ${row.duplicate_existing} sudah ada, ${row.suppressed_count} dibiarkan jangan-dihubungi.`
    await load()
  } catch (err) {
    error.value = err.message || 'Gagal menyimpan hasil import.'
  } finally {
    importing.value = false
  }
}

function exportCsv() {
  const rows = filtered.value.map(p => ({
    ig_username: p.ig_username,
    display_name: p.display_name || '',
    campus: p.campus || '',
    cohort_year: p.cohort_year || '',
    status: p.status,
    do_not_contact: p.do_not_contact ? 'true' : 'false',
    permission_basis: p.permission_basis,
  }))
  downloadCsv(
    `prospek-${new Date().toISOString().slice(0, 10)}.csv`,
    toCsv(rows, ['ig_username', 'display_name', 'campus', 'cohort_year', 'status', 'do_not_contact', 'permission_basis']),
  )
}

async function undoDnc(prospect) {
  const reason = window.prompt(
    `Alasan melepas status jangan-dihubungi untuk @${prospect.ig_username}?\n(Ini akan dicatat di audit log.)`,
  )
  if (!reason || !reason.trim()) return
  try {
    await clearDoNotContact(prospect.id, reason.trim())
    notice.value = `Status jangan-dihubungi @${prospect.ig_username} dilepas dan tercatat di audit log.`
    await load()
  } catch (err) {
    error.value = err.message || 'Gagal melepas status jangan-dihubungi.'
  }
}

function closeImport() {
  showImport.value = false
  importCsvText.value = ''
  importFileName.value = ''
  importPreview.value = null
  importResult.value = null
}

onMounted(load)
</script>

<template>
  <SideNav>
    <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-4 mb-7">
      <div>
        <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2">Outreach</p>
        <h1 class="text-headline-lg font-bold">Prospek</h1>
        <p class="text-secondary mt-2 max-w-2xl">
          Hanya masukkan kontak dari sumber yang sah: input manual, formulir opt-in, atau daftar yang diberikan admin dengan izin.
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <button @click="showImport = true" class="inline-flex items-center gap-2 border border-electric-blue text-electric-blue font-label-bold px-4 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors">
          <span class="material-symbols-outlined text-[20px]">upload_file</span>
          Impor CSV
        </button>
        <button @click="showAdd = true" class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary transition-colors shadow-sm">
          <span class="material-symbols-outlined text-[20px]">person_add</span>
          Tambah Manual
        </button>
      </div>
    </div>

    <div v-if="error" class="mb-5 flex items-start gap-2 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-on-error-container">
      <span class="material-symbols-outlined text-[18px]">error</span>
      <span class="text-sm">{{ error }}</span>
    </div>
    <div v-if="notice" class="mb-5 flex items-start gap-2 rounded-xl border border-success-green/30 bg-success-green/10 p-4">
      <span class="material-symbols-outlined text-[18px] text-success-green">check_circle</span>
      <span class="text-sm">{{ notice }}</span>
    </div>

    <div class="grid grid-cols-3 gap-3 mb-6">
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Total Prospek</p>
        <p class="text-2xl font-bold">{{ counts.total }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Boleh Dihubungi</p>
        <p class="text-2xl font-bold text-success-green">{{ counts.active }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Jangan Dihubungi</p>
        <p class="text-2xl font-bold text-on-surface-variant">{{ counts.dnc }}</p>
      </div>
    </div>

    <!-- Filters -->
    <div class="flex flex-col sm:flex-row gap-3 mb-5">
      <input v-model="search" type="search" placeholder="Cari username / nama..." class="flex-1 rounded-xl border border-outline-variant bg-surface-white px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-electric-blue/40" />
      <select v-model="campusFilter" class="rounded-xl border border-outline-variant bg-surface-white px-3 py-2.5 text-sm">
        <option value="">Semua Kampus</option>
        <option v-for="c in campuses" :key="c" :value="c">{{ c }}</option>
      </select>
      <select v-model="statusFilter" class="rounded-xl border border-outline-variant bg-surface-white px-3 py-2.5 text-sm">
        <option value="">Semua Status</option>
        <option v-for="(meta, key) in PROSPECT_STATUS" :key="key" :value="key">{{ meta.label }}</option>
      </select>
      <button @click="exportCsv" class="inline-flex items-center gap-2 rounded-xl border border-outline-variant px-4 py-2.5 text-sm font-bold hover:bg-surface-container-low">
        <span class="material-symbols-outlined text-[18px]">download</span>
        Ekspor
      </button>
    </div>

    <div v-if="loading" class="text-center py-16 text-on-surface-variant">
      <span class="material-symbols-outlined text-[40px] animate-spin">progress_activity</span>
    </div>

    <div v-else-if="filtered.length === 0" class="text-center py-16 bg-surface-white rounded-xl border border-border-subtle">
      <span class="material-symbols-outlined text-[48px] mb-3 block text-on-surface-variant">group</span>
      <p class="font-bold">Belum ada prospek yang cocok.</p>
      <p class="text-sm text-on-surface-variant mt-1">Tambahkan manual atau impor CSV dari daftar berizin.</p>
    </div>

    <div v-else class="bg-surface-white rounded-xl border border-border-subtle overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-surface-container-low text-left">
          <tr class="text-on-surface-variant">
            <th class="px-4 py-3 font-bold">Username</th>
            <th class="px-4 py-3 font-bold hidden md:table-cell">Nama</th>
            <th class="px-4 py-3 font-bold hidden lg:table-cell">Kampus</th>
            <th class="px-4 py-3 font-bold">Status</th>
            <th class="px-4 py-3 font-bold hidden xl:table-cell">Sumber</th>
            <th class="px-4 py-3 font-bold text-right">Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.id" class="border-t border-border-subtle">
            <td class="px-4 py-3">
              <a :href="`https://instagram.com/${p.ig_username}/`" target="_blank" rel="noopener" class="font-bold text-electric-blue hover:underline">
                @{{ p.ig_username }}
              </a>
            </td>
            <td class="px-4 py-3 hidden md:table-cell text-on-surface-variant">{{ p.display_name || '—' }}</td>
            <td class="px-4 py-3 hidden lg:table-cell text-on-surface-variant">{{ p.campus || '—' }}</td>
            <td class="px-4 py-3">
              <span :class="statusMeta(p.status).class" class="text-[11px] font-bold px-2 py-0.5 rounded-full whitespace-nowrap">
                {{ statusMeta(p.status).label }}
              </span>
            </td>
            <td class="px-4 py-3 hidden xl:table-cell text-on-surface-variant text-xs">
              {{ PERMISSION_BASIS_LABELS[p.permission_basis] || p.permission_basis }}
            </td>
            <td class="px-4 py-3 text-right">
              <button v-if="p.do_not_contact" @click="undoDnc(p)" class="text-xs font-bold text-on-surface-variant hover:text-on-surface underline">
                Lepas DNC
              </button>
              <span v-else class="text-xs text-on-surface-variant">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Add modal -->
    <div v-if="showAdd" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4" @click.self="showAdd = false">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex items-center justify-between mb-5">
          <h2 class="font-bold text-lg">Tambah Prospek Manual</h2>
          <button @click="showAdd = false" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <form @submit.prevent="addProspect" class="space-y-4">
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Username Instagram *</label>
            <input v-model="addForm.ig_username" type="text" required placeholder="@username atau username" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            <p class="text-[11px] text-on-surface-variant mt-1">
              Disimpan sebagai: <span class="font-mono">{{ normalizeUsername(addForm.ig_username) || '—' }}</span>
            </p>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Nama (opsional)</label>
              <input v-model="addForm.display_name" type="text" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Angkatan</label>
              <input v-model="addForm.cohort_year" type="number" min="1990" max="2036" placeholder="2023" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Kampus</label>
            <input v-model="addForm.campus" type="text" placeholder="Binus, Telkom..." class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Akun sumber (opsional)</label>
            <select v-model="addForm.source_account_id" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
              <option value="">— Tidak ada —</option>
              <option v-for="a in accounts" :key="a.id" :value="a.id">@{{ a.ig_username }}</option>
            </select>
          </div>
          <p v-if="addError" class="text-sm text-urgency-red">{{ addError }}</p>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showAdd = false" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant font-bold text-sm">Batal</button>
            <button type="submit" :disabled="adding" class="flex-1 px-4 py-2.5 rounded-xl bg-electric-blue text-white font-bold text-sm disabled:opacity-60">
              {{ adding ? 'Menyimpan...' : 'Simpan' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Import modal -->
    <div v-if="showImport" class="fixed inset-0 z-50 flex items-start justify-center bg-black/40 backdrop-blur-sm px-4 py-8 overflow-y-auto" @click.self="closeImport">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-2xl">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-bold text-lg">Impor CSV</h2>
          <button @click="closeImport" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>

        <div class="rounded-xl bg-surface-container-low border border-border-subtle p-3 text-xs text-on-surface-variant mb-4">
          Kolom: <code class="font-mono">ig_username, display_name, campus, cohort_year</code>.
          Baris pertama boleh header. Username dinormalisasi (buang <code>@</code>, lowercase, trim).
        </div>

        <div class="grid sm:grid-cols-2 gap-3 mb-4">
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Akun sumber</label>
            <select v-model="importSourceAccount" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-2.5 text-sm">
              <option value="">— Tanpa sumber —</option>
              <option v-for="a in accounts" :key="a.id" :value="a.id">@{{ a.ig_username }}</option>
            </select>
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Dasar izin</label>
            <select v-model="importBasis" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-2.5 text-sm">
              <option value="ADMIN_SHARED_LIST">Daftar diberikan admin</option>
              <option value="INBOUND_OPT_IN">Inbound / mendaftar sendiri</option>
              <option value="MANUAL_ENTRY">Input manual</option>
            </select>
          </div>
        </div>

        <div class="space-y-3 mb-4">
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Pilih file .csv</label>
            <input type="file" accept=".csv,text/csv" @change="onFileChange" class="w-full text-sm" />
            <p v-if="importFileName" class="text-[11px] text-on-surface-variant mt-1">{{ importFileName }}</p>
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">atau tempel isi CSV</label>
            <textarea v-model="importCsvText" rows="4" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-2 text-xs font-mono" placeholder="ig_username,display_name,campus,cohort_year"></textarea>
            <button @click="onPasteCsv" class="mt-2 text-xs font-bold text-electric-blue hover:underline">Pratinjau</button>
          </div>
        </div>

        <div v-if="importPreview" class="rounded-xl border border-border-subtle p-4 mb-4">
          <div class="grid grid-cols-4 gap-2 text-center mb-3">
            <div><p class="text-[11px] text-on-surface-variant">Baris</p><p class="font-bold">{{ importPreview.summary.total }}</p></div>
            <div><p class="text-[11px] text-on-surface-variant">Valid</p><p class="font-bold text-success-green">{{ importPreview.summary.valid }}</p></div>
            <div><p class="text-[11px] text-on-surface-variant">Invalid</p><p class="font-bold text-urgency-red">{{ importPreview.summary.invalid }}</p></div>
            <div><p class="text-[11px] text-on-surface-variant">Duplikat</p><p class="font-bold">{{ importPreview.summary.duplicateInFile }}</p></div>
          </div>

          <div v-if="importPreview.errors.length" class="max-h-32 overflow-y-auto text-[11px] text-on-surface-variant space-y-1 mb-3">
            <p v-for="e in importPreview.errors.slice(0, 30)" :key="`${e.line}-${e.value}`">
              Baris {{ e.line }} · <span class="font-mono">{{ e.value || '(kosong)' }}</span> — {{ e.reason }}
            </p>
          </div>

          <div v-if="importPreview.rows.length" class="max-h-40 overflow-y-auto text-[11px] font-mono space-y-0.5">
            <p v-for="r in importPreview.rows.slice(0, 50)" :key="r.ig_username">
              @{{ r.ig_username }}<span v-if="r.campus"> · {{ r.campus }}</span><span v-if="r.cohort_year"> · {{ r.cohort_year }}</span>
            </p>
          </div>
        </div>

        <div v-if="importResult" class="rounded-xl bg-success-green/10 border border-success-green/30 p-4 mb-4 text-sm">
          <p class="font-bold mb-1">Import selesai</p>
          <ul class="text-xs space-y-0.5 text-on-surface-variant">
            <li>Baru: {{ importResult.inserted_count }}</li>
            <li>Sudah ada: {{ importResult.duplicate_existing }}</li>
            <li>Dilewati karena jangan-dihubungi: {{ importResult.suppressed_count }}</li>
            <li>Duplikat dalam file: {{ importResult.duplicate_in_file }}</li>
            <li>Invalid: {{ importResult.invalid_count }}</li>
          </ul>
        </div>

        <div class="flex gap-3">
          <button @click="closeImport" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant font-bold text-sm">
            {{ importResult ? 'Tutup' : 'Batal' }}
          </button>
          <button
            v-if="!importResult"
            @click="commitImport"
            :disabled="importing || !importPreview?.rows?.length"
            class="flex-1 px-4 py-2.5 rounded-xl bg-electric-blue text-white font-bold text-sm disabled:opacity-50"
          >
            {{ importing ? 'Menyimpan...' : `Simpan ${importPreview?.rows?.length || 0} prospek` }}
          </button>
        </div>
      </div>
    </div>
  </SideNav>
</template>
