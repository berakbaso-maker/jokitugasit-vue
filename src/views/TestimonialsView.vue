<script setup>
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { supabase } from '../lib/supabase'
import { waLink } from '../lib/tautan'
import { testimoniContoh } from '../lib/testimoni-contoh'

const testimonials = ref([])
const loading = ref(true)
const errorMsg = ref('')
// true bila yang tampil adalah data contoh (tabel masih kosong / gagal dimuat)
const pakaiContoh = ref(false)

// Form submit testimoni
const form = ref({ name: '', role: '', rating: 5, message: '', project_type: '' })
const submitting = ref(false)
const submitMsg = ref('')

const RATINGS = [5, 4, 3, 2, 1]

async function loadTestimonials() {
  loading.value = true
  const { data, error } = await supabase
    .from('testimonials')
    .select('*')
    .eq('is_published', true)
    .order('created_at', { ascending: false })
  if (error) {
    // Tabel belum ada atau jaringan gagal: pakai data contoh supaya
    // halaman tidak kosong saat pengembangan.
    testimonials.value = testimoniContoh
    pakaiContoh.value = true
  } else if (!data || data.length === 0) {
    // Tabel ada tapi belum ada testimoni terbit.
    testimonials.value = testimoniContoh
    pakaiContoh.value = true
  } else {
    testimonials.value = data
    pakaiContoh.value = false
  }
  loading.value = false
}

async function submitTestimonial() {
  submitMsg.value = ''
  if (!form.value.name.trim() || !form.value.message.trim()) {
    submitMsg.value = 'Nama dan pesan wajib diisi.'
    return
  }
  submitting.value = true
  const { error } = await supabase.from('testimonials').insert({
    name: form.value.name.trim(),
    role: form.value.role.trim() || null,
    rating: form.value.rating,
    message: form.value.message.trim(),
    project_type: form.value.project_type.trim() || null,
    is_published: false,
  })
  submitting.value = false
  if (error) {
    submitMsg.value = 'Gagal kirim testimoni. Coba lagi.'
  } else {
    submitMsg.value = 'success'
    form.value = { name: '', role: '', rating: 5, message: '', project_type: '' }
  }
}

function stars(rating) {
  return '★'.repeat(rating) + '☆'.repeat(5 - rating)
}

onMounted(loadTestimonials)
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main id="konten-utama" tabindex="-1" class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Header -->
      <section class="text-center max-w-2xl mx-auto mb-12">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-1.5 shadow-sm mb-4">
          <span class="material-symbols-outlined text-amber-600 text-[18px]">star</span>
          <span class="font-label-sm text-label-sm text-secondary">Testimoni Mahasiswa</span>
        </div>
        <h1 class="font-display-hero-mobile md:font-display-hero text-display-hero-mobile md:text-display-hero font-bold text-on-surface mb-4">Kata Mereka yang Sudah Beres</h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-xl mx-auto">Cerita nyata dari mahasiswa yang mentok tugas IT, lalu dibantu sampai kelar.</p>
      </section>

      <!-- Stats: hanya angka yang bisa dipertanggungjawabkan -->
      <section class="grid grid-cols-3 gap-4 max-w-2xl mx-auto mb-12">
        <div class="bg-surface-white rounded-xl border border-border-subtle p-4 text-center shadow-sm">
          <div class="font-display-hero-mobile text-display-hero-mobile font-extrabold text-electric-blue">16</div>
          <div class="text-xs text-secondary mt-1">Studi Kasus</div>
        </div>
        <div class="bg-surface-white rounded-xl border border-border-subtle p-4 text-center shadow-sm">
          <div class="font-display-hero-mobile text-display-hero-mobile font-extrabold text-electric-blue">{{ testimonials.length }}</div>
          <div class="text-xs text-secondary mt-1">Cerita Tampil</div>
        </div>
        <div class="bg-surface-white rounded-xl border border-border-subtle p-4 text-center shadow-sm">
          <div class="font-display-hero-mobile text-display-hero-mobile font-extrabold text-electric-blue">Manual</div>
          <div class="text-xs text-secondary mt-1">Review Sebelum Terbit</div>
        </div>
      </section>

      <p v-if="pakaiContoh" class="max-w-2xl mx-auto mb-6 rounded-lg border border-border-subtle bg-surface-container-low px-4 py-3 text-xs text-secondary text-center">
        Menampilkan contoh testimoni. Data asli akan muncul setelah ada kiriman yang lolos review.
      </p>

      <!-- List Testimoni -->
      <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 mb-14">
        <div v-for="t in testimonials" :key="t.id" class="bg-surface-white rounded-2xl p-6 border border-border-subtle shadow-sm hover:shadow-md hover:border-electric-blue transition-all flex flex-col">
          <div class="text-amber-600 text-lg mb-3 tracking-wider">{{ stars(t.rating) }}</div>
          <p class="text-sm text-on-surface-variant leading-6 mb-4 flex-grow italic">"{{ t.message }}"</p>
          <div class="border-t border-border-subtle pt-3">
            <div class="font-label-bold text-label-bold text-on-surface">{{ t.name }}</div>
            <div class="text-xs text-secondary">{{ t.role || 'Mahasiswa' }}</div>
            <div v-if="t.project_type" class="mt-2 inline-block bg-primary-fixed/40 text-electric-blue text-[11px] px-2 py-0.5 rounded-full">{{ t.project_type }}</div>
          </div>
        </div>
        <div v-if="!loading && testimonials.length === 0" class="col-span-full text-center text-secondary py-10">Belum ada testimoni.</div>
      </section>

      <!-- Form Testimoni -->
      <section class="bg-surface-white rounded-2xl p-6 md:p-8 border border-border-subtle shadow-sm max-w-2xl mx-auto mb-12">
        <h2 class="font-headline-lg text-headline-lg font-bold text-on-surface mb-2 text-center">Sudah Pernah Dibantu? Ceritain!</h2>
        <p class="text-sm text-secondary text-center mb-6">Testimoni kamu bakal muncul setelah direview engineer.</p>
        <form class="space-y-4" @submit.prevent="submitTestimonial">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-1.5" for="t-name">Nama</label>
              <input id="t-name" v-model="form.name" type="text" placeholder="Contoh: Rina"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none" />
            </div>
            <div>
              <label class="block font-label-bold text-label-bold text-on-background mb-1.5" for="t-role">Status (opsional)</label>
              <input id="t-role" v-model="form.role" type="text" placeholder="Mahasiswa Informatika"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none" />
            </div>
          </div>
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-1.5">Rating</label>
            <div class="flex gap-1">
              <button v-for="r in RATINGS" :key="r" type="button" @click="form.rating = r"
                class="text-2xl transition-colors" :class="r <= form.rating ? 'text-amber-600' : 'text-border-subtle'">★</button>
            </div>
          </div>
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-1.5" for="t-msg">Cerita pengalamanmu</label>
            <textarea id="t-msg" v-model="form.message" rows="3" placeholder="Tugas apa yang dibantu? Gimana hasilnya?"
              class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none resize-none"></textarea>
          </div>
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-1.5" for="t-proj">Jenis project (opsional)</label>
            <input id="t-proj" v-model="form.project_type" type="text" placeholder="CRUD PHP / Flutter / Skripsi"
              class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none" />
          </div>

          <div v-if="submitMsg === 'success'" class="bg-success-green/10 text-success-green rounded-lg px-4 py-3 font-body-md text-body-md">
            ✅ Makasih! Testimoni kamu bakal tampil setelah direview.
          </div>
          <div v-else-if="submitMsg" class="bg-error-container text-on-error-container rounded-lg px-4 py-3 font-body-md text-body-md">
            {{ submitMsg }}
          </div>

          <button type="submit" :disabled="submitting"
            class="w-full bg-accent-fill text-white font-label-bold text-label-bold py-3.5 rounded-xl hover:bg-accent-fill transition-colors shadow-md disabled:opacity-60">
            {{ submitting ? 'Mengirim...' : 'Kirim Testimoni' }}
          </button>
        </form>
      </section>

      <!-- CTA -->
      <section class="text-center">
        <h2 class="font-headline-lg text-headline-lg font-bold text-on-surface mb-3">Mau Rasain Sendiri?</h2>
        <p class="text-secondary mb-6">Konsultasi gratis, cek project gratis. Ceritain aja masalahmu.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-accent-fill text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl shadow-md">Kirim Project</RouterLink>
          <a :href="waLink('6285166337257', 'Halo, saya lihat testimoni dan mau konsultasi tugas IT.')" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl">Chat WhatsApp</a>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
