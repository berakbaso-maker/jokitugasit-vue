<script setup>
/**
 * /janji — halaman komitmen layanan.
 *
 * Tujuannya menutup dua ketakutan utama calon klien jasa bantuan tugas:
 *   (1) "nanti ditipu / hasilnya tidak sesuai"
 *   (2) "tugas saya bocor atau ketahuan"
 *
 * Aturan isi: hanya menulis komitmen yang benar-benar dijalankan sistem.
 * Jangan menambah klaim angka/rating. Bagian "tidak kami janjikan" sengaja
 * ada supaya halaman ini terasa jujur, bukan brosur.
 */
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/tautan'

const janji = [
  {
    icon: 'handshake',
    judul: 'Nilai disepakati sebelum pengerjaan',
    isi: 'Kamu menerima nilai pekerjaan lebih dulu. Tidak ada tagihan tambahan di tengah jalan. Kalau kamu setuju, baru pengerjaan dimulai.',
    bukti: 'Setiap order mencatat nilai dan diskon di sistem, dan tercetak di kuitansi.',
  },
  {
    icon: 'build',
    judul: 'Garansi perbaikan saat presentasi',
    isi: 'Kalau muncul error saat kamu presentasi atau demo di depan dosen, kami perbaiki tanpa biaya tambahan.',
    bukti: 'Ketentuan ini tertulis di ringkasan pekerjaan (SOW) yang kamu terima sebelum mulai.',
  },
  {
    icon: 'school',
    judul: 'Pendampingan, bukan sekadar hasil jadi',
    isi: 'Kamu dapat penjelasan cara kerja kode dan pendampingan persiapan demo, supaya bisa menjawab kalau ditanya.',
    bukti: 'Sesi penjelasan dan catatan logika disiapkan untuk setiap pekerjaan.',
  },
  {
    icon: 'lock',
    judul: 'File dan datamu tidak dipublikasikan',
    isi: 'Tugas, kode, dan datamu tidak dipakai sebagai portofolio atau dibagikan ke pihak lain tanpa izin tertulis darimu.',
    bukti: 'Portofolio di situs ini memakai studi kasus contoh, bukan pekerjaan klien.',
  },
]

const tidakDijanjikan = [
  'Nilai atau IP tertentu — penilaian tetap di tangan dosen.',
  'Mengerjakan ujian, tes seleksi, atau sertifikasi formal.',
  'Hasil tanpa revisi — revisi tetap mengikuti kesepakatan di awal.',
  'Pengerjaan tanpa kesepakatan tertulis soal nilai dan lingkup kerja.',
]

const wa = waLink('6285166337257', 'Halo jokitugasit.my.id, saya sudah baca halaman janji layanan dan mau tanya.')
</script>

<template>
  <div class="min-h-screen bg-surface">
    <TopAppBar />

    <main id="konten-utama" tabindex="-1">
      <!-- kop -->
      <section class="border-b border-border-subtle bg-surface-container-low">
        <div class="mx-auto max-w-container-max-width px-gutter py-14 md:py-20">
          <p class="eyebrow">Janji layanan</p>
          <h1 class="mt-4 max-w-3xl text-[30px] font-extrabold leading-tight tracking-tight text-on-surface md:text-[42px]">
            Yang kami jamin, dan yang tidak kami janjikan
          </h1>
          <p class="mt-4 max-w-2xl text-body-md leading-relaxed text-secondary">
            Sebelum kamu mempercayakan tugas ke orang lain, wajar kalau kamu ingin tahu
            batasannya. Halaman ini menjelaskan keduanya dengan jelas — tanpa istilah
            pemasaran.
          </p>
          <div class="mt-7 flex flex-col gap-3 sm:flex-row">
            <RouterLink
              to="/request"
              class="btn-primary min-h-11 px-6 text-sm"
            >
              <span class="material-symbols-outlined text-[20px]" aria-hidden="true">send</span>
              Mulai konsultasi gratis
            </RouterLink>
            <a
              :href="wa"
              target="_blank"
              rel="noopener noreferrer"
              class="btn-secondary min-h-11 px-6 text-sm"
            >
              <span class="material-symbols-outlined text-[20px]" aria-hidden="true">chat</span>
              Tanya via WhatsApp
            </a>
          </div>
        </div>
      </section>

      <!-- 4 komitmen -->
      <section class="mx-auto max-w-container-max-width px-gutter py-14 md:py-20">
        <div class="grid gap-4 md:grid-cols-2">
          <article v-for="j in janji" :key="j.judul" class="card p-6">
            <span class="material-symbols-outlined rounded-lg bg-primary-fixed/50 p-2 text-primary" aria-hidden="true">{{ j.icon }}</span>
            <h2 class="mt-4 text-base font-bold text-on-surface">{{ j.judul }}</h2>
            <p class="mt-2 text-sm leading-relaxed text-secondary">{{ j.isi }}</p>
            <p class="mt-4 flex items-start gap-2 rounded-lg bg-surface-container-low p-3 text-xs leading-relaxed text-on-surface-variant">
              <span class="material-symbols-outlined text-[16px] text-success-green" aria-hidden="true">verified</span>
              <span><b class="font-bold">Buktinya:</b> {{ j.bukti }}</span>
            </p>
          </article>
        </div>
      </section>

      <!-- yang tidak dijanjikan -->
      <section class="border-y border-border-subtle bg-surface-container-low">
        <div class="mx-auto max-w-container-max-width px-gutter py-14 md:py-16">
          <p class="eyebrow">Batas layanan</p>
          <h2 class="mt-3 text-[26px] font-extrabold tracking-tight text-on-surface md:text-[32px]">
            Yang tidak kami janjikan
          </h2>
          <p class="mt-3 max-w-2xl text-sm leading-relaxed text-secondary">
            Kami sengaja menuliskannya. Layanan yang jelas batasannya lebih aman
            daripada yang menjanjikan segalanya.
          </p>
          <ul class="mt-6 grid gap-3 sm:grid-cols-2">
            <li v-for="t in tidakDijanjikan" :key="t" class="flex items-start gap-2.5 rounded-xl border border-border-subtle bg-surface-white p-4 text-sm text-on-surface-variant">
              <span class="material-symbols-outlined text-[18px] text-urgency-red" aria-hidden="true">block</span>
              <span>{{ t }}</span>
            </li>
          </ul>
        </div>
      </section>

      <!-- bukti yang bisa dicek -->
      <section class="mx-auto max-w-container-max-width px-gutter py-14 md:py-20">
        <p class="eyebrow">Bukti, bukan klaim</p>
        <h2 class="mt-3 text-[26px] font-extrabold tracking-tight text-on-surface md:text-[32px]">
          Kamu bisa mengeceknya sendiri hari ini
        </h2>
        <p class="mt-3 max-w-2xl text-sm leading-relaxed text-secondary">
          Sistem yang kamu lihat di situs ini adalah sistem yang kami pakai sehari-hari
          untuk mengelola pesanan. Bukan demo.
        </p>
        <ol class="mt-6 grid gap-4 md:grid-cols-3">
          <li class="card p-5">
            <span class="text-xs font-bold text-primary">01</span>
            <h3 class="mt-1 text-sm font-bold text-on-surface">Kirim request</h3>
            <p class="mt-1 text-sm text-secondary">Gratis, tanpa daftar akun. Cukup ceritakan masalahmu.</p>
            <RouterLink to="/request" class="mt-3 inline-flex min-h-11 items-center gap-1 text-sm font-bold text-primary hover:underline">
              Buka form <span class="material-symbols-outlined text-[16px]" aria-hidden="true">arrow_forward</span>
            </RouterLink>
          </li>
          <li class="card p-5">
            <span class="text-xs font-bold text-primary">02</span>
            <h3 class="mt-1 text-sm font-bold text-on-surface">Dapat kode booking</h3>
            <p class="mt-1 text-sm text-secondary">Nomor order langsung terbit dan dikirim ke emailmu.</p>
            <RouterLink to="/track" class="mt-3 inline-flex min-h-11 items-center gap-1 text-sm font-bold text-primary hover:underline">
              Cek status <span class="material-symbols-outlined text-[16px]" aria-hidden="true">arrow_forward</span>
            </RouterLink>
          </li>
          <li class="card p-5">
            <span class="text-xs font-bold text-primary">03</span>
            <h3 class="mt-1 text-sm font-bold text-on-surface">Pantau tanpa login</h3>
            <p class="mt-1 text-sm text-secondary">Setiap perubahan status juga dikabari lewat email.</p>
            <RouterLink to="/cara-kerja" class="mt-3 inline-flex min-h-11 items-center gap-1 text-sm font-bold text-primary hover:underline">
              Lihat alurnya <span class="material-symbols-outlined text-[16px]" aria-hidden="true">arrow_forward</span>
            </RouterLink>
          </li>
        </ol>
      </section>

      <!-- CTA -->
      <section class="mx-auto max-w-container-max-width px-gutter pb-16">
        <div class="rounded-2xl bg-inverse-surface p-6 text-inverse-on-surface md:p-10">
          <h2 class="text-[24px] font-extrabold tracking-tight md:text-[30px]">Masih ada yang ingin ditanyakan?</h2>
          <p class="mt-2 max-w-xl text-sm leading-relaxed opacity-80">
            Tanya dulu soal lingkup, nilai, atau tenggat. Konsultasi gratis dan tidak
            ada kewajiban untuk lanjut.
          </p>
          <a
            :href="wa"
            target="_blank"
            rel="noopener noreferrer"
            class="mt-5 inline-flex min-h-11 items-center gap-2 rounded-lg bg-white px-5 text-sm font-bold text-primary hover:bg-primary-fixed"
          >
            <span class="material-symbols-outlined text-[20px]" aria-hidden="true">chat</span>
            Chat WhatsApp
          </a>
        </div>
      </section>
    </main>

    <FooterBar />
    <BottomNavBar />
  </div>
</template>
