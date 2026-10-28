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

const tab = ref('outbound')
const leads = ref([])
const posts = ref([])
const insights = ref([])
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const statusFilter = ref('all')
const form = ref({ caption: '', media_url: '', media_type: 'IMAGE', scheduled_at: '' })

// Outbound CRM State (Master Blueprint Strategi Bisnis)
const outboundTarget = ref({ name: '', campus: '', major: 'Informatika' })
const activeTemplateId = ref('template_4')
const copyDmSuccess = ref(false)
const dailyDmCount = ref(Number(localStorage.getItem('joki_daily_dm_count_' + new Date().toISOString().slice(0, 10)) || 0))

function incrementDm() {
  if (dailyDmCount.value < 20) {
    dailyDmCount.value++
    localStorage.setItem('joki_daily_dm_count_' + new Date().toISOString().slice(0, 10), String(dailyDmCount.value))
  }
}

function resetDailyDm() {
  dailyDmCount.value = 0
  localStorage.setItem('joki_daily_dm_count_' + new Date().toISOString().slice(0, 10), '0')
}

const outboundTemplates = [
  {
    id: 'template_4',
    name: 'Template 4: Dual Offer (Paling Recommended)',
    targetType: 'Mahasiswa semester 4–6 (Dua opsi: Bantuan teknis atau Komisi 10%)',
    content: (name, campus) => `Halo ${name || '[Nama]'}, salam kenal ya!

Izin sapa sesama penggiat IT di ${campus || '[Nama Kampus]'}. Aku software engineer yang udah beberapa tahun kerja di industri software.

Saat ini aku buka dua hal buat temen-temen mahasiswa IT:
1. Layanan Code Rescue & Pendampingan: bantuan benerin error kode, perbaikan fitur web/mobile, database, sampai persiapan demo tugas akhir.
2. Program Student Partner (Komisi 10%): kalau ada temenmu yang butuh bantuan teknis dan kamu referensikan ke aku, kamu dapet komisi 10% dari nilai transaksinya.

Jadi kamu bisa pakai bantuannya langsung kalau lagi mentok ngoding, atau dapet uang saku tambahan dengan jadi partner referral.

Kalau relevan, boleh aku share link website & portofolioku buat disimpan dulu?`,
  },
  {
    id: 'template_2',
    name: 'Template 2: Direct Client (Skripsi / Deadline Mepet)',
    targetType: 'Mahasiswa tingkat akhir / semester padat dengan urgensi tinggi',
    content: (name, campus) => `Halo ${name || '[Nama]'}, izin sapa ya!

Aku liat profil kamu mahasiswa IT di ${campus || '[Nama Kampus]'}. Kenalin, aku software engineer profesional di industri.

Di luar jam kerja, aku sering bantu mahasiswa IT yang lagi mentok ngerjain project—khususnya yang butuh bantuan benerin error, optimasi query database, integrasi API, atau asistensi kode skripsi/tugas akhir biar siap pas demo dosen.

Kalau kamu atau kelompokmu lagi ada project ngoding yang stuck dan butuh bantuan teknis cepat, boleh banget ngobrol dulu.

Kalau tertarik lihat portofolio dan ulasan project sebelumnya, boleh aku kirimin link websitenya?`,
  },
  {
    id: 'template_3',
    name: 'Template 3: Referral Partner (Komti / Mahasiswa Supel)',
    targetType: 'Mahasiswa aktif organisasi atau komti yang punya jaringan luas',
    content: (name, campus) => `Halo ${name || '[Nama]'}, salam kenal ya!

Liat profil kamu kayaknya cukup aktif di kampus ${campus || '[Nama Kampus]'}.

Kenalin, aku software engineer. Aku lagi buka program partner referral khusus mahasiswa IT.

Konsepnya simpel: kalau kamu punya temen seangkatan atau adek tingkat yang lagi pusing mentok ngerjain project ngoding/skripsi dan kamu rekomendasikan ke aku, kamu bakal dapet komisi 10% bersih dari nilai transaksi setelah project deal. Semua pengerjaan teknis aku yang handle 100%.

Lumayan banget buat nambah uang saku tanpa kamu harus ikut pusing ngoding.

Kira-kira tertarik denger skema partnernya lebih detail?`,
  },
  {
    id: 'template_1',
    name: 'Template 1: Soft Selling (Pendekatan Santai & Natural)',
    targetType: 'Mahasiswa umum, membuka obrolan tanpa terkesan jualan',
    content: (name, campus) => `Halo ${name || '[Nama]'}, salam kenal ya!

Aku liat kamu anak IT di ${campus || '[Nama Kampus]'}. Kebetulan aku software engineer, lagi connect sama temen-temen mahasiswa IT.

Biasanya anak IT suka pusing pas deadline praktikum atau pas kode kena bug aneh dari ChatGPT. Kalau suatu saat kamu lagi mentok ngoding atau butuh sparring partner buat debug kode project kuliah, feel free buat reach out ya.

Semoga lancar terus kuliahnya! 👍`,
  },
  {
    id: 'template_5',
    name: 'Template 5: Follow-Up Ramah (Setelah 3-4 Hari)',
    targetType: 'Prospek yang belum membalas pesan sebelumnya',
    content: (name) => `Halo ${name || '[Nama]'}, cuma mau re-connect sebentar.

Lagi persiapan UTS/UAS atau lagi sibuk project praktikum minggu ini?

Santai aja ya, nggak ada kewajiban apa-apa. Kalau nanti pas mendekati deadline ada kode yang error atau mau diskusi santai soal industri software, pintu selalu terbuka. Semangat kuliahnya! 🙌`,
  },
]

const currentGeneratedDm = computed(() => {
  const t = outboundTemplates.find(tpl => tpl.id === activeTemplateId.value) || outboundTemplates[0]
  return t.content(outboundTarget.value.name.trim(), outboundTarget.value.campus.trim())
})

function copyCurrentDm() {
  navigator.clipboard.writeText(currentGeneratedDm.value)
  copyDmSuccess.value = true
  incrementDm()
  setTimeout(() => (copyDmSuccess.value = false), 2500)
}

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
      <button v-for="item in [{id:'outbound',label:'🚀 Outbound DM Generator'},{id:'leads',label:'Lead Instagram'},{id:'posts',label:'Antrean Konten'},{id:'compose',label:'Buat Konten'},{id:'insights',label:'Insight'}]" :key="item.id" class="whitespace-nowrap rounded-full px-4 py-2 font-bold transition" :class="tab === item.id ? 'bg-electric-blue text-white' : 'bg-surface-white text-on-surface border border-border-subtle'" @click="tab = item.id">{{ item.label }}</button>
    </div>

    <div v-if="loading" class="rounded-xl bg-surface-white p-12 text-center"><span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span></div>

    <!-- OUTBOUND DM GENERATOR (MASTER BLUEPRINT) -->
    <section v-else-if="tab === 'outbound'" class="space-y-6">
      <!-- Quota Tracker & Rule Banner -->
      <div class="bg-surface-white rounded-2xl border border-border-subtle p-5 md:p-6 shadow-sm">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-border-subtle">
          <div>
            <span class="text-xs font-bold text-electric-blue uppercase tracking-wider">Aturan Anti-Spam Blueprint</span>
            <h2 class="text-lg font-bold text-on-surface">Target Harian: 15–20 DM Terkirim</h2>
            <p class="text-xs text-secondary mt-0.5">Batasi 15-20 DM per hari agar akun Instagram personal aman dari shadowban/action block.</p>
          </div>
          <div class="flex items-center gap-3">
            <div class="text-right">
              <div class="text-xs text-secondary">Progres Hari Ini:</div>
              <div class="text-xl font-extrabold text-electric-blue">{{ dailyDmCount }} / 20 DM</div>
            </div>
            <button @click="incrementDm" class="bg-electric-blue text-white px-3.5 py-2 rounded-xl text-xs font-bold hover:bg-primary transition-all flex items-center gap-1 shadow-xs">
              <span class="material-symbols-outlined text-[16px]">add</span>
              +1 Terkirim
            </button>
            <button @click="resetDailyDm" title="Reset Counter" class="text-secondary hover:text-urgency-red p-2 rounded-lg transition-colors">
              <span class="material-symbols-outlined text-[18px]">restart_alt</span>
            </button>
          </div>
        </div>

        <div class="w-full bg-surface-container-high rounded-full h-2.5 mt-4 overflow-hidden">
          <div
            class="h-full rounded-full transition-all duration-300"
            :class="dailyDmCount >= 20 ? 'bg-success-green' : dailyDmCount >= 15 ? 'bg-electric-blue' : 'bg-primary-container'"
            :style="{ width: Math.min(100, (dailyDmCount / 20) * 100) + '%' }"
          ></div>
        </div>

        <div class="mt-4 pt-4 border-t border-border-subtle text-xs text-secondary flex flex-wrap gap-4 items-center">
          <span class="flex items-center gap-1"><span class="material-symbols-outlined text-success-green text-[16px]">check_circle</span> Target: Mahasiswa Kampus Swasta (Binus, Telkom, Trisakti, UMN, Mercu Buana)</span>
          <span class="flex items-center gap-1"><span class="material-symbols-outlined text-urgency-red text-[16px]">block</span> Aturan Emas: Jangan lampirkan link di pesan pertama! Tunggu balasan.</span>
        </div>
      </div>

      <!-- Generator Workspace (Grid) -->
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        <!-- Controls (Col 5) -->
        <div class="lg:col-span-5 bg-surface-white rounded-2xl border border-border-subtle p-5 shadow-sm space-y-5">
          <h3 class="font-bold text-sm text-on-surface">1. Pilih Template Blueprint</h3>
          <div class="space-y-2">
            <label
              v-for="tpl in outboundTemplates"
              :key="tpl.id"
              class="block p-3 rounded-xl border text-xs cursor-pointer transition-all"
              :class="activeTemplateId === tpl.id ? 'border-electric-blue bg-primary-fixed/20 shadow-xs' : 'border-border-subtle bg-surface-container-lowest hover:border-outline-variant'"
            >
              <input v-model="activeTemplateId" type="radio" :value="tpl.id" class="sr-only" />
              <div class="font-bold text-on-surface flex items-center justify-between">
                <span>{{ tpl.name }}</span>
                <span v-if="activeTemplateId === tpl.id" class="w-2 h-2 rounded-full bg-electric-blue"></span>
              </div>
              <p class="text-secondary mt-1 text-[11px] leading-relaxed">{{ tpl.targetType }}</p>
            </label>
          </div>

          <div class="pt-4 border-t border-border-subtle space-y-3">
            <h3 class="font-bold text-sm text-on-surface">2. Data Prospek Mahasiswa</h3>
            <div>
              <label class="block text-xs font-semibold text-secondary mb-1">Nama Panggilan Mahasiswa</label>
              <input
                v-model="outboundTarget.name"
                type="text"
                placeholder="Contoh: Budi / Kevin / Sarah"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-3.5 py-2.5 text-xs text-on-surface outline-none focus:border-electric-blue focus:ring-1 focus:ring-electric-blue"
              />
            </div>
            <div>
              <label class="block text-xs font-semibold text-secondary mb-1">Nama Kampus</label>
              <input
                v-model="outboundTarget.campus"
                type="text"
                placeholder="Contoh: Binus / Telkom / Trisakti"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-3.5 py-2.5 text-xs text-on-surface outline-none focus:border-electric-blue focus:ring-1 focus:ring-electric-blue"
              />
            </div>
          </div>
        </div>

        <!-- Preview & Copy Action (Col 7) -->
        <div class="lg:col-span-7 bg-surface-white rounded-2xl border border-border-subtle p-5 sm:p-6 shadow-sm flex flex-col justify-between space-y-4">
          <div>
            <div class="flex items-center justify-between pb-3 border-b border-border-subtle">
              <span class="text-xs font-bold text-secondary uppercase tracking-wider">Preview Pesan DM Siap Kirim</span>
              <span class="text-[11px] text-electric-blue font-semibold">Variabel otomatis terisi</span>
            </div>
            <div class="mt-4 p-4 rounded-xl bg-surface-container-low border border-border-subtle font-mono text-xs sm:text-sm text-on-surface leading-relaxed whitespace-pre-wrap select-all">
              {{ currentGeneratedDm }}
            </div>
          </div>

          <div class="pt-2 flex flex-col sm:flex-row gap-2.5">
            <button
              @click="copyCurrentDm"
              class="flex-1 bg-electric-blue text-white font-bold text-sm py-3 px-4 rounded-xl shadow-md hover:bg-primary transition-all flex items-center justify-center gap-2 active:scale-95"
            >
              <span class="material-symbols-outlined text-[18px]">content_copy</span>
              {{ copyDmSuccess ? '✓ Pesan Berhasil Disalin (+1 DM Counter)!' : 'Salin Pesan DM (+1 Count)' }}
            </button>
            <a
              :href="'https://instagram.com/direct/inbox/'"
              target="_blank"
              rel="noopener"
              class="bg-surface-white border border-border-subtle text-secondary hover:text-on-surface text-xs font-bold py-3 px-4 rounded-xl transition-colors flex items-center justify-center gap-1.5"
            >
              <span class="material-symbols-outlined text-[16px]">open_in_new</span>
              Buka Instagram Web
            </a>
          </div>
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
