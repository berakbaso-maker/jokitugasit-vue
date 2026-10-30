<script setup>
/**
 * PortfolioDetailView — studi kasus satu proyek.
 *
 * Struktur mengikuti pola yang lazim dipakai portofolio engineer:
 * Masalah -> Pendekatan -> Hasil. Ini yang membuat pembaca tertarik,
 * bukan daftar fitur mentah.
 *
 * Proyek diambil dari slug di URL. Kalau slug tidak dikenal, tampilkan
 * keadaan kosong dengan tautan kembali -- bukan halaman putih.
 */
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import ProjectMockup from '../components/ProjectMockup.vue'
import PortfolioCard from '../components/PortfolioCard.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import { cariSlug, proyekTerkait, LABEL_KATEGORI } from '../lib/portfolio'

const route = useRoute()

const proyek = computed(() => cariSlug(String(route.params.slug || '')))
const terkait = computed(() => (proyek.value ? proyekTerkait(proyek.value.slug, 3) : []))
const label = computed(() =>
  proyek.value ? LABEL_KATEGORI[proyek.value.category] || proyek.value.category : '',
)
</script>

<template>
  <div class="flex min-h-screen flex-col bg-background font-body-md text-on-surface antialiased">
    <TopAppBar />
    <main class="mx-auto w-full max-w-container-max-width flex-1 px-gutter py-10 md:py-14">
    <!-- Tidak ditemukan -->
    <template v-if="!proyek">
      <EmptyState
        icon="search_off"
        title="Proyek tidak ditemukan"
        description="Tautan mungkin salah ketik atau proyeknya sudah diganti."
      />
      <div class="mt-6 text-center">
        <RouterLink
          to="/portofolio"
          class="inline-flex items-center gap-2 rounded-xl border border-border-subtle bg-surface-white px-5 py-2.5 text-sm font-bold text-on-surface transition-colors hover:border-primary hover:text-primary"
        >
          <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_back</span>
          Kembali ke portofolio
        </RouterLink>
      </div>
    </template>

    <template v-else>
      <!-- Remah roti -->
      <nav class="mb-6 flex items-center gap-1.5 text-sm text-muted" aria-label="Remah roti">
        <RouterLink to="/portofolio" class="transition-colors hover:text-primary">Portofolio</RouterLink>
        <span class="material-symbols-outlined text-base" aria-hidden="true">chevron_right</span>
        <RouterLink
          :to="`/portofolio?kategori=${proyek.category}`"
          class="transition-colors hover:text-primary"
        >
          {{ label }}
        </RouterLink>
        <span class="material-symbols-outlined text-base" aria-hidden="true">chevron_right</span>
        <span class="truncate font-semibold text-on-surface">{{ proyek.title }}</span>
      </nav>

      <!-- Header -->
      <header class="mb-8 max-w-3xl">
        <span
          class="mb-3 inline-block rounded-full bg-primary-fixed px-3 py-1 text-[11px] font-bold uppercase tracking-wide text-on-primary-fixed"
        >
          {{ label }}
        </span>
        <h1 class="text-headline-lg font-headline-lg font-bold text-on-surface">
          {{ proyek.title }}
        </h1>
        <p class="mt-2 text-body-lg font-body-lg text-secondary">{{ proyek.tagline }}</p>

        <!-- Meta -->
        <dl class="mt-6 grid grid-cols-2 gap-x-6 gap-y-4 border-t border-border-subtle pt-5 sm:grid-cols-4">
          <div>
            <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Tahun</dt>
            <dd class="mt-0.5 text-sm font-bold text-on-surface">{{ proyek.year }}</dd>
          </div>
          <div>
            <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Durasi</dt>
            <dd class="mt-0.5 text-sm font-bold text-on-surface">{{ proyek.duration }}</dd>
          </div>
          <div>
            <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Peran</dt>
            <dd class="mt-0.5 text-sm font-bold text-on-surface">{{ proyek.role }}</dd>
          </div>
          <div>
            <dt class="text-xs font-semibold uppercase tracking-wide text-muted">Kategori</dt>
            <dd class="mt-0.5 text-sm font-bold text-on-surface">{{ label }}</dd>
          </div>
        </dl>
      </header>

      <!-- Mockup besar -->
      <div class="mb-10 overflow-hidden rounded-2xl border border-border-subtle shadow-card">
        <ProjectMockup
          :gradient="proyek.mockup.gradient"
          :icon="proyek.mockup.icon"
          variant="wide"
        />
      </div>

      <div class="grid gap-10 lg:grid-cols-[minmax(0,1fr)_280px]">
        <div class="min-w-0">
          <!-- Masalah -->
          <section class="mb-8">
            <h2 class="mb-2 flex items-center gap-2 text-headline-md font-headline-md font-bold text-on-surface">
              <span class="material-symbols-outlined text-primary" aria-hidden="true">report_problem</span>
              Masalah
            </h2>
            <p class="text-body-md font-body-md leading-relaxed text-secondary">
              {{ proyek.problem }}
            </p>
          </section>

          <!-- Pendekatan -->
          <section class="mb-8">
            <h2 class="mb-2 flex items-center gap-2 text-headline-md font-headline-md font-bold text-on-surface">
              <span class="material-symbols-outlined text-primary" aria-hidden="true">lightbulb</span>
              Pendekatan
            </h2>
            <p class="text-body-md font-body-md leading-relaxed text-secondary">
              {{ proyek.solution }}
            </p>
          </section>

          <!-- Fitur -->
          <section class="mb-8">
            <h2 class="mb-3 flex items-center gap-2 text-headline-md font-headline-md font-bold text-on-surface">
              <span class="material-symbols-outlined text-primary" aria-hidden="true">checklist</span>
              Yang dibangun
            </h2>
            <ul class="grid gap-2.5 sm:grid-cols-2">
              <li
                v-for="f in proyek.features"
                :key="f"
                class="flex items-start gap-2 rounded-xl border border-border-subtle bg-surface-white p-3 text-sm text-secondary"
              >
                <span
                  class="material-symbols-outlined mt-0.5 text-base text-primary"
                  aria-hidden="true"
                  >check_circle</span
                >
                <span>{{ f }}</span>
              </li>
            </ul>
          </section>

          <!-- Hasil -->
          <section>
            <h2 class="mb-3 flex items-center gap-2 text-headline-md font-headline-md font-bold text-on-surface">
              <span class="material-symbols-outlined text-primary" aria-hidden="true">trending_up</span>
              Hasil
            </h2>
            <div class="grid gap-3 sm:grid-cols-3">
              <div
                v-for="m in proyek.result.metrics"
                :key="m.label"
                class="rounded-xl border border-border-subtle bg-surface-container-low p-4"
              >
                <p class="text-xs font-semibold uppercase tracking-wide text-muted">{{ m.label }}</p>
                <p class="mt-1 text-lg font-bold text-on-surface">{{ m.value }}</p>
              </div>
            </div>
          </section>
        </div>

        <!-- Sidebar -->
        <aside class="lg:sticky lg:top-24 lg:self-start">
          <div class="rounded-2xl border border-border-subtle bg-surface-white p-5 shadow-card">
            <h2 class="mb-3 text-sm font-bold uppercase tracking-wide text-muted">Teknologi</h2>
            <div class="flex flex-wrap gap-1.5">
              <span
                v-for="s in proyek.stack"
                :key="s"
                class="rounded-md bg-surface-container px-2.5 py-1 text-xs font-semibold text-on-surface-variant"
              >
                {{ s }}
              </span>
            </div>

            <hr class="my-5 border-border-subtle" />

            <p class="text-sm text-secondary">Butuh sesuatu yang mirip dengan proyek ini?</p>
            <RouterLink
              to="/request"
              class="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-bold text-white transition-colors hover:bg-primary-container"
            >
              Ajukan tugas
              <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
            </RouterLink>
            <RouterLink
              to="/harga"
              class="mt-2 flex w-full items-center justify-center rounded-xl border border-border-subtle px-4 py-2.5 text-sm font-bold text-on-surface transition-colors hover:border-primary hover:text-primary"
            >
              Cek estimasi harga
            </RouterLink>
          </div>
        </aside>
      </div>

      <!-- Proyek terkait -->
      <section v-if="terkait.length" class="mt-14">
        <h2 class="mb-4 text-headline-md font-headline-md font-bold text-on-surface">
          Proyek lain di kategori {{ label }}
        </h2>
        <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          <PortfolioCard v-for="p in terkait" :key="p.slug" :proyek="p" />
        </div>
      </section>

      <p class="mt-10 text-center text-xs leading-relaxed text-muted">
        Studi kasus ini adalah contoh penyusunan portofolio. Angka dan detail proyek
        bersifat ilustratif, bukan klaim pekerjaan klien tertentu.
      </p>
    </template>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
