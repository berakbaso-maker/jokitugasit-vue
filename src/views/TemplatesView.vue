<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import { createTemplate, listTemplates, renderTemplate, updateTemplate } from '../lib/outreach'
import { pesanGalat } from '../lib/galat'

const CATEGORY_LABELS = {
  ADMIN: 'Admin Angkatan',
  DIRECT: 'Direct Client',
  DUAL_OFFER: 'Tawaran Ganda',
  REFERRAL: 'Referral',
  WEBSITE_REPLY: 'Balasan Website',
  OPT_OUT: 'Penolakan',
}

const PLACEHOLDERS = [
  { token: '{name}', hint: 'Nama panggilan prospek' },
  { token: '{campus}', hint: 'Kampus prospek' },
  { token: '{cohort}', hint: 'Angkatan' },
  { token: '{website_url}', hint: 'Link website kamu' },
]

const loading = ref(true)
const saving = ref(false)
const error = ref('')
const notice = ref('')
const templates = ref([])
const activeId = ref(null)

const draft = ref({ name: '', category: 'DUAL_OFFER', body: '', is_active: true, sort_order: 0 })

const active = computed(() => templates.value.find(t => t.id === activeId.value) || null)

const preview = computed(() => renderTemplate(draft.value.body, {
  prospect: { display_name: 'Andi', campus: 'Binus', cohort_year: 2023 },
  websiteUrl: 'https://jokitugasit.my.id',
}))

const unknownPlaceholders = computed(() => {
  const found = [...String(draft.value.body).matchAll(/\{(\w+)\}/g)].map(m => m[1])
  const known = ['name', 'nama', 'display_name', 'campus', 'kampus', 'cohort', 'angkatan', 'cohort_year', 'website_url', 'website', 'link']
  return [...new Set(found.filter(f => !known.includes(f.toLowerCase())))]
})

async function load(selectId = null) {
  loading.value = true
  error.value = ''
  try {
    templates.value = await listTemplates({ activeOnly: false })
    const target = selectId || activeId.value || templates.value[0]?.id
    if (target) selectTemplate(target)
  } catch (err) {
    error.value = err.message.includes('relation')
      ? 'Schema outreach belum dipasang. Jalankan supabase/migration-outreach-schema.sql.'
      : pesanGalat(err, 'Gagal memuat template.')
  } finally {
    loading.value = false
  }
}

function selectTemplate(id) {
  const tpl = templates.value.find(t => t.id === id)
  if (!tpl) return
  activeId.value = id
  draft.value = {
    name: tpl.name,
    category: tpl.category,
    body: tpl.body,
    is_active: tpl.is_active,
    sort_order: tpl.sort_order,
  }
  notice.value = ''
  error.value = ''
}

async function save() {
  if (!activeId.value) return
  if (!draft.value.name.trim() || !draft.value.body.trim()) {
    error.value = 'Nama dan isi template wajib diisi.'
    return
  }
  saving.value = true
  error.value = ''
  try {
    const updated = await updateTemplate(activeId.value, {
      name: draft.value.name.trim(),
      category: draft.value.category,
      body: draft.value.body,
      is_active: draft.value.is_active,
      sort_order: Number(draft.value.sort_order) || 0,
    })
    const idx = templates.value.findIndex(t => t.id === updated.id)
    if (idx >= 0) templates.value[idx] = updated
    notice.value = 'Template disimpan.'
  } catch (err) {
    error.value = pesanGalat(err, 'Gagal menyimpan template.')
  } finally {
    saving.value = false
  }
}

async function duplicate() {
  if (!active.value) return
  saving.value = true
  error.value = ''
  try {
    const created = await createTemplate({
      name: `${active.value.name} (salinan)`,
      category: active.value.category,
      body: active.value.body,
      is_active: false,
      sort_order: (active.value.sort_order || 0) + 1,
    })
    templates.value.push(created)
    selectTemplate(created.id)
    notice.value = 'Salinan dibuat (nonaktif).'
  } catch (err) {
    error.value = pesanGalat(err, 'Gagal menyalin template.')
  } finally {
    saving.value = false
  }
}

function insertToken(token) {
  draft.value.body = `${draft.value.body}${draft.value.body.endsWith(' ') || !draft.value.body ? '' : ' '}${token}`
}

onMounted(() => load())
</script>

<template>
  <SideNav>
    <div class="mb-7">
      <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2">Outreach</p>
      <h1 class="text-headline-lg font-bold">Template DM</h1>
      <p class="text-secondary mt-2 max-w-2xl">
        Placeholder hanya diisi dari data yang benar-benar ada. Data yang tidak tersedia dibiarkan terlihat supaya tidak terkirim setengah jadi.
      </p>
    </div>

    <div v-if="error" class="mb-5 flex items-start gap-2 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-on-error-container">
      <span class="material-symbols-outlined text-[18px]">error</span>
      <span class="text-sm">{{ error }}</span>
    </div>
    <div v-if="notice" class="mb-5 flex items-start gap-2 rounded-xl border border-success-green/30 bg-success-green/10 p-4">
      <span class="material-symbols-outlined text-[18px] text-success-green">check_circle</span>
      <span class="text-sm">{{ notice }}</span>
    </div>

    <div v-if="loading" class="text-center py-16 text-on-surface-variant">
      <span class="material-symbols-outlined text-[40px] animate-spin">progress_activity</span>
    </div>

    <div v-else class="grid lg:grid-cols-[260px_1fr] gap-6 items-start">
      <nav class="space-y-1">
        <button
          v-for="t in templates"
          :key="t.id"
          @click="selectTemplate(t.id)"
          class="w-full text-left px-3 py-2.5 rounded-lg text-sm transition-colors"
          :class="activeId === t.id ? 'bg-accent-fill text-white font-bold' : 'hover:bg-surface-container text-on-surface'"
        >
          <span class="block truncate">{{ t.name }}</span>
          <span class="block text-[11px] mt-0.5" :class="activeId === t.id ? 'text-white/70' : 'text-on-surface-variant'">
            {{ CATEGORY_LABELS[t.category] || t.category }}
            <template v-if="!t.is_active"> · nonaktif</template>
          </span>
        </button>
      </nav>

      <div v-if="active" class="space-y-5">
        <div class="bg-surface-white rounded-xl border border-border-subtle p-5 space-y-4">
          <div class="grid sm:grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Nama template</label>
              <input v-model="draft.name" type="text" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5 text-sm">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Kategori</label>
              <select v-model="draft.category" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-2.5 text-sm">
                <option v-for="(label, key) in CATEGORY_LABELS" :key="key" :value="key">{{ label }}</option>
              </select>
            </div>
          </div>

          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Isi pesan</label>
            <textarea v-model="draft.body" rows="10" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm leading-relaxed"></textarea>
            <div class="flex flex-wrap gap-1.5 mt-2">
              <button
                v-for="p in PLACEHOLDERS"
                :key="p.token"
                @click="insertToken(p.token)"
                :title="p.hint"
                class="text-[11px] font-mono px-2 py-1 rounded-md bg-surface-container hover:bg-surface-container-high"
              >
                {{ p.token }}
              </button>
            </div>
          </div>

          <div v-if="unknownPlaceholders.length" class="rounded-lg bg-amber-50 border border-amber-200 p-3 text-[11px] text-amber-800">
            Placeholder tidak dikenal: <strong class="font-mono">{{ unknownPlaceholders.join(', ') }}</strong>.
            Placeholder ini akan dibiarkan apa adanya saat pesan disalin — hapus atau ganti dengan yang didukung.
          </div>

          <div class="flex flex-wrap items-center gap-4">
            <label class="inline-flex items-center gap-2 text-sm">
              <input v-model="draft.is_active" type="checkbox" class="rounded">
              Aktif (muncul di antrean)
            </label>
            <label class="inline-flex items-center gap-2 text-sm">
              Urutan
              <input v-model="draft.sort_order" type="number" class="w-20 rounded-lg border border-outline-variant px-2 py-1 text-sm">
            </label>
          </div>

          <div class="flex gap-2 pt-1">
            <button @click="save" :disabled="saving" class="bg-accent-fill text-white font-bold text-sm px-5 py-2.5 rounded-xl hover:bg-accent-fill disabled:opacity-60">
              {{ saving ? 'Menyimpan...' : 'Simpan' }}
            </button>
            <button @click="duplicate" :disabled="saving" class="border border-outline-variant font-bold text-sm px-5 py-2.5 rounded-xl hover:bg-surface-container-low disabled:opacity-60">
              Duplikat
            </button>
          </div>
        </div>

        <div class="bg-surface-container-low rounded-xl border border-border-subtle p-5">
          <p class="text-label-sm text-on-surface-variant mb-2">Pratinjau dengan data contoh (Andi · Binus · 2023)</p>
          <p class="text-sm whitespace-pre-wrap leading-relaxed">{{ preview.text }}</p>
          <p v-if="preview.missing.length" class="text-[11px] text-amber-700 mt-3">
            Data belum tersedia: {{ preview.missing.join(', ') }}
          </p>
        </div>
      </div>
    </div>
  </SideNav>
</template>
