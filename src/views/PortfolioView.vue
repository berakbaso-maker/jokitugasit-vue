<script setup>
/**
 * PortfolioView — daftar seluruh studi kasus.
 *
 * Filter dan pencarian dilakukan di sisi klien karena datanya statis
 * (src/lib/portfolio.js), jadi tidak perlu request jaringan sama sekali.
 *
 * Filter kategori disimpan di query string (?kategori=web) supaya hasil
 * filter bisa dibagikan lewat tautan dan tetap ada saat halaman di-refresh.
 */
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import PortfolioCard from '../components/PortfolioCard.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import {
  proyek,
  proyekUnggulan,
  filterProyek,
  kategoriTerpakai,
  hitungPerKategori,
  statistik,
  LABEL_KATEGORI,
} from '../lib/portfolio'

const route = useRoute()
const router = useRouter()

const kategoriAktif = ref(
  typeof route.query.kategori === 'string' && route.query.kategori ? route.query.kategori : 'semua',
)
const kataKunci = ref('')

const kategori = kategoriTerpakai()
const jumlah = hitungPerKategori()
const stat = statistik()

const unggulan = proyekUnggulan(3)

const hasil = computed(() =>
  filterProyek({ kategori: kategoriAktif.value, q: kataKunci.value }),
)

/** Proyek unggulan hanya ditampilkan saat tidak sedang memfilter/mencari. */
const tampilkanUnggulan = computed(
  () => kategoriAktif.value === 'semua' && kataKunci.value.trim() === '',
)

/** Grid utama: sembunyikan proyek unggulan kalau sedang tampil di atas. */
const hasilGrid = computed(() => {
  if (!tampilkanUnggulan.value) return hasil.value
  const slugUnggulan = new Set(unggulan.map((p) => p.slug))
  return hasil.value.filter((p) => !slugUnggulan.has(p.slug))
})

function pilihKategori(k) {
  kategoriAktif.value = k
}

// Sinkronkan filter -> query string (tanpa menambah riwayat baru).
watch(kategoriAktif, (k) => {
  const query = { ...route.query }
  if (k === 'semua') delete query.kategori
  else query.kategori = k
  router.replace({ query })
})

function resetFilter() {
  kategoriAktif.value = 'semua'
  kataKunci.value = ''
}
</script>

<template>
  <div class="flex min-h-screen flex-col bg-background font-body-md text-on-surface antialiased">
    <TopAppBar />
    <main class="mx-auto w-full max-w-container-max-width flex-1 px-gutter py-12 md:py-16">
    <!-- Hero -->
    <section class="mb-10 max-w-3xl">
      <div
        class="mb-4 inline-flex items-center gap-2 rounded-full border border-border-subtle bg-surface-white px-4 py-1.5 shadow-sm"
      >
        <span class="material-symbols-outlined text-base text-primary" aria-hidden="true">work</span>
        <span class="text-xs font-bold uppercase tracking-wider text-secondary">Portofolio</span>
      </div>

      <h1 class="text-headline-lg font-headline-lg font-bold text-on-surface">
        Proyek yang pernah dikerjakan
      </h1>
      <p class="mt-3 text-body-lg font-body-lg text-secondary">
        Kumpulan studi kasus dari {{ stat.jumlahProyek }} proyek di
        {{ stat.jumlahKategori }} kategori berbeda, memakai
        {{ stat.jumlahStack }} teknologi. Setiap studi kasus menuliskan masalah awal,
        pendekatan yang dipakai, dan hasil terukurnya.
      </p>

      <!-- Statistik ringkas -->
      <dl class="mt-7 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div class="rounded-xl border border-border-subtle bg-surface-white p-4 shadow-card">
          <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Proyek</dt>
          <dd class="mt-1 text-2xl font-bold text-on-surface">{{ stat.jumlahProyek }}</dd>
        </div>
        <div class="rounded-xl border border-border-subtle bg-surface-white p-4 shadow-card">
          <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Kategori</dt>
          <dd class="mt-1 text-2xl font-bold text-on-surface">{{ stat.jumlahKategori }}</dd>
        </div>
        <div class="rounded-xl border border-border-subtle bg-surface-white p-4 shadow-card">
          <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Teknologi</dt>
          <dd class="mt-1 text-2xl font-bold text-on-surface">{{ stat.jumlahStack }}</dd>
        </div>
        <div class="rounded-xl border border-border-subtle bg-surface-white p-4 shadow-card">
          <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Rentang</dt>
          <dd class="mt-1 text-2xl font-bold text-on-surface">
            {{ stat.tahunAwal }}–{{ stat.tahunAkhir }}
          </dd>
        </div>
      </dl>
    </section>

    <!-- Filter + pencarian -->
    <section class="mb-8">
      <div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="-mx-1 flex flex-wrap gap-2 px-1">
          <button
            type="button"
            class="rounded-full border px-3.5 py-1.5 text-sm font-semibold transition-colors"
            :class="
              kategoriAktif === 'semua'
                ? 'border-primary bg-primary text-white'
                : 'border-border-subtle bg-surface-white text-secondary hover:border-primary hover:text-primary'
            "
            :aria-pressed="kategoriAktif === 'semua'"
            @click="pilihKategori('semua')"
          >
            Semua
            <span class="ml-1 text-xs opacity-80">{{ proyek.length }}</span>
          </button>

          <button
            v-for="k in kategori"
            :key="k"
            type="button"
            class="rounded-full border px-3.5 py-1.5 text-sm font-semibold transition-colors"
            :class="
              kategoriAktif === k
                ? 'border-primary bg-primary text-white'
                : 'border-border-subtle bg-surface-white text-secondary hover:border-primary hover:text-primary'
            "
            :aria-pressed="kategoriAktif === k"
            @click="pilihKategori(k)"
          >
            {{ LABEL_KATEGORI[k] }}
            <span class="ml-1 text-xs opacity-80">{{ jumlah[k] }}</span>
          </button>
        </div>

        <!-- Pencarian -->
        <div class="relative sm:w-64">
          <span
            class="material-symbols-outlined pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-base text-muted"
            aria-hidden="true"
            >search</span
          >
          <label for="cari-portofolio" class="sr-only">Cari proyek</label>
          <input
            id="cari-portofolio"
            v-model="kataKunci"
            type="search"
            placeholder="Cari proyek atau teknologi…"
            class="w-full rounded-xl border border-border-subtle bg-surface-white py-2 pl-9 pr-3 text-sm text-on-surface outline-none transition-colors focus:border-primary focus:ring-1 focus:ring-primary"
          />
        </div>
      </div>

      <p class="text-sm text-muted">
        Menampilkan <strong class="text-on-surface">{{ hasil.length }}</strong> proyek<span
          v-if="kategoriAktif !== 'semua'"
        >
          di kategori <strong class="text-on-surface">{{ LABEL_KATEGORI[kategoriAktif] }}</strong></span
        ><span v-if="kataKunci.trim()">
          untuk pencarian “<strong class="text-on-surface">{{ kataKunci.trim() }}</strong>”</span
        >.
      </p>
    </section>

    <!-- Proyek unggulan -->
    <section v-if="tampilkanUnggulan" class="mb-10">
      <h2 class="mb-4 text-headline-md font-headline-md font-bold text-on-surface">Proyek unggulan</h2>
      <div class="grid gap-5">
        <PortfolioCard v-for="p in unggulan" :key="p.slug" :proyek="p" variant="wide" />
      </div>
    </section>

    <!-- Grid -->
    <section v-if="hasilGrid.length">
      <h2 v-if="tampilkanUnggulan" class="mb-4 text-headline-md font-headline-md font-bold text-on-surface">
        Semua proyek
      </h2>
      <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <PortfolioCard v-for="p in hasilGrid" :key="p.slug" :proyek="p" />
      </div>
    </section>

    <!-- Kosong -->
    <!-- EmptyState memakai prop actionLabel + event @action, bukan slot. -->
    <EmptyState
      v-else-if="!hasil.length"
      icon="search_off"
      title="Tidak ada proyek yang cocok"
      description="Coba kata kunci lain, atau pilih kategori yang berbeda."
      action-label="Reset filter"
      @action="resetFilter"
    />

    <!-- CTA -->
    <section
      class="mt-14 rounded-2xl border border-border-subtle bg-surface-container-low p-7 text-center md:p-10"
    >
      <h2 class="text-headline-md font-headline-md font-bold text-on-surface">
        Punya tugas dengan kebutuhan serupa?
      </h2>
      <p class="mx-auto mt-2 max-w-xl text-sm text-secondary">
        Ceritakan masalahnya, bukan cuma judul tugasnya. Dari situ biasanya ketahuan
        pendekatan paling masuk akal dan berapa lama pengerjaannya.
      </p>
      <div class="mt-5 flex flex-wrap justify-center gap-3">
        <RouterLink
          to="/request"
          class="inline-flex items-center gap-2 rounded-xl bg-primary px-6 py-3 text-sm font-bold text-white transition-colors hover:bg-primary-container"
        >
          Ajukan tugas
          <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
        </RouterLink>
        <RouterLink
          to="/harga"
          class="inline-flex items-center gap-2 rounded-xl border border-border-subtle bg-surface-white px-6 py-3 text-sm font-bold text-on-surface transition-colors hover:border-primary hover:text-primary"
        >
          Lihat estimasi harga
        </RouterLink>
      </div>
    </section>

    <!-- Catatan kejujuran data -->
    <p class="mt-8 text-center text-xs leading-relaxed text-muted">
      Studi kasus di halaman ini adalah contoh penyusunan portofolio. Angka dan detail
      proyek bersifat ilustratif, bukan klaim pekerjaan klien tertentu.
    </p>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
