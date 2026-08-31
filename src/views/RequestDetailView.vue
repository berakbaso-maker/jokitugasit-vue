<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import SideNav from '../components/SideNav.vue'
import { getRequest, updateRequest, waLink, DEADLINE_LABELS, STATUS_LABELS, formatRupiah } from '../lib/api'

const route = useRoute()
const router = useRouter()

const request = ref(null)
const loading = ref(true)
const errorMsg = ref('')

const quote = ref('')
const notes = ref('')
const status = ref('consultation')
const saving = ref(false)
const savedMsg = ref('')

const ROW_CLICKABLE_CLASS = 'bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6 hover:border hover:border-electric-blue hover:shadow-lg transition-all duration-200 border border-transparent'

async function load() {
  loading.value = true
  try {
    request.value = await getRequest(route.params.id)
    if (request.value) {
      quote.value = request.value.quote_amount || ''
      notes.value = request.value.internal_notes || ''
      status.value = request.value.status || 'consultation'
    }
  } catch (err) {
    errorMsg.value = err.message || 'Gagal memuat detail request.'
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function save() {
  saving.value = true
  savedMsg.value = ''
  try {
    const patch = {
      status: status.value,
      quote_amount: quote.value ? Number(quote.value) : null,
      internal_notes: notes.value || null,
    }
    await updateRequest(request.value.id, patch)
    request.value = await getRequest(request.value.id)
    savedMsg.value = 'Perubahan tersimpan.'
    setTimeout(() => (savedMsg.value = ''), 2500)
  } catch (err) {
    savedMsg.value = err.message || 'Gagal menyimpan.'
  } finally {
    saving.value = false
  }
}

async function setStatus(next) {
  saving.value = true
  try {
    const updated = await updateRequest(request.value.id, { status: next })
    request.value = updated
    status.value = next
  } catch (err) {
    alert(err.message || 'Gagal update status.')
  } finally {
    saving.value = false
  }
}

const typeColor = (c) => {
  const colors = { web: 'bg-primary-container text-on-primary-container', data: 'bg-secondary-container text-on-secondary-container', mobile: 'bg-tertiary-container text-on-tertiary', ai: 'bg-error-container text-on-error-container', lainnya: 'bg-surface-container-high text-on-surface-variant' }
  return colors[c] || 'bg-surface-container-high text-on-surface-variant'
}
</script>

<template>
  <SideNav>
    <div v-if="loading" class="p-10 text-center">
      <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
    </div>

    <div v-else-if="errorMsg || !request" class="p-10 text-center">
      <p class="text-body-md">{{ errorMsg || 'Request tidak ditemukan' }}</p>
      <button class="mt-4 text-electric-blue font-label-bold hover:underline" @click="router.push('/dashboard')">Kembali ke Dashboard</button>
    </div>

    <template v-else>
      <!-- Header -->
      <header class="flex flex-col md:flex-row md:items-center justify-between mb-8 gap-4">
        <div class="flex items-center gap-4">
          <button class="text-secondary hover:text-electric-blue transition-colors p-2 -ml-2 rounded-full hover:bg-surface-container-low" @click="router.push('/dashboard')">
            <span class="material-symbols-outlined">arrow_back</span>
          </button>
          <div>
            <h1 class="text-headline-lg font-headline-lg text-on-background flex items-center gap-3">
              {{ request.order_no }}
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold capitalize" :class="{ 'bg-tertiary-container text-on-tertiary-container': true }">{{ STATUS_LABELS[request.status] || request.status }}</span>
            </h1>
            <p class="text-secondary mt-1 text-sm">Diajukan {{ request.created_at ? new Date(request.created_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'long' }) : '-' }}</p>
          </div>
        </div>
      </header>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left Column: Details -->
        <div class="lg:col-span-2 space-y-6">
          <section :class="ROW_CLICKABLE_CLASS">
            <h2 class="text-headline-md font-headline-md mb-4 flex items-center gap-2">
              <span class="material-symbols-outlined text-electric-blue">person</span>
              Customer Info
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <p class="text-label-sm font-label-sm text-secondary mb-1">Name</p>
                <p class="font-body-md font-medium">{{ request.customer_name }}</p>
              </div>
              <div>
                <p class="text-label-sm font-label-sm text-secondary mb-1">WhatsApp</p>
                <p class="font-body-md font-medium flex items-center gap-2">
                  +62 {{ request.whatsapp }}
                  <a
                    :href="waLink('62' + request.whatsapp, `Halo ${request.customer_name}, ini engineer JokiTugasIT.id untuk ${request.order_no}.`)"
                    target="_blank"
                    rel="noopener"
                    class="text-electric-blue hover:text-primary transition-colors inline-flex items-center"
                  >
                    <span class="material-symbols-outlined text-sm">chat</span>
                  </a>
                </p>
              </div>
            </div>
          </section>

          <section :class="ROW_CLICKABLE_CLASS + ' border-l-4 border-l-urgency-red'">
            <div class="flex justify-between items-start mb-4">
              <h2 class="text-headline-md font-headline-md flex items-center gap-2 text-urgency-red">
                <span class="material-symbols-outlined">warning</span>
                Problem Description
              </h2>
              <div class="px-3 py-1 bg-error-container text-on-error-container rounded-full text-xs font-bold flex items-center gap-1">
                <span class="material-symbols-outlined text-[16px]">schedule</span>
                {{ DEADLINE_LABELS[request.deadline] || request.deadline }}
              </div>
            </div>
            <div class="mb-6">
              <div class="flex gap-2 mb-3">
                <span class="px-3 py-1 bg-surface-container-low text-primary rounded-full text-xs font-semibold capitalize">{{ request.category }}</span>
              </div>
              <div class="bg-surface-container-lowest p-4 rounded-lg border border-border-subtle">
                <p class="font-body-md italic text-on-surface-variant">"{{ request.description }}"</p>
              </div>
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 pt-4 border-t border-border-subtle">
              <div>
                <h3 class="text-label-sm font-label-sm text-secondary mb-2">Attachments</h3>
                <div class="space-y-2">
                  <a v-if="request.file_url" class="flex items-center gap-2 p-2 rounded-lg bg-surface-container-low hover:bg-surface-container-high transition-colors" :href="request.file_url" target="_blank" rel="noopener">
                    <span class="material-symbols-outlined text-electric-blue">folder_zip</span>
                    <span class="text-sm truncate">Lihat file lampiran</span>
                  </a>
                  <p v-else class="text-sm text-outline">Tidak ada lampiran.</p>
                </div>
              </div>
              <div>
                <h3 class="text-label-sm font-label-sm text-secondary mb-2">Links</h3>
                <a v-if="request.link" class="flex items-center gap-2 p-2 rounded-lg bg-surface-container-low hover:bg-surface-container-high transition-colors text-electric-blue" :href="request.link" target="_blank" rel="noopener">
                  <span class="material-symbols-outlined">link</span>
                  <span class="text-sm truncate underline">{{ request.link }}</span>
                </a>
                <p v-else class="text-sm text-outline">Tidak ada link.</p>
              </div>
            </div>
          </section>
        </div>

        <!-- Right Column: Action Panel -->
        <div class="space-y-6">
          <section class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-6 sticky top-24" :class="request.deadline === 'hari_ini' ? 'border-l-4 border-l-urgency-red' : ''">
            <h2 class="text-headline-md font-headline-md mb-6 border-b border-border-subtle pb-4">Actions</h2>

            <div class="mb-6 bg-surface-container-low p-4 rounded-lg">
              <p class="text-label-sm font-label-sm text-secondary mb-1">Customer Budget Estimate</p>
              <p class="font-headline-md text-primary font-bold">{{ request.budget_estimate ? formatRupiah(request.budget_estimate) : 'Belum diisi' }}</p>
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Your Quote (Rp)</label>
              <input v-model="quote" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3" placeholder="e.g. 200000" type="number" />
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Internal Notes</label>
              <textarea v-model="notes" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3 min-h-[100px]" placeholder="Note for yourself..."></textarea>
            </div>

            <div class="mb-6">
              <label class="block text-label-bold font-label-bold mb-2">Update Status</label>
              <select v-model="status" class="w-full rounded-xl border-border-subtle focus:border-electric-blue focus:ring focus:ring-electric-blue/20 transition-all font-body-md p-3 bg-surface-white capitalize">
                <option value="consultation">Consultation</option>
                <option value="working">Sedang dikerjakan</option>
                <option value="review">Menunggu review</option>
                <option value="done">Done</option>
                <option value="paid">Paid</option>
              </select>
            </div>

            <div v-if="savedMsg" class="mb-4 text-success-green font-label-bold text-sm">{{ savedMsg }}</div>

            <button
              class="w-full bg-electric-blue hover:bg-primary text-white font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all shadow-md disabled:opacity-60 mb-4"
              :disabled="saving"
              @click="save"
            >
              {{ saving ? 'Menyimpan...' : 'Simpan' }}
            </button>

            <div class="space-y-3">
              <a
                :href="waLink('62' + (request.whatsapp || ''), `Halo ${request.customer_name}, ini engineer JokiTugasIT.id untuk ${request.order_no}.`)"
                target="_blank"
                rel="noopener"
                class="w-full bg-[#25D366] hover:bg-[#1EBE5D] text-white font-label-bold text-label-bold py-3 rounded-xl flex items-center justify-center gap-2 active:scale-95 transition-all shadow-md"
              >
                <span class="material-symbols-outlined">chat</span>
                Chat WhatsApp
              </a>
              <div class="grid grid-cols-2 gap-3 pt-4 border-t border-border-subtle">
                <button class="bg-electric-blue hover:bg-primary text-white font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all text-center" @click="setStatus('working')">Mark as Working</button>
                <button class="bg-success-green hover:bg-green-600 text-white font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all text-center flex items-center justify-center gap-1" @click="setStatus('done')">
                  <span class="material-symbols-outlined text-sm">done_all</span> Done
                </button>
              </div>
              <button class="w-full bg-transparent border border-electric-blue text-electric-blue hover:bg-surface-container-low font-label-bold text-label-bold py-3 rounded-xl active:scale-95 transition-all text-center mt-2" @click="setStatus('paid')">
                Mark as Paid
              </button>
            </div>
          </section>
        </div>
      </div>
    </template>
  </SideNav>
</template>