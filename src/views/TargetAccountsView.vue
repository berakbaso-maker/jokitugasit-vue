<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  ACCOUNT_TYPE_LABELS,
  RELATIONSHIP_LABELS,
  createTargetAccount,
  deleteTargetAccount,
  isValidUsername,
  listTargetAccounts,
  normalizeUsername,
  updateTargetAccount,
} from '../lib/outreach'

const loading = ref(true)
const error = ref('')
const notice = ref('')
const accounts = ref([])

const showForm = ref(false)
const editingId = ref(null)
const formError = ref('')
const savingForm = ref(false)
const deletingId = ref('')

const emptyForm = () => ({
  ig_username: '', campus: '', major: '', cohort_year: '',
  account_type: 'COHORT', admin_contact: '', notes: '',
})
const form = ref(emptyForm())

const counts = computed(() => ({
  total: accounts.value.length,
  granted: accounts.value.filter(a => a.relationship_status === 'PERMISSION_GRANTED').length,
  contacted: accounts.value.filter(a => a.relationship_status === 'CONTACTED').length,
}))

async function load() {
  loading.value = true
  error.value = ''
  try {
    accounts.value = await listTargetAccounts()
  } catch (err) {
    error.value = err.message.includes('relation')
      ? 'Schema outreach belum dipasang. Jalankan supabase/migration-outreach-schema.sql.'
      : (err.message || 'Gagal memuat akun target.')
  } finally {
    loading.value = false
  }
}

function openAdd() {
  editingId.value = null
  form.value = emptyForm()
  formError.value = ''
  showForm.value = true
}

function openEdit(account) {
  editingId.value = account.id
  form.value = {
    ig_username: account.ig_username,
    campus: account.campus || '',
    major: account.major || '',
    cohort_year: account.cohort_year || '',
    account_type: account.account_type || 'COHORT',
    admin_contact: account.admin_contact || '',
    notes: account.notes || '',
  }
  formError.value = ''
  showForm.value = true
}

async function saveAccount() {
  formError.value = ''
  const username = normalizeUsername(form.value.ig_username)
  if (!isValidUsername(username)) {
    formError.value = 'Username Instagram tidak valid.'
    return
  }

  savingForm.value = true
  try {
    const payload = {
      ig_username: username,
      instagram_profile_url: `https://instagram.com/${username}/`,
      campus: form.value.campus.trim() || null,
      major: form.value.major.trim() || null,
      cohort_year: form.value.cohort_year ? Number(form.value.cohort_year) : null,
      account_type: form.value.account_type,
      admin_contact: form.value.admin_contact.trim() || null,
      notes: form.value.notes.trim() || null,
    }

    if (editingId.value) {
      await updateTargetAccount(editingId.value, payload)
      notice.value = `Akun @${username} diperbarui.`
    } else {
      await createTargetAccount(payload)
      notice.value = `Akun @${username} ditambahkan.`
    }

    showForm.value = false
    editingId.value = null
    form.value = emptyForm()
    await load()
  } catch (err) {
    formError.value = err.code === '23505'
      ? 'Username ini sudah dipakai akun lain.'
      : (err.message || 'Gagal menyimpan akun.')
  } finally {
    savingForm.value = false
  }
}

async function removeAccount(account) {
  const ok = window.confirm(
    `Hapus akun target @${account.ig_username}?\n\nProspek yang bersumber dari akun ini tetap ada, tetapi tautan sumbernya dikosongkan.`,
  )
  if (!ok) return

  deletingId.value = account.id
  error.value = ''
  try {
    await deleteTargetAccount(account.id)
    notice.value = `Akun @${account.ig_username} dihapus.`
    await load()
  } catch (err) {
    error.value = err.message || 'Gagal menghapus akun.'
  } finally {
    deletingId.value = ''
  }
}

async function setStatus(account, status) {
  if (status === 'DECLINED'
    && !window.confirm(`Tandai @${account.ig_username} menolak? Jangan hubungi lagi akun ini.`)) {
    return
  }
  error.value = ''
  try {
    const updated = await updateTargetAccount(account.id, { relationship_status: status })
    Object.assign(account, updated)
    notice.value = `Status @${account.ig_username}: ${RELATIONSHIP_LABELS[status]}`
  } catch (err) {
    error.value = err.message || 'Gagal mengubah status.'
  }
}

onMounted(load)
</script>

<template>
  <SideNav>
    <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-4 mb-7">
      <div>
        <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2">Outreach</p>
        <h1 class="text-headline-lg font-bold">Akun Target</h1>
        <p class="text-secondary mt-2 max-w-2xl">
          Akun angkatan/jurusan sebagai <strong>sumber</strong> prospek. Catat izin admin sebelum membagikan apa pun.
        </p>
      </div>
      <button @click="openAdd" class="inline-flex items-center gap-2 bg-accent-fill text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-accent-fill transition-colors shadow-sm">
        <span class="material-symbols-outlined text-[20px]">add</span>
        Tambah Akun
      </button>
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
        <p class="text-label-sm text-on-surface-variant mb-1">Total Akun</p>
        <p class="text-2xl font-bold">{{ counts.total }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Sudah Dihubungi</p>
        <p class="text-2xl font-bold">{{ counts.contacted }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Izin Diberikan</p>
        <p class="text-2xl font-bold text-success-green">{{ counts.granted }}</p>
      </div>
    </div>

    <div v-if="loading" class="text-center py-16 text-on-surface-variant">
      <span class="material-symbols-outlined text-[40px] animate-spin">progress_activity</span>
    </div>

    <div v-else-if="accounts.length === 0" class="text-center py-16 bg-surface-white rounded-xl border border-border-subtle">
      <span class="material-symbols-outlined text-[48px] mb-3 block text-on-surface-variant">school</span>
      <p class="font-bold">Belum ada akun target.</p>
      <p class="text-sm text-on-surface-variant mt-1 max-w-md mx-auto">
        Mulai dari 3 akun angkatan Informatika/Sistem Informasi di kampus sekitar. Kirim pesan ke admin dulu.
      </p>
    </div>

    <div v-else class="space-y-3">
      <div v-for="a in accounts" :key="a.id" class="bg-surface-white rounded-xl border border-border-subtle p-4">
        <div class="flex flex-col lg:flex-row lg:items-center justify-between gap-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <a :href="`https://instagram.com/${a.ig_username}/`" target="_blank" rel="noopener" class="font-bold text-electric-blue hover:underline">
                @{{ a.ig_username }}
              </a>
              <span class="text-[11px] font-bold px-2 py-0.5 rounded-full bg-surface-container text-on-surface-variant">
                {{ ACCOUNT_TYPE_LABELS[a.account_type] || a.account_type }}
              </span>
              <span
                class="text-[11px] font-bold px-2 py-0.5 rounded-full"
                :class="a.relationship_status === 'PERMISSION_GRANTED'
                  ? 'bg-success-green/15 text-success-green'
                  : a.relationship_status === 'DECLINED'
                    ? 'bg-error-container text-on-error-container'
                    : 'bg-surface-container text-on-surface-variant'"
              >
                {{ RELATIONSHIP_LABELS[a.relationship_status] || a.relationship_status }}
              </span>
            </div>
            <p class="text-sm text-on-surface-variant mt-0.5 truncate">
              {{ a.campus || 'Kampus belum diisi' }}
              <template v-if="a.major"> · {{ a.major }}</template>
              <template v-if="a.cohort_year"> · {{ a.cohort_year }}</template>
            </p>
            <p v-if="a.admin_contact" class="text-[11px] text-on-surface-variant mt-1">
              Admin: {{ a.admin_contact }}
            </p>
          </div>

          <div class="flex flex-wrap gap-2 shrink-0">
            <button
              v-if="a.relationship_status === 'NEW'"
              @click="setStatus(a, 'CONTACTED')"
              class="text-xs font-bold px-3 py-1.5 rounded-lg bg-accent-fill text-white hover:bg-accent-fill"
            >
              Tandai Dihubungi
            </button>
            <button
              v-if="a.relationship_status !== 'PERMISSION_GRANTED'"
              @click="setStatus(a, 'PERMISSION_GRANTED')"
              class="text-xs font-bold px-3 py-1.5 rounded-lg bg-success-green/15 text-success-green hover:bg-success-green/25"
            >
              Izin Diberikan
            </button>
            <button
              v-if="a.relationship_status !== 'DECLINED'"
              @click="setStatus(a, 'DECLINED')"
              class="text-xs font-bold px-3 py-1.5 rounded-lg bg-error-container text-on-error-container hover:bg-error-container/80"
            >
              Menolak
            </button>
            <button
              @click="openEdit(a)"
              class="text-xs font-bold px-3 py-1.5 rounded-lg border border-outline-variant text-on-surface-variant hover:bg-surface-container-low"
            >
              Edit
            </button>
            <button
              :disabled="deletingId === a.id"
              @click="removeAccount(a)"
              class="text-xs font-bold px-3 py-1.5 rounded-lg text-urgency-red hover:bg-error-container/50 disabled:opacity-50"
            >
              {{ deletingId === a.id ? 'Menghapus...' : 'Hapus' }}
            </button>
          </div>
        </div>
        <p v-if="a.notes" class="text-xs text-on-surface-variant mt-3 pt-3 border-t border-border-subtle">{{ a.notes }}</p>
      </div>
    </div>

    <!-- Add / edit modal -->
    <div v-if="showForm" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4 py-8 overflow-y-auto" @click.self="showForm = false">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-lg">
        <div class="flex items-center justify-between mb-5">
          <h2 class="font-bold text-lg">{{ editingId ? 'Edit Akun Target' : 'Tambah Akun Target' }}</h2>
          <button @click="showForm = false" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <form @submit.prevent="saveAccount" class="space-y-4">
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Username Instagram *</label>
            <input v-model="form.ig_username" type="text" required placeholder="hmif.kampus.2023" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            <p class="text-[11px] text-on-surface-variant mt-1">Disimpan sebagai: <span class="font-mono">{{ normalizeUsername(form.ig_username) || '—' }}</span></p>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Kampus</label>
              <input v-model="form.campus" type="text" placeholder="Binus" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Jurusan</label>
              <input v-model="form.major" type="text" placeholder="Informatika" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Angkatan</label>
              <input v-model="form.cohort_year" type="number" min="1990" max="2036" placeholder="2023" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Jenis akun</label>
              <select v-model="form.account_type" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
                <option value="COHORT">Angkatan</option>
                <option value="DEPARTMENT">Jurusan</option>
                <option value="STUDENT_ORG">Organisasi</option>
                <option value="OTHER">Lainnya</option>
              </select>
            </div>
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Kontak admin (opsional)</label>
            <input v-model="form.admin_contact" type="text" placeholder="Nama / WhatsApp admin, hanya jika diberikan" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Catatan pendekatan</label>
            <textarea v-model="form.notes" rows="2" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm resize-none"></textarea>
          </div>
          <p v-if="formError" class="text-sm text-urgency-red">{{ formError }}</p>
          <div class="flex gap-3 pt-2">
            <button type="button" @click="showForm = false" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant font-bold text-sm">Batal</button>
            <button type="submit" :disabled="savingForm" class="flex-1 px-4 py-2.5 rounded-xl bg-accent-fill text-white font-bold text-sm disabled:opacity-60">
              {{ savingForm ? 'Menyimpan...' : (editingId ? 'Simpan Perubahan' : 'Simpan') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </SideNav>
</template>
