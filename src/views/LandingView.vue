<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'
import { useScrollReveal } from '../composables/useScrollReveal'

// Nomor WhatsApp resmi — sama dengan yang dipakai BottomNavBar.
const WA_NUMBER = '6285166337257'
const waKonsultasi = waLink(
  WA_NUMBER,
  'Halo jokitugasit.my.id, saya ingin konsultasi project.',
)

// ---------------------------------------------------------------------------
// Layanan. Setiap entri menjawab: masalah apa yang diselesaikan, dan apa
// yang didapat. Semua route sudah ada di router (diverifikasi), bukan link
// karangan.
// ---------------------------------------------------------------------------
const layanan = [
  {
    icon: 'terminal',
    judul: 'Joki Tugas Kuliah IT',
    masalah: 'Deadline pemrograman mepet dan konsepnya belum kepahaman.',
    hasil: 'Kode jalan + penjelasan baris per baris, jadi kamu tetap bisa menjelaskan saat ditanya.',
    to: '/joki-tugas-kuliah-it',
    tag: 'Paling dicari',
  },
  {
    icon: 'school',
    judul: 'Bimbingan Skripsi IT',
    masalah: 'Bingung menyusun metode, implementasi, atau revisi dari dosen pembimbing.',
    hasil: 'Pendampingan terarah per bab, dari perancangan sampai siap sidang.',
    to: '/joki-skripsi-it',
    tag: '',
  },
  {
    icon: 'bug_report',
    judul: 'Debug & Perbaikan Error',
    masalah: 'Error yang sudah berhari-hari dicari tapi tetap tidak ketemu akarnya.',
    hasil: 'Diagnosis akar masalah, perbaikan, dan catatan agar tidak terulang.',
    to: '/joki-debug-error',
    tag: '',
  },
  {
    icon: 'code',
    judul: 'Project Web & Aplikasi',
    masalah: 'Butuh sistem yang benar-benar jadi, bukan sekadar tampilan.',
    hasil: 'Pengembangan web, mobile, desktop, hingga database dan API.',
    to: '/joki-project-web',
    tag: '',
  },
  {
    icon: 'rate_review',
    judul: 'Code Review & Mentoring',
    masalah: 'Kode sudah jalan, tapi kualitas dan strukturnya bikin ragu.',
    hasil: 'Review terstruktur plus arahan perbaikan yang bisa langsung diterapkan.',
    to: '/layanan',
    tag: '',
  },
  {
    icon: 'palette',
    judul: 'Desain UI/UX',
    masalah: 'Aplikasi berfungsi, tapi terasa berantakan dan sulit dipakai.',
    hasil: 'Perbaikan alur, hirarki visual, dan konsistensi antarmuka.',
    to: '/joki-desain-ui-ux',
    tag: '',
  },
]

// Alur kerja. Diturunkan dari halaman /cara-kerja yang sudah ada.
const alur = [
  {
    nomor: '01',
    judul: 'Ceritakan kebutuhanmu',
    isi: 'Kirim detail tugas atau project lewat form. Bisa juga langsung tanya via WhatsApp kalau masih ragu.',
    icon: 'edit_note',
  },
  {
    nomor: '02',
    judul: 'Dapat estimasi & konfirmasi',
    isi: 'Kami tinjau ruang lingkupnya, lalu beri estimasi biaya dan waktu. Tidak ada biaya sebelum kamu setuju.',
    icon: 'request_quote',
  },
  {
    nomor: '03',
    judul: 'Pengerjaan & progres terbuka',
    isi: 'Pengerjaan berjalan dengan pembaruan progres yang bisa kamu pantau lewat halaman cek status.',
    icon: 'pending_actions',
  },
  {
    nomor: '04',
    judul: 'Serah terima & penjelasan',
    isi: 'Hasil diserahkan beserta penjelasan. Revisi sesuai kesepakatan di awal, bukan tambahan mendadak.',
    icon: 'task_alt',
  },
]

// Alasan memilih. Semua klaim di sini bersifat janji proses yang bisa
// diverifikasi dari cara kerja aplikasi — bukan angka statistik karangan.
const jaminan = [
  {
    icon: 'visibility',
    judul: 'Progres bisa kamu pantau',
    isi: 'Setiap permintaan punya nomor order yang bisa dicek kapan saja lewat halaman status.',
  },
  {
    icon: 'handshake',
    judul: 'Harga disepakati di depan',
    isi: 'Estimasi diberikan sebelum pengerjaan. Tidak ada tagihan kejutan di tengah jalan.',
  },
  {
    icon: 'psychology',
    judul: 'Dijelaskan, bukan sekadar dikirim',
    isi: 'Hasil kerja disertai penjelasan agar kamu paham dan bisa mempertanggungjawabkannya.',
  },
  {
    icon: 'chat',
    judul: 'Komunikasi langsung',
    isi: 'Diskusi lewat WhatsApp dengan bahasa yang jelas, tanpa istilah teknis yang bikin bingung.',
  },
]

// FAQ singkat di beranda. Tiga pertama diambil dari /tanya-jawab.
// Empat pertanyaan ini disalin dari /tanya-jawab (FaqView.vue) agar beranda
// tidak memuat pertanyaan atau jawaban yang dikarang.
const faqSingkat = [
  {
    t: 'Berapa harga jasa bantu tugas IT?',
    j: 'Kami nggak pasang nominal di halaman ini karena tiap tugas beda tingkat kesulitannya. Ceritain dulu masalah dan budget kamu lewat WhatsApp — engineer yang tentuin, kamu yang setuju. Konsultasi gratis, tidak ada biaya tersembunyi.',
  },
  {
    t: 'Apakah bisa dikerjakan hari ini kalau deadline mepet?',
    j: 'Bisa. Project dengan deadline hari ini juga biasa ditangani. Pilih opsi "Hari Ini" saat mengirim request, atau langsung chat WhatsApp agar dijadwalkan.',
  },
  {
    t: 'Bagaimana cara pembayarannya?',
    j: 'Bayar DP dulu, sisanya dilunasi setelah project selesai dan kamu review. Metode transfer bank atau e-wallet.',
  },
  {
    t: 'Kalau hasilnya masih error, bagaimana?',
    j: 'Ada revisi sampai project benar-benar jalan sesuai kesepakatan awal. Cukup sampaikan bagian mana yang masih kurang.',
  },
]

// Program referral. Angka 10% dan waktu pencairan diambil dari halaman
// /partner yang sudah ada — bukan karangan.
const referralPoin = [
  'Komisi 10% dari nilai project yang berhasil direferensikan.',
  'Pencairan diproses maksimal 1×24 jam setelah pelunasan project.',
  'Cocok untuk mahasiswa yang ingin penghasilan tambahan tanpa modal.',
]

useScrollReveal('.reveal')
</script>

<template>
  <div class="min-h-screen bg-background font-sans text-on-surface">
    <TopAppBar />

    <main>
      <!-- ================= HERO ================= -->
      <section class="relative overflow-hidden border-b border-border-subtle">
        <!-- Latar grid halus, memudar ke bawah. Dekoratif, aria-hidden. -->
        <div class="pointer-events-none absolute inset-0 bg-grid mask-fade-b" aria-hidden="true"></div>

        <div class="relative mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
          <div class="grid items-start gap-12 lg:grid-cols-[1.05fr_0.95fr] lg:gap-16">
            <!-- Kolom kiri: pesan utama -->
            <div>
              <p class="eyebrow reveal">
                <span class="inline-block h-1.5 w-1.5 rounded-full bg-primary"></span>
                Bantuan teknis yang bisa dipertanggungjawabkan
              </p>

              <h1
                class="reveal reveal-delay-1 mt-5 text-[32px] font-extrabold leading-[1.15] tracking-tight text-on-surface md:text-[44px] lg:text-[52px]"
              >
                Butuh bantuan
                <span class="text-gradient">koding, debugging,</span>
                atau bimbingan teknis?
              </h1>

              <p class="reveal reveal-delay-2 mt-6 max-w-xl text-body-lg text-secondary">
                Kami bantu mahasiswa dan developer awal menyelesaikan tugas pemrograman,
                memperbaiki error, dan memahami kode — dengan penjelasan yang jelas,
                bukan sekadar hasil jadi.
              </p>

              <!-- Dua CTA utama -->
              <div class="reveal reveal-delay-3 mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
                <RouterLink to="/request" class="btn-primary w-full sm:w-auto">
                  <span class="material-symbols-outlined text-xl" aria-hidden="true">rocket_launch</span>
                  Mulai Konsultasi
                </RouterLink>
                <RouterLink to="/harga" class="btn-secondary w-full sm:w-auto">
                  <span class="material-symbols-outlined text-xl" aria-hidden="true">payments</span>
                  Lihat Estimasi Harga
                </RouterLink>
              </div>

              <!-- Penanda kepercayaan: fakta proses, bukan angka karangan -->
              <ul class="reveal reveal-delay-4 mt-8 flex flex-wrap items-center gap-x-6 gap-y-3 text-sm text-secondary">
                <li class="flex items-center gap-2">
                  <span class="material-symbols-outlined text-lg text-primary" aria-hidden="true">verified</span>
                  Estimasi harga sebelum bayar
                </li>
                <li class="flex items-center gap-2">
                  <span class="material-symbols-outlined text-lg text-primary" aria-hidden="true">schedule</span>
                  Progres bisa dipantau
                </li>
                <li class="flex items-center gap-2">
                  <span class="material-symbols-outlined text-lg text-primary" aria-hidden="true">forum</span>
                  Dijelaskan langsung
                </li>
              </ul>
            </div>

            <!-- Kolom kanan: kartu ringkas layanan. Tanpa foto stok/AI. -->
            <div class="reveal reveal-delay-2">
              <div class="card p-6 md:p-7">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="text-label-bold font-label-bold uppercase tracking-widest text-secondary">
                      Mulai dari sini
                    </p>
                    <h2 class="mt-2 text-headline-md font-headline-md text-on-surface">
                      Apa yang bisa kami bantu?
                    </h2>
                  </div>
                  <span
                    class="material-symbols-outlined rounded-xl bg-surface-container p-2.5 text-primary"
                    aria-hidden="true"
                    >support_agent</span
                  >
                </div>

                <ul class="mt-6 space-y-1">
                  <li v-for="item in layanan.slice(0, 4)" :key="item.judul">
                    <RouterLink
                      :to="item.to"
                      class="group flex items-center gap-3 rounded-lg px-3 py-3 transition-colors hover:bg-surface-container"
                    >
                      <span
                        class="material-symbols-outlined shrink-0 rounded-lg bg-surface-container p-2 text-lg text-primary transition-colors group-hover:bg-primary group-hover:text-on-primary"
                        aria-hidden="true"
                        >{{ item.icon }}</span
                      >
                      <span class="min-w-0 flex-1">
                        <span class="block truncate text-sm font-bold text-on-surface">{{ item.judul }}</span>
                        <span class="block truncate text-xs text-secondary">{{ item.masalah }}</span>
                      </span>
                      <span
                        class="material-symbols-outlined shrink-0 text-lg text-secondary transition-transform group-hover:translate-x-0.5 group-hover:text-primary"
                        aria-hidden="true"
                        >arrow_forward</span
                      >
                    </RouterLink>
                  </li>
                </ul>

                <RouterLink
                  to="/layanan"
                  class="mt-4 flex items-center justify-center gap-2 rounded-lg border border-border-subtle py-2.5 text-sm font-bold text-primary transition-colors hover:bg-surface-container"
                >
                  Lihat semua layanan
                  <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
                </RouterLink>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- ================= LAYANAN ================= -->
      <section id="layanan" class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
        <div class="max-w-2xl">
          <p class="eyebrow reveal">Layanan</p>
          <h2 class="reveal reveal-delay-1 mt-4 text-[28px] font-extrabold tracking-tight text-on-surface md:text-[36px]">
            Setiap masalah teknis punya jalannya sendiri
          </h2>
          <p class="reveal reveal-delay-2 mt-4 text-body-md text-secondary">
            Pilih yang paling dekat dengan situasimu. Kalau belum yakin, ceritakan saja
            kondisinya — kami arahkan ke penanganan yang tepat.
          </p>
        </div>

        <div class="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <RouterLink
            v-for="(item, i) in layanan"
            :key="item.judul"
            :to="item.to"
            class="card-interactive reveal group flex flex-col p-6"
            :class="[`reveal-delay-${(i % 3) + 1}`]"
          >
            <div class="flex items-start justify-between gap-3">
              <span
                class="material-symbols-outlined rounded-xl bg-surface-container p-3 text-primary transition-colors duration-200 group-hover:bg-primary group-hover:text-on-primary"
                aria-hidden="true"
                >{{ item.icon }}</span
              >
              <span
                v-if="item.tag"
                class="rounded-full bg-primary-fixed px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide text-on-primary-fixed"
              >
                {{ item.tag }}
              </span>
            </div>

            <h3 class="mt-5 text-lg font-bold text-on-surface">{{ item.judul }}</h3>

            <!-- Masalah -> hasil. Ini yang membedakan dari daftar layanan generik. -->
            <dl class="mt-4 flex-1 space-y-3 text-sm">
              <div>
                <dt class="font-bold uppercase tracking-wide text-xs text-secondary">Masalahnya</dt>
                <dd class="mt-1 text-secondary">{{ item.masalah }}</dd>
              </div>
              <div>
                <dt class="font-bold uppercase tracking-wide text-xs text-secondary">Yang kamu dapat</dt>
                <dd class="mt-1 text-on-surface">{{ item.hasil }}</dd>
              </div>
            </dl>

            <span class="mt-5 flex items-center gap-1.5 text-sm font-bold text-primary">
              Selengkapnya
              <span
                class="material-symbols-outlined text-base transition-transform duration-200 group-hover:translate-x-0.5"
                aria-hidden="true"
                >arrow_forward</span
              >
            </span>
          </RouterLink>
        </div>
      </section>

      <!-- ================= CARA KERJA ================= -->
      <section class="border-y border-border-subtle bg-surface-container-low">
        <div class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
          <div class="max-w-2xl">
            <p class="eyebrow reveal">Cara kerja</p>
            <h2 class="reveal reveal-delay-1 mt-4 text-[28px] font-extrabold tracking-tight text-on-surface md:text-[36px]">
              Empat langkah, tanpa kejutan
            </h2>
            <p class="reveal reveal-delay-2 mt-4 text-body-md text-secondary">
              Kamu tahu persis apa yang terjadi di setiap tahap, dan biayanya disepakati sebelum kerja dimulai.
            </p>
          </div>

          <ol class="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-4">
            <li
              v-for="(step, i) in alur"
              :key="step.nomor"
              class="card reveal relative p-6"
              :class="[`reveal-delay-${i + 1}`]"
            >
              <div class="flex items-center justify-between">
                <span
                  class="material-symbols-outlined rounded-xl bg-primary-fixed p-2.5 text-primary"
                  aria-hidden="true"
                  >{{ step.icon }}</span
                >
                <span class="text-2xl font-extrabold tabular-nums text-surface-container-high" aria-hidden="true">
                  {{ step.nomor }}
                </span>
              </div>
              <h3 class="mt-5 text-base font-bold text-on-surface">{{ step.judul }}</h3>
              <p class="mt-2 text-sm leading-relaxed text-secondary">{{ step.isi }}</p>
            </li>
          </ol>
        </div>
      </section>

      <!-- ================= JAMINAN ================= -->
      <section class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
        <div class="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:gap-16">
          <div>
            <p class="eyebrow reveal">Kenapa kami</p>
            <h2 class="reveal reveal-delay-1 mt-4 text-[28px] font-extrabold tracking-tight text-on-surface md:text-[36px]">
              Bantuan teknis yang tidak membuatmu bergantung
            </h2>
            <p class="reveal reveal-delay-2 mt-4 text-body-md text-secondary">
              Tujuan kami bukan menyelesaikan satu tugas lalu selesai. Kami ingin kamu
              keluar dari percakapan ini dengan pemahaman yang lebih baik.
            </p>

            <!-- Blok sorotan, bukan kartu statistik palsu -->
            <div class="reveal reveal-delay-3 mt-8 rounded-2xl border border-border-subtle bg-surface-container-low p-5">
              <p class="flex items-center gap-2 text-sm font-bold text-on-surface">
                <span class="material-symbols-outlined text-lg text-primary" aria-hidden="true">info</span>
                Belum yakin harus mulai dari mana?
              </p>
              <p class="mt-2 text-sm text-secondary">
                Ceritakan kondisi tugas atau errormu lewat WhatsApp. Kami bantu petakan
                langkah paling masuk akal, tanpa kewajiban lanjut.
              </p>
              <a
                :href="waKonsultasi"
                target="_blank"
                rel="noopener noreferrer"
                class="mt-4 inline-flex items-center gap-2 text-sm font-bold text-primary hover:underline"
              >
                <span class="material-symbols-outlined text-base" aria-hidden="true">chat</span>
                Tanya dulu via WhatsApp
              </a>
            </div>
          </div>

          <ul class="grid gap-4 sm:grid-cols-2">
            <li
              v-for="(item, i) in jaminan"
              :key="item.judul"
              class="card reveal p-5"
              :class="[`reveal-delay-${(i % 4) + 1}`]"
            >
              <span
                class="material-symbols-outlined rounded-lg bg-surface-container p-2 text-primary"
                aria-hidden="true"
                >{{ item.icon }}</span
              >
              <h3 class="mt-4 text-sm font-bold text-on-surface">{{ item.judul }}</h3>
              <p class="mt-1.5 text-sm leading-relaxed text-secondary">{{ item.isi }}</p>
            </li>
          </ul>
        </div>
      </section>

      <!-- ================= STUDI KASUS ================= -->
      <section class="border-y border-border-subtle bg-surface-container-low">
        <div class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
          <div class="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
            <div class="max-w-2xl">
              <p class="eyebrow reveal">Contoh penanganan</p>
              <h2 class="reveal reveal-delay-1 mt-4 text-[28px] font-extrabold tracking-tight text-on-surface md:text-[36px]">
                Bagaimana persoalan seperti ini biasanya ditangani
              </h2>
            </div>
            <p class="reveal reveal-delay-2 max-w-sm text-sm text-secondary">
              Ilustrasi pendekatan, bukan klaim hasil. Setiap kasus tetap ditinjau
              sesuai kondisinya.
            </p>
          </div>

          <!-- Bento ringan: 1 kartu besar + 2 kartu kecil -->
          <div class="mt-10 grid gap-5 lg:grid-cols-3">
            <article class="card reveal flex flex-col p-6 lg:row-span-2 lg:p-8">
              <span class="w-fit rounded-full bg-surface-container px-3 py-1 text-[11px] font-bold uppercase tracking-wide text-secondary">
                Debugging
              </span>
              <h3 class="mt-5 text-xl font-bold text-on-surface">
                Error yang tidak kunjung ketemu akarnya
              </h3>
              <p class="mt-3 text-sm leading-relaxed text-secondary">
                Kasus paling sering: kode berjalan di lokal tapi gagal saat di-deploy,
                atau error yang muncul acak tanpa jejak jelas.
              </p>

              <div class="mt-6 space-y-4 border-l-2 border-primary-fixed pl-4">
                <div>
                  <p class="text-xs font-bold uppercase tracking-wide text-secondary">Pendekatan</p>
                  <p class="mt-1 text-sm text-on-surface">
                    Reproduksi kondisi gagal, telusuri log dan dependensi, lalu isolasi
                    titik penyebab.
                  </p>
                </div>
                <div>
                  <p class="text-xs font-bold uppercase tracking-wide text-secondary">Hasil yang dituju</p>
                  <p class="mt-1 text-sm text-on-surface">
                    Perbaikan yang menyasar penyebab, bukan gejala — plus catatan agar
                    tidak terulang.
                  </p>
                </div>
              </div>

              <RouterLink
                to="/joki-debug-error"
                class="mt-auto flex items-center gap-1.5 pt-6 text-sm font-bold text-primary"
              >
                Lihat penanganan debug
                <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
              </RouterLink>
            </article>

            <article class="card reveal reveal-delay-1 flex flex-col p-6">
              <span class="w-fit rounded-full bg-surface-container px-3 py-1 text-[11px] font-bold uppercase tracking-wide text-secondary">
                Tugas kuliah
              </span>
              <h3 class="mt-4 text-base font-bold text-on-surface">Deadline pemrograman mepet</h3>
              <p class="mt-2 flex-1 text-sm leading-relaxed text-secondary">
                Pengerjaan disertai penjelasan alur logika, supaya kamu bisa
                mempertanggungjawabkan hasilnya saat presentasi atau ditanya dosen.
              </p>
              <RouterLink
                to="/joki-tugas-kuliah-it"
                class="mt-4 flex items-center gap-1.5 text-sm font-bold text-primary"
              >
                Selengkapnya
                <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
              </RouterLink>
            </article>

            <article class="card reveal reveal-delay-2 flex flex-col p-6">
              <span class="w-fit rounded-full bg-surface-container px-3 py-1 text-[11px] font-bold uppercase tracking-wide text-secondary">
                Skripsi
              </span>
              <h3 class="mt-4 text-base font-bold text-on-surface">Revisi yang arahnya belum jelas</h3>
              <p class="mt-2 flex-1 text-sm leading-relaxed text-secondary">
                Pendampingan per bab dengan acuan masukan pembimbing, agar revisi
                terarah dan tidak berputar-putar.
              </p>
              <RouterLink
                to="/joki-skripsi-it"
                class="mt-4 flex items-center gap-1.5 text-sm font-bold text-primary"
              >
                Selengkapnya
                <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
              </RouterLink>
            </article>
          </div>
        </div>
      </section>

      <!-- ================= REFERRAL ================= -->
      <section class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
        <div class="overflow-hidden rounded-2xl border border-border-subtle bg-surface-white shadow-card">
          <div class="grid lg:grid-cols-[1.1fr_0.9fr]">
            <!-- Kiri: penjelasan -->
            <div class="p-6 md:p-10">
              <p class="eyebrow reveal">Program referral</p>
              <h2 class="reveal reveal-delay-1 mt-4 text-[26px] font-extrabold tracking-tight text-on-surface md:text-[32px]">
                Punya teman yang butuh bantuan teknis?
              </h2>
              <p class="reveal reveal-delay-2 mt-4 text-body-md text-secondary">
                Referensikan kami, dan dapatkan komisi dari setiap project yang berhasil
                berjalan. Tanpa modal, tanpa target.
              </p>

              <ul class="mt-6 space-y-3">
                <li
                  v-for="(poin, i) in referralPoin"
                  :key="poin"
                  class="reveal flex items-start gap-3 text-sm text-on-surface"
                  :class="[`reveal-delay-${i + 2}`]"
                >
                  <span
                    class="material-symbols-outlined mt-0.5 shrink-0 text-lg text-success-green"
                    aria-hidden="true"
                    >check_circle</span
                  >
                  {{ poin }}
                </li>
              </ul>

              <div class="reveal reveal-delay-4 mt-8 flex flex-col gap-3 sm:flex-row">
                <RouterLink to="/partner" class="btn-primary">
                  Daftar jadi partner
                  <span class="material-symbols-outlined text-lg" aria-hidden="true">arrow_forward</span>
                </RouterLink>
                <RouterLink to="/partner" class="btn-ghost border border-border-subtle">
                  Pelajari mekanismenya
                </RouterLink>
              </div>
            </div>

            <!-- Kanan: panel ringkas mekanisme -->
            <div class="border-t border-border-subtle bg-surface-container-low p-6 md:p-10 lg:border-l lg:border-t-0">
              <p class="text-[11px] font-bold uppercase tracking-widest text-secondary">
                Ringkasan mekanisme
              </p>
              <dl class="mt-5 space-y-4">
                <div class="flex items-baseline justify-between gap-4 border-b border-border-subtle pb-4">
                  <dt class="text-sm text-secondary">Nilai komisi</dt>
                  <dd class="text-lg font-extrabold text-on-surface">10%</dd>
                </div>
                <div class="flex items-baseline justify-between gap-4 border-b border-border-subtle pb-4">
                  <dt class="text-sm text-secondary">Pencairan</dt>
                  <dd class="text-right text-sm font-bold text-on-surface">Maks. 1×24 jam<br /><span class="text-xs font-normal text-secondary">setelah pelunasan</span></dd>
                </div>
                <div class="flex items-baseline justify-between gap-4">
                  <dt class="text-sm text-secondary">Modal awal</dt>
                  <dd class="text-sm font-bold text-on-surface">Tidak ada</dd>
                </div>
              </dl>

              <p class="mt-6 rounded-lg border border-border-subtle bg-surface-white p-3 text-xs leading-relaxed text-secondary">
                Komisi dihitung dari nilai project yang benar-benar berjalan, bukan dari
                sekadar pendaftaran.
              </p>
            </div>
          </div>
        </div>
      </section>

      <!-- ================= FAQ ================= -->
      <section class="border-t border-border-subtle bg-surface-container-low">
        <div class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
          <div class="grid gap-10 lg:grid-cols-[0.8fr_1.2fr] lg:gap-16">
            <div>
              <p class="eyebrow reveal">Tanya jawab</p>
              <h2 class="reveal reveal-delay-1 mt-4 text-[28px] font-extrabold tracking-tight text-on-surface md:text-[36px]">
                Yang sering ditanyakan
              </h2>
              <p class="reveal reveal-delay-2 mt-4 text-sm text-secondary">
                Belum terjawab?
                <RouterLink to="/tanya-jawab" class="font-bold text-primary hover:underline">
                  Lihat semua pertanyaan
                </RouterLink>
                atau tanya langsung via WhatsApp.
              </p>
            </div>

            <!-- Accordion native <details>: aksesibel tanpa JS tambahan -->
            <div class="reveal reveal-delay-2 divide-y divide-border-subtle border-y border-border-subtle">
              <details v-for="(item, i) in faqSingkat" :key="item.t" class="group" :open="i === 0">
                <summary
                  class="flex cursor-pointer list-none items-center justify-between gap-4 py-5 text-left text-sm font-bold text-on-surface transition-colors hover:text-primary md:text-base"
                >
                  {{ item.t }}
                  <span
                    class="material-symbols-outlined shrink-0 text-xl text-secondary transition-transform duration-200 group-open:rotate-45"
                    aria-hidden="true"
                    >add</span
                  >
                </summary>
                <p class="pb-5 pr-8 text-sm leading-relaxed text-secondary">{{ item.j }}</p>
              </details>
            </div>
          </div>
        </div>
      </section>

      <!-- ================= CTA AKHIR ================= -->
      <section class="mx-auto max-w-container-max-width px-gutter py-16 md:py-24">
        <div class="reveal relative overflow-hidden rounded-2xl bg-inverse-surface px-6 py-12 md:px-12 md:py-16">
          <!-- Aksen dekoratif tipis, tidak ramai -->
          <div
            class="pointer-events-none absolute -right-24 -top-24 h-64 w-64 rounded-full bg-primary/20 blur-3xl"
            aria-hidden="true"
          ></div>

          <div class="relative max-w-2xl">
            <h2 class="text-[28px] font-extrabold tracking-tight text-inverse-on-surface md:text-[36px]">
              Ceritakan kebutuhanmu, kami bantu petakan langkahnya
            </h2>
            <p class="mt-4 text-body-md text-slate-300">
              Tanpa kewajiban lanjut. Mulai dari konsultasi singkat untuk tahu apa
              yang sebenarnya dibutuhkan.
            </p>
            <div class="mt-8 flex flex-col gap-3 sm:flex-row">
              <RouterLink
                to="/request"
                class="btn inline-flex items-center justify-center gap-2 rounded-lg bg-surface-white px-6 py-3 font-bold text-inverse-surface transition-all duration-200 hover:-translate-y-0.5 hover:bg-surface-container"
              >
                <span class="material-symbols-outlined text-xl" aria-hidden="true">edit_note</span>
                Kirim detail project
              </RouterLink>
              <a
                :href="waKonsultasi"
                target="_blank"
                rel="noopener noreferrer"
                class="btn inline-flex items-center justify-center gap-2 rounded-lg border border-slate-600 px-6 py-3 font-bold text-inverse-on-surface transition-all duration-200 hover:-translate-y-0.5 hover:bg-slate-800"
              >
                <span class="material-symbols-outlined text-xl" aria-hidden="true">chat</span>
                Chat via WhatsApp
              </a>
            </div>
          </div>
        </div>
      </section>
    </main>

    <FooterBar />
    <BottomNavBar />
  </div>
</template>
