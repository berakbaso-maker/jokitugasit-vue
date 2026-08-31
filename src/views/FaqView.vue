<script setup>
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo JokiTugasIT.id, saya mau tanya tentang layanan kalian.'

const faqs = [
  { q: 'Berapa harga jasa bantu tugas IT?', a: 'Mulai dari Rp10 ribu tergantung tingkat kesulitan dan deadline. Semua transparan, diskusi dulu sebelum deal, nggak ada biaya tersembunyi.' },
  { q: 'Apakah bisa dikerjakan hari ini / deadline mepet?', a: 'Bisa. Kami biasa ngerjain project yang deadline-nya hari ini juga. Pilih opsi "Hari Ini" saat kirim request, atau langsung chat WhatsApp biar dijadwalkan.' },
  { q: 'Jenis tugas IT apa saja yang bisa dibantu?', a: 'Website, aplikasi mobile, database & API, debug kode error (termasuk hasil ChatGPT), tugas kuliah pemrograman, sampai bagian coding skripsi.' },
  { q: 'Apakah data / project saya aman?', a: 'Aman. Semua data dan project dirahasiakan dan nggak akan disebar ke siapa pun. Privasi kamu prioritas.' },
  { q: 'Bagaimana cara pembayarannya?', a: 'Bayar DP dulu, sisa pelunasan setelah project selesai dan kamu review. Metode transfer bank / e-wallet.' },
  { q: 'Kalau hasilnya masih error, gimana?', a: 'Kami kasih revisi sampai project benar-benar jalan sesuai kesepakatan awal. Tinggal bilang apa yang masih kurang.' },
  { q: 'Apakah bisa minta revisi?', a: 'Bisa. Revisi wajar dan sesuai scope kesepakatan dibantu sampai beres.' },
  { q: 'Apakah saya perlu jago coding untuk pakai jasa ini?', a: 'Nggak perlu. Kamu cukup ceritakan masalah atau tugasnya dengan bahasa sederhana, kami yang urus teknisnya.' },
]

const open = ref(0)

// JSON-LD FAQPage untuk SEO
const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: faqs.map((f) => ({
    '@type': 'Question',
    name: f.q,
    acceptedAnswer: { '@type': 'Answer', text: f.a },
  })),
}
onMounted(() => {
  const existing = document.getElementById('faq-jsonld')
  if (!existing) {
    const script = document.createElement('script')
    script.id = 'faq-jsonld'
    script.type = 'application/ld+json'
    script.textContent = JSON.stringify(faqSchema)
    document.head.appendChild(script)
  }
})
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Header -->
      <section class="text-center max-w-2xl mx-auto mb-12">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <span class="material-symbols-outlined text-electric-blue text-[18px]">help</span>
          <span class="font-label-sm text-label-sm text-secondary">Tanya Jawab</span>
        </div>
        <h1 class="font-headline-lg text-headline-lg md:text-display-hero-mobile font-bold text-on-surface mb-3">Pertanyaan yang sering ditanya</h1>
        <p class="text-body-lg font-body-lg text-on-surface-variant">Masih ragu? Baca dulu jawaban di bawah, atau langsung chat kami.</p>
      </section>

      <!-- FAQ Accordion -->
      <section class="max-w-3xl mx-auto space-y-3 mb-12">
        <div v-for="(f, i) in faqs" :key="i"
          class="bg-surface-white rounded-xl border border-border-subtle shadow-sm overflow-hidden">
          <button
            class="w-full flex items-center justify-between gap-4 px-5 py-4 text-left hover:bg-surface-container-low transition-colors"
            @click="open = open === i ? -1 : i"
            :aria-expanded="open === i"
          >
            <span class="font-label-bold text-label-bold text-on-surface">{{ f.q }}</span>
            <span class="material-symbols-outlined text-electric-blue shrink-0 transition-transform duration-200" :class="open === i ? 'rotate-180' : ''">expand_more</span>
          </button>
          <div v-if="open === i" class="px-5 pb-4 text-body-md text-body-md text-on-surface-variant leading-7">{{ f.a }}</div>
        </div>
      </section>

      <!-- CTA -->
      <section class="max-w-3xl mx-auto text-center bg-surface-container rounded-2xl p-10">
        <span class="material-symbols-outlined text-4xl text-electric-blue mb-3" style="font-variation-settings: 'FILL' 1">support_agent</span>
        <h2 class="font-headline-md text-headline-md font-bold mb-2">Pertanyaanmu nggak ada di sini?</h2>
        <p class="text-body-md text-body-md text-secondary mb-6">Chat aja langsung, kami jawab secepatnya.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-electric-blue text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-primary transition-colors shadow-md">Chat WhatsApp</a>
          <RouterLink to="/request" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-primary-fixed/20 transition-colors">Kirim Request</RouterLink>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
