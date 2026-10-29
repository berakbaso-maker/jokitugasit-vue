<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  createInstagramPost,
  IG_LEAD_STATUS,
  IG_POST_STATUS,
  listInstagramInsights,
  listInstagramLeads,
  listInstagramPosts,
  updateInstagramLead,
} from '../lib/instagram'

const tab = ref('leads')
const leads = ref([])
const posts = ref([])
const insights = ref([])
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const statusFilter = ref('all')
const form = ref({ caption: '', media_url: '', media_type: 'IMAGE', scheduled_at: '' })

const visibleLeads = computed(() => statusFilter.value === 'all'
  ? leads.value
  : leads.value.filter((lead) => lead.status === statusFilter.value))
const latestInsight = computed(() => insights.value[0] || {})

async function load() {
  loading.value = true
  error.value = ''
  try {
    ;[leads.value, posts.value, insights.value] = await Promise.all([
      listInstagramLeads(),
      listInstagramPosts(),
      listInstagramInsights(),
    ])
  } catch (err) {
    error.value = err.message.includes('relation')
      ? 'Schema Instagram belum dipasang. Jalankan supabase/ig-schema.sql terlebih dahulu.'
      : err.message
  } finally {
    loading.value = false
  }
}

async function setLeadStatus(lead, status) {
  const previous = lead.status
  lead.status = status
  try {
    await updateInstagramLead(lead.id, { status })
  } catch (err) {
    lead.status = previous
    error.value = err.message
  }
}

async function queuePost() {
  if (!form.value.media_url || !form.value.caption) return
  saving.value = true
  error.value = ''
  try {
    const post = await createInstagramPost({
      ...form.value,
      scheduled_at: form.value.scheduled_at ? new Date(form.value.scheduled_at).toISOString() : null,
      status: form.value.scheduled_at ? 'scheduled' : 'draft',
    })
    posts.value.unshift(post)
    form.value = { caption: '', media_url: '', media_type: 'IMAGE', scheduled_at: '' }
    tab.value = 'posts'
  } catch (err) {
    error.value = err.message
  } finally {
    saving.value = false
  }
}

function formatDate(value) {
  return value ? new Date(value).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' }) : '-'
}

onMounted(load)
</script>

<template>
  <SideNav>
    <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-4 mb-7">
      <div>
        <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2">Social Operations</p>
        <h1 class="text-headline-lg font-bold">Instagram Command Center</h1>
        <p class="text-secondary mt-2">Lead, antrean konten, dan insight untuk akun JokiTugasIT.</p>
      </div>
      <div class="flex items-center gap-2 rounded-full bg-surface-white border border-border-subtle px-4 py-2 shadow-sm">
        <span class="w-2.5 h-2.5 rounded-full bg-success-green"></span>
        <span class="text-label-bold font-bold">Hermes + 9router</span>
      </div>
    </div>

    <div v-if="error" class="mb-5 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-on-error-container">{{ error }}</div>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-7">
      <div class="rounded-xl bg-surface-white p-4 shadow-sm"><p class="text-label-sm text-secondary">Lead Baru</p><p class="text-3xl font-extrabold mt-2">{{ leads.filter((l) => l.status === 'new').length }}</p></div>
      <div class="rounded-xl bg-surface-white p-4 shadow-sm"><p class="text-label-sm text-secondary">Konten Terjadwal</p><p class="text-3xl font-extrabold mt-2">{{ posts.filter((p) => p.status === 'scheduled').length }}</p></div>
      <div class="rounded-xl bg-surface-white p-4 shadow-sm"><p class="text-label-sm text-secondary">Followers</p><p class="text-3xl font-extrabold mt-2">{{ latestInsight.followers_count || 0 }}</p></div>
      <div class="rounded-xl bg-primary-container p-4 shadow-sm"><p class="text-label-sm text-on-primary-container">Reach Hari Terakhir</p><p class="text-3xl font-extrabold mt-2 text-on-primary-container">{{ latestInsight.reach || 0 }}</p></div>
    </div>

    <div class="flex gap-2 overflow-x-auto mb-5">
      <button v-for="item in [{id:'outbound',label:'🚀 Outreach'},{id:'leads',label:'Lead Instagram'},{id:'posts',label:'Antrean Konten'},{id:'compose',label:'Buat Konten'},{id:'insights',label:'Insight'}]" :key="item.id" class="whitespace-nowrap rounded-full px-4 py-2 font-bold transition" :class="tab === item.id ? 'bg-electric-blue text-white' : 'bg-surface-white text-on-surface border border-border-subtle'" @click="tab = item.id">{{ item.label }}</button>
    </div>

    <div v-if="loading" class="rounded-xl bg-surface-white p-12 text-center"><span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span></div>

    <!-- OUTBOUND: dipindahkan ke halaman antrean terpisah -->
    <section v-else-if="tab === 'outbound'" class="space-y-5">
      <div class="bg-surface-white rounded-2xl border border-border-subtle p-5 md:p-7 shadow-sm">
        <span class="text-xs font-bold text-electric-blue uppercase tracking-wider">Outreach</span>
        <h2 class="text-lg font-bold text-on-surface mt-1">Antrean DM sekarang punya halaman sendiri</h2>
        <p class="text-sm text-secondary mt-2 max-w-2xl">
          Template yang dulu tertanam di sini sudah dipindahkan ke database, dan setiap pesan
          dicatat per prospek — bukan sekadar penghitung harian di browser.
        </p>
        <p class="text-sm text-secondary mt-2 max-w-2xl">
          Tidak ada ambang jumlah DM yang dijamin aman. Batas yang berlaku adalah penilaian
          manualmu atas relevansi dan izin penerima.
        </p>
        <div class="flex flex-wrap gap-2 mt-5">
          <RouterLink to="/ops/outreach" class="inline-flex items-center gap-2 bg-electric-blue text-white font-bold text-sm px-4 py-2.5 rounded-xl hover:bg-primary transition-colors">
            <span class="material-symbols-outlined text-[18px]">send</span>
            Buka Antrean DM
          </RouterLink>
          <RouterLink to="/ops/prospects" class="inline-flex items-center gap-2 border border-electric-blue text-electric-blue font-bold text-sm px-4 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors">
            <span class="material-symbols-outlined text-[18px]">group</span>
            Kelola Prospek
          </RouterLink>
          <RouterLink to="/ops/templates" class="inline-flex items-center gap-2 border border-outline-variant text-on-surface font-bold text-sm px-4 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors">
            <span class="material-symbols-outlined text-[18px]">chat</span>
            Template DM
          </RouterLink>
        </div>
      </div>
    </section>

    <section v-else-if="tab === 'leads'" class="rounded-xl bg-surface-white shadow-md overflow-hidden">
      <div class="p-4 border-b border-border-subtle flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div><h2 class="font-bold text-body-lg">Lead Masuk</h2><p class="text-secondary text-label-sm">Komentar, mention, dan DM yang tersedia via API.</p></div>
        <select v-model="statusFilter" class="h-10 rounded-lg border border-outline-variant px-3 bg-white"><option value="all">Semua status</option><option v-for="(label,key) in IG_LEAD_STATUS" :key="key" :value="key">{{ label }}</option></select>
      </div>
      <div v-if="!visibleLeads.length" class="p-12 text-center text-secondary">Belum ada lead Instagram.</div>
      <div v-else class="divide-y divide-border-subtle">
        <article v-for="lead in visibleLeads" :key="lead.id" class="p-4 md:p-5 flex flex-col md:flex-row gap-4 md:items-center">
          <div class="w-11 h-11 rounded-full bg-gradient-to-br from-fuchsia-500 via-rose-500 to-amber-400 text-white flex items-center justify-center font-extrabold shrink-0">{{ (lead.username || '?').charAt(0).toUpperCase() }}</div>
          <div class="min-w-0 flex-1"><div class="flex flex-wrap gap-2 items-center"><p class="font-bold">@{{ lead.username || lead.ig_user_id }}</p><span class="text-[11px] uppercase tracking-wide rounded-full bg-surface-container-high px-2 py-1">{{ lead.source }}</span></div><p class="text-secondary mt-1 break-words">{{ lead.last_message || 'Event tanpa teks' }}</p><p class="text-label-sm text-secondary mt-2">{{ formatDate(lead.last_event_at) }}<span v-if="lead.requests"> · Request #{{ lead.requests.order_no }}</span></p></div>
          <select :value="lead.status" class="h-10 rounded-lg border border-outline-variant px-3 bg-white" @change="setLeadStatus(lead, $event.target.value)"><option v-for="(label,key) in IG_LEAD_STATUS" :key="key" :value="key">{{ label }}</option></select>
        </article>
      </div>
    </section>

    <section v-else-if="tab === 'posts'" class="grid gap-4">
      <div v-if="!posts.length" class="rounded-xl bg-surface-white p-12 text-center text-secondary">Belum ada antrean konten.</div>
      <article v-for="post in posts" :key="post.id" class="rounded-xl bg-surface-white shadow-sm p-4 flex flex-col sm:flex-row gap-4">
        <img :src="post.media_url" alt="Preview konten Instagram" class="w-full sm:w-32 h-32 object-cover rounded-lg bg-surface-container-high" loading="lazy">
        <div class="flex-1 min-w-0"><div class="flex gap-2 items-center mb-2"><span class="rounded-full bg-primary-container text-on-primary-container px-2.5 py-1 text-label-sm font-bold">{{ IG_POST_STATUS[post.status] || post.status }}</span><span class="text-label-sm text-secondary">{{ post.media_type }}</span></div><p class="whitespace-pre-wrap break-words">{{ post.caption }}</p><p class="text-label-sm text-secondary mt-3">Jadwal: {{ formatDate(post.scheduled_at) }}</p><p v-if="post.error_message" class="text-urgency-red mt-2">{{ post.error_message }}</p></div>
      </article>
    </section>

    <section v-else-if="tab === 'compose'" class="rounded-xl bg-surface-white shadow-md p-5 md:p-7 max-w-3xl">
      <h2 class="font-bold text-body-lg mb-1">Masukkan Antrean Konten</h2><p class="text-secondary mb-6">Hermes akan memproses antrean terjadwal. URL media harus publik dan dapat diakses Meta.</p>
      <form class="space-y-4" @submit.prevent="queuePost">
        <label class="block"><span class="font-bold text-label-sm">URL gambar/video</span><input v-model.trim="form.media_url" type="url" required placeholder="https://..." class="mt-2 w-full h-11 rounded-lg border border-outline-variant px-4 outline-none focus:border-electric-blue"></label>
        <label class="block"><span class="font-bold text-label-sm">Caption</span><textarea v-model.trim="form.caption" required rows="6" maxlength="2200" placeholder="Tulis brief atau caption final..." class="mt-2 w-full rounded-lg border border-outline-variant p-4 outline-none focus:border-electric-blue"></textarea><span class="text-label-sm text-secondary">{{ form.caption.length }}/2200</span></label>
        <div class="grid sm:grid-cols-2 gap-4"><label><span class="font-bold text-label-sm">Format</span><select v-model="form.media_type" class="mt-2 w-full h-11 rounded-lg border border-outline-variant px-3 bg-white"><option value="IMAGE">Gambar</option><option value="REELS">Reels</option></select></label><label><span class="font-bold text-label-sm">Jadwal (opsional)</span><input v-model="form.scheduled_at" type="datetime-local" class="mt-2 w-full h-11 rounded-lg border border-outline-variant px-3"></label></div>
        <button :disabled="saving" class="h-11 px-6 rounded-lg bg-electric-blue text-white font-bold disabled:opacity-50">{{ saving ? 'Menyimpan...' : 'Masukkan Antrean' }}</button>
      </form>
    </section>

    <section v-else class="rounded-xl bg-surface-white shadow-md overflow-hidden">
      <div class="p-5 border-b border-border-subtle"><h2 class="font-bold text-body-lg">Snapshot 30 Hari</h2><p class="text-secondary text-label-sm">Diisi otomatis oleh cron Hermes melalui Graph API.</p></div>
      <div v-if="!insights.length" class="p-12 text-center text-secondary">Belum ada data insight.</div>
      <div v-else class="overflow-x-auto"><table class="w-full text-left"><thead class="bg-surface text-label-sm text-secondary uppercase"><tr><th class="p-4">Tanggal</th><th class="p-4">Followers</th><th class="p-4">Reach</th><th class="p-4">Profile Views</th><th class="p-4">Website Clicks</th></tr></thead><tbody class="divide-y divide-border-subtle"><tr v-for="row in insights" :key="row.id"><td class="p-4">{{ row.snapshot_date }}</td><td class="p-4 font-bold">{{ row.followers_count }}</td><td class="p-4">{{ row.reach }}</td><td class="p-4">{{ row.profile_views }}</td><td class="p-4">{{ row.website_clicks }}</td></tr></tbody></table></div>
    </section>
  </SideNav>
</template>
